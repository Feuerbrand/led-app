import Foundation
import Observation
import QuartzCore

/// Was gesteuert wird: alle Lichter zusammen oder ein einzelnes
enum Target: Hashable {
    case all
    case light(UUID)
}

/// Was ein Licht (oder „Alle Lichter“) zeigen soll. Wird gespeichert.
struct LightLook: Codable, Equatable {
    /// nil = noch nie in der App eingestellt
    var power: Bool? = nil
    var red = 255
    var green = 0
    var blue = 0
    var brightness = 100
    var speed = 50
    var flowID: String? = nil
    var builtin: UInt8? = nil
    var builtinFamily: String? = nil

    /// Zuletzt gewählte feste Farbe (Grundfarbe für „Atmen“)
    var base: RGB {
        get { RGB(red, green, blue) }
        set {
            red = newValue.r
            green = newValue.g
            blue = newValue.b
        }
    }

    var family: EffectFamily? { builtinFamily.flatMap { EffectFamily(rawValue: $0) } }
}

private struct SavedLooks: Codable {
    var all: LightLook
    var lights: [String: LightLook]
    var wave: Bool?
}

/// Zustand der App und die Lichtlogik aus index.html (Farbe, Flow-Effekte, Tempo, Sende-Regel),
/// erweitert um einzeln steuerbare Lichter, „Alle Lichter“, die Welle über mehrere Lichter,
/// Szenen, Musik-Modus und Kurzbefehle. Läuft komplett auf dem Hauptthread.
@Observable
final class LightController {
    enum Bar {
        case hue, white
    }

    /// Eine Instanz für die ganze App (auch für Siri und Kurzbefehle)
    static let shared = LightController()

    /// Kennung für „Alle Lichter“ in den Animationen (steht für die Lampe in der Oberfläche)
    static let allKey = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Bluetooth und die Liste der Lichter
    let hub = LightHub()

    // MARK: - Was die Oberfläche anzeigt

    private(set) var log = ""
    /// Zählt bei jeder neuen Verbindung hoch (löst Lichtring und Rückmeldung aus)
    private(set) var connectedCount = 0
    /// Vorführmodus: alles bedienen, ohne dass ein Licht verbunden ist (für Apples Prüfung, Bilder, Ausprobieren)
    private(set) var demo = false
    /// Geöffnete Steuerung: alle Lichter oder eines
    private(set) var target: Target = .all
    private(set) var looks: [UUID: LightLook] = [:]
    private(set) var allLook = LightLook()
    /// Farbe, in der jedes Licht gerade leuchtet (für Karten und Lampe, gedrosselt nachgeführt)
    private(set) var glows: [UUID: RGB] = [:]
    /// Effekte bei „Alle Lichter“ versetzt laufen lassen: die Farbe wandert von Licht zu Licht
    private(set) var wave = true
    private(set) var swatch: Int? = nil
    private(set) var bar: Bar? = nil
    private(set) var huePos = 0.0
    private(set) var whitePos = 0.0
    private(set) var scenes: [LightScene] = []
    /// Zuletzt gewählte Szene (für die Markierung)
    private(set) var sceneID: UUID? = nil

    // Zustand der geöffneten Steuerung
    var look: LightLook { lookOf(target) }
    var power: Bool? { look.power }
    var base: RGB { look.base }
    var brightness: Int { look.brightness }
    var speed: Int { look.speed }
    var flowID: String? { look.flowID }
    var builtin: UInt8? { look.builtin }
    var builtinFamily: EffectFamily? { look.family }
    /// Farbe der geöffneten Steuerung, wie sie gerade leuchtet
    var led: RGB { glow(target) }

    func lookOf(_ t: Target) -> LightLook {
        switch t {
        case .all: return allLook
        case .light(let id): return looks[id] ?? allLook
        }
    }

    func glow(_ t: Target) -> RGB {
        glows[key(t)] ?? lookOf(t).base
    }

    func title(_ t: Target) -> String {
        switch t {
        case .all: return "Alle Lichter"
        case .light(let id): return hub.light(id: id)?.title ?? "Licht"
        }
    }

    /// Lichter, an die Befehle für dieses Ziel gehen (eingeschaltete in der Liste, ob verbunden oder nicht)
    func lightsOf(_ t: Target) -> [Light] {
        switch t {
        case .all: return hub.mine.filter { $0.enabled }
        case .light(let id): return hub.mine.filter { $0.id == id }
        }
    }

    func isConnected(_ t: Target) -> Bool {
        lightsOf(t).contains { $0.state == .on }
    }

    /// Bedienung freigeben: ein passendes Licht ist verbunden oder der Vorführmodus läuft
    var canControl: Bool { demo || isConnected(target) }

    /// Verbunden und nicht ausgeschaltet -> die Oberfläche leuchtet in der Farbe des Lichts
    func isLive(_ t: Target) -> Bool {
        (demo || isConnected(t)) && lookOf(t).power != false
    }

    var live: Bool { isLive(target) }

    var link: LinkState { demo && !hub.hasTargets ? .on : hub.summary }
    var status: String { demo && !hub.hasTargets ? "Vorführmodus – kein Licht verbunden" : hub.statusText }

    /// Bildschirm anlassen, solange ein Effekt der App läuft (sonst hält iOS die App an)
    var keepAwake: Bool {
        if demo && allLook.flowID != nil { return true }
        return hub.targets.contains { looks[$0.id]?.flowID != nil }
    }

    /// Vorschlag für den Namen einer neuen Szene
    var suggestedSceneName: String {
        if let id = flowID, let flow = Flow.everything.first(where: { $0.id == id }) { return flow.name }
        return "Farbe \(base.hex)"
    }

    /// Sekunden pro Durchlauf: Tempo 0 = langsam (90 s) … 100 = schnell (3 s), wie period() in index.html
    static func period(_ speed: Int) -> Double {
        90 * pow(3.0 / 90.0, Double(speed) / 100)
    }

    var period: Double { Self.period(speed) }

    // MARK: - Intern

    @ObservationIgnored private let meter = SoundMeter()
    @ObservationIgnored private var cur: [UUID: RGB] = [:]          // zuletzt ausgegebene Farbe je Licht
    @ObservationIgnored private var owner: [UUID: Int] = [:]        // welche Animation gerade welches Licht steuert
    @ObservationIgnored private var lastAnim = 0
    @ObservationIgnored private var glowAt: [UUID: Double] = [:]
    @ObservationIgnored private var pending: [() -> Void] = []      // Kurzbefehl, der auf die Verbindung wartet
    @ObservationIgnored private var saveTask: Task<Void, Never>? = nil

    private static let whites = [RGB(255, 147, 41), RGB(255, 214, 170), RGB(255, 255, 255), RGB(201, 226, 255)]
    private static let stateKey = "led-app.state"
    private static let looksKey = "led-app.looks"
    private static let scenesKey = "led-app.scenes"

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init() {
        if let saved = Store.load(SavedLooks.self, key: Self.looksKey) {
            allLook = saved.all
            for (key, look) in saved.lights {
                if let id = UUID(uuidString: key) { looks[id] = look }
            }
            wave = saved.wave ?? true
        } else if let old = Store.load(SavedState.self, key: Self.stateKey) {
            // Aus älteren Versionen: eine gemeinsame Einstellung für alle Lichter
            allLook.brightness = min(max(old.brightness, 0), 100)
            allLook.speed = min(max(old.speed, 0), 100)
            allLook.base = RGB(old.red, old.green, old.blue)
        }
        // Effekte der App laufen nur, solange sie offen ist
        allLook.flowID = nil
        for id in looks.keys { looks[id]?.flowID = nil }
        scenes = Store.load([LightScene].self, key: Self.scenesKey) ?? LightScene.starters
        hub.onLog = { [weak self] message in self?.note(message) }
        hub.onReady = { [weak self] light in self?.sync(light) }
        note("Bereit. Andere Licht-Apps vorher schließen!")
    }

    // MARK: - Verbindung

    /// Beim App-Start: Bluetooth einschalten, die Lichter werden dann von selbst gesucht
    func start() {
        // Bei den automatischen App-Store-Bildern kein Bluetooth starten (keine Erlaubnis-Abfrage im Bild)
        if UserDefaults.standard.bool(forKey: "demo") {
            startScreenshotScene()
            return
        }
        hub.start()
    }

    func resume() { hub.resume() }

    /// Steuerung für ein Ziel öffnen
    func select(_ t: Target) {
        if target != t {
            target = t
            swatch = nil
            bar = nil
            sceneID = nil
        }
    }

    func setDemo(_ on: Bool) {
        demo = on
        if on {
            if allLook.power == nil { allLook.power = true }
            note("Vorführmodus an – die Bedienung läuft ohne Licht.")
        } else {
            note("Vorführmodus aus")
        }
    }

    func setWave(_ on: Bool) {
        wave = on
        saveSoon()
        // Läuft gerade ein Effekt auf allen Lichtern, mit der neuen Einstellung neu starten
        if let id = allLook.flowID, let f = Flow.everything.first(where: { $0.id == id }) {
            startFlow(f, .all)
        }
    }

    /// Licht aufnehmen: es bekommt erst einmal die Einstellung von „Alle Lichter“
    func add(_ light: Light, name: String) {
        if looks[light.id] == nil {
            var look = allLook
            look.flowID = nil
            look.builtin = nil
            look.builtinFamily = nil
            looks[light.id] = look
        }
        hub.add(light, name: name)
        saveSoon()
    }

    /// Für die automatischen App-Store-Bilder: Startargumente wie „-demo YES -screenshotFlow aurora“
    @ObservationIgnored private var screenshotDone = false
    private func startScreenshotScene() {
        let args = UserDefaults.standard
        guard !screenshotDone, args.bool(forKey: "demo") else { return }
        screenshotDone = true
        hub.showSampleLights()
        setDemo(true)
        if let hex = args.string(forKey: "screenshotColor"), let c = RGB(hexString: hex) {
            applyColor(c, .all, instant: true)
        }
        if let id = args.string(forKey: "screenshotFlow"), let f = Flow.everything.first(where: { $0.id == id }), f.kind != .music {
            applyFlow(f, .all, toggle: false)
        }
    }

    /// Ein Licht ist frisch verbunden: seinen gespeicherten Zustand übertragen.
    /// Solange in der App noch nichts eingestellt wurde, bleibt das Licht, wie es ist.
    private func sync(_ light: Light) {
        connectedCount += 1
        let look = looks[light.id] ?? allLook
        if look.power == false {
            hub.send(.power(false), to: light)
        } else {
            // Die MELK-Anmeldung schaltet das Licht aus -> wieder einschalten
            if look.power == true || !light.model.login.isEmpty { hub.send(.power(true), to: light) }
            if look.power == true {
                hub.send(.bright(look.brightness), to: light)
                if let code = look.builtin, look.family == light.model.family {
                    hub.send(.effect(code), to: light)
                } else if owner[light.id] == nil {
                    hub.send(color: cur[light.id] ?? look.base, to: light)
                }
                // Ein laufender Effekt erreicht das Licht von selbst mit dem nächsten Farbwert
            }
        }
        let jobs = pending
        pending = []
        for job in jobs { job() }
    }

    private func note(_ message: String) {
        let line = Self.clock.string(from: Date()) + "  " + message + "\n"
        log = String((line + log).prefix(2000))
    }

    // MARK: - Zustand ändern und senden

    private func key(_ t: Target) -> UUID {
        if case .light(let id) = t { return id }
        return Self.allKey
    }

    /// Kennungen, die eine Animation für dieses Ziel bedient (bei „Alle“ auch die Lampe der Oberfläche)
    private func ids(for t: Target) -> [UUID] {
        switch t {
        case .all: return lightsOf(.all).map { $0.id } + [Self.allKey]
        case .light(let id): return [id]
        }
    }

    private func update(_ t: Target, _ change: (inout LightLook) -> Void) {
        switch t {
        case .all:
            change(&allLook)
            for light in lightsOf(.all) {
                var look = looks[light.id] ?? allLook
                change(&look)
                looks[light.id] = look
            }
        case .light(let id):
            var look = looks[id] ?? allLook
            change(&look)
            looks[id] = look
        }
        saveSoon()
    }

    private func send(_ order: Order, to t: Target, family: EffectFamily? = nil) {
        for light in lightsOf(t) where family == nil || light.model.family == family {
            hub.send(order, to: light)
        }
    }

    /// Farbe ausgeben: ans Licht schicken und in der Oberfläche spiegeln (höchstens alle 80 ms)
    private func emit(_ c: RGB, _ id: UUID, force: Bool = false) {
        cur[id] = c
        if id != Self.allKey, let light = hub.light(id: id), looks[id]?.power != false {
            hub.send(color: c, to: light)
        }
        let now = CACurrentMediaTime()
        if force || now - (glowAt[id] ?? 0) >= 0.08 {
            glowAt[id] = now
            if glows[id] != c { glows[id] = c }
        }
    }

    /// Diese Lichter übernimmt eine neue Animation; ältere Animationen lassen sie dann los
    private func claim(_ ids: [UUID]) -> Int {
        lastAnim += 1
        for id in ids { owner[id] = lastAnim }
        return lastAnim
    }

    private func release(_ ids: [UUID]) {
        for id in ids { owner[id] = nil }
    }

    private func saveSoon() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [self] in
            try? await Task.sleep(for: .milliseconds(600))
            if Task.isCancelled { return }
            var lights: [String: LightLook] = [:]
            for (id, look) in looks { lights[id.uuidString] = look }
            Store.save(SavedLooks(all: allLook, lights: lights, wave: wave), key: Self.looksKey)
        }
    }

    // MARK: - Animationen

    /// Weich von der aktuellen zur neuen Farbe
    private func fade(_ ids: [UUID], to target: RGB, ms: Double = 350) {
        var from: [UUID: RGB] = [:]
        for id in ids { from[id] = cur[id] ?? target }
        let my = claim(ids)
        let t0 = CACurrentMediaTime()
        Task { @MainActor [self] in
            while true {
                let mine = ids.filter { owner[$0] == my }
                if mine.isEmpty { return }
                let k = min(1, (CACurrentMediaTime() - t0) * 1000 / ms)
                for id in mine {
                    emit(ColorMath.mix(from[id] ?? target, target, ColorMath.ease(k)), id, force: true)
                }
                if k >= 1 {
                    release(mine)
                    return
                }
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    /// Abstand der Lichter in der Welle (Anteil eines Durchlaufs)
    private static func waveStep(_ count: Int) -> Double {
        count > 1 ? min(0.12, 0.6 / Double(count - 1)) : 0
    }

    /// Flow-Effekt für ein Ziel laufen lassen. Bei „Alle“ mit Welle läuft die Farbe von Licht zu Licht.
    private func startFlow(_ f: Flow, _ t: Target) {
        let ids = ids(for: t)
        let lights = ids.filter { $0 != Self.allKey }
        var offsets: [UUID: Double] = [:]
        if t == .all && wave && lights.count > 1 {
            let step = Self.waveStep(lights.count)
            for (i, id) in lights.enumerated() { offsets[id] = -Double(i) * step }
        }
        var from: [UUID: RGB] = [:]
        for id in ids { from[id] = cur[id] ?? lookOf(t).base }
        // Regenbogen und Musik steigen beim aktuellen Farbton ein
        let first = cur[ids.first ?? Self.allKey] ?? lookOf(t).base
        let start = (f.kind == .rainbow || f.kind == .music) ? ColorMath.hue(of: first) / 360 : 0
        let my = claim(ids)
        let t0 = CACurrentMediaTime()
        if f.kind == .music { startListening(t) }
        Task { @MainActor [self] in
            var phase = start
            var last = t0
            var envelope = 0.0
            while true {
                let mine = ids.filter { owner[$0] == my }
                if mine.isEmpty { return }
                let now = CACurrentMediaTime()
                let dt = min(now - last, 0.1)
                last = now
                let look = lookOf(t)
                phase = (phase + dt * f.rate / Self.period(look.speed)).truncatingRemainder(dividingBy: 1)
                // Musik: sofort hochschnellen, langsamer abklingen
                envelope = max(meter.level, envelope * 0.86)
                let k = (now - t0) / 0.9                                    // Einstieg: 0,9 s von der alten Farbe überblenden
                for id in mine {
                    var p = (phase + (offsets[id] ?? 0)).truncatingRemainder(dividingBy: 1)
                    if p < 0 { p += 1 }
                    var c = f.color(at: p, base: look.base, level: envelope)
                    if k < 1 { c = ColorMath.mix(from[id] ?? c, c, ColorMath.ease(k)) }
                    emit(c, id)
                }
                try? await Task.sleep(for: .milliseconds(34))
            }
        }
    }

    /// Mikrofon für den Musik-Modus einschalten; ohne Erlaubnis hält der Effekt wieder an
    private func startListening(_ t: Target) {
        meter.start { [weak self] ok in
            guard let self else { return }
            if !ok {
                self.note("Musik-Modus: Mikrofon nicht verfügbar. Erlauben unter Einstellungen → Apps → LED Control → Mikrofon.")
                if self.lookOf(t).flowID == Flow.music.id {
                    self.release(self.ids(for: t))
                    self.update(t) { $0.flowID = nil }
                }
            }
            self.stopMeterIfUnused()
        }
    }

    private func stopMeterIfUnused() {
        guard meter.running else { return }
        let music = Flow.music.id
        let used = allLook.flowID == music || looks.values.contains { $0.flowID == music }
        if !used { meter.stop() }
    }

    // MARK: - Bedienung (wirkt auf die geöffnete Steuerung)

    func setPower(_ on: Bool) { applyPower(on, target) }

    private func applyPower(_ on: Bool, _ t: Target) {
        update(t) { $0.power = on }
        send(.power(on), to: t)
    }

    /// Ein einzelnes Licht direkt an- oder ausschalten (Knopf auf der Karte im Hauptmenü)
    func setPower(_ on: Bool, for t: Target) { applyPower(on, t) }

    func setBrightness(_ percent: Int) { applyBrightness(percent, target) }

    private func applyBrightness(_ percent: Int, _ t: Target) {
        update(t) { $0.brightness = percent }
        send(.bright(percent), to: t)
    }

    func setSpeed(_ percent: Int) {
        let t = target
        update(t) { $0.speed = percent }
        // Flow-Effekte lesen das Tempo selbst, nur die eingebauten Effekte brauchen den Befehl
        for light in lightsOf(t) where looks[light.id]?.builtin != nil {
            hub.send(.speed(percent), to: light)
        }
    }

    func pick(_ c: RGB, instant: Bool = false, swatch index: Int? = nil, bar which: Bar? = nil) {
        swatch = index
        bar = which
        sceneID = nil
        applyColor(c, target, instant: instant)
    }

    private func applyColor(_ c: RGB, _ t: Target, instant: Bool) {
        if lookOf(t).power != true { applyPower(true, t) }
        update(t) {
            $0.base = c
            $0.flowID = nil
            $0.builtin = nil
            $0.builtinFamily = nil
        }
        let ids = ids(for: t)
        if instant {
            release(ids)
            for id in ids { emit(c, id, force: true) }
        } else {
            fade(ids, to: c)
        }
        stopMeterIfUnused()
    }

    /// Farbton-Leiste, f = 0…1 von links nach rechts
    func dragHue(_ f: Double) {
        huePos = f
        pick(ColorMath.hsv(min(f, 0.999) * 360, 1, 1), instant: true, bar: .hue)
    }

    /// Weißton-Leiste von warm bis kalt, f = 0…1
    func dragWhite(_ f: Double) {
        whitePos = f
        let w = Self.whites
        let x = f * Double(w.count - 1)
        let i = min(Int(x.rounded(.down)), w.count - 2)
        let e = x - Double(i)
        func between(_ a: Int, _ b: Int) -> Int {
            ColorMath.jsRound(Double(a) + Double(b - a) * e)
        }
        let c = RGB(between(w[i].r, w[i + 1].r), between(w[i].g, w[i + 1].g), between(w[i].b, w[i + 1].b))
        pick(c, instant: true, bar: .white)
    }

    /// Flow starten; nochmal tippen = bei der aktuellen Farbe anhalten
    func toggleFlow(_ f: Flow) {
        swatch = nil
        bar = nil
        sceneID = nil
        applyFlow(f, target, toggle: true)
    }

    private func applyFlow(_ f: Flow, _ t: Target, toggle: Bool) {
        if toggle && lookOf(t).flowID == f.id {
            release(ids(for: t))
            update(t) { $0.flowID = nil }
            stopMeterIfUnused()
            return
        }
        if lookOf(t).power != true { applyPower(true, t) }
        update(t) {
            $0.flowID = f.id
            $0.builtin = nil
            $0.builtinFamily = nil
        }
        startFlow(f, t)
        stopMeterIfUnused()
    }

    /// Eingebauten Effekt starten. Er geht nur an die Lichter der passenden Bauart.
    func startBuiltin(_ code: UInt8, family: EffectFamily = .elk) {
        let t = target
        swatch = nil
        bar = nil
        sceneID = nil
        let affected = lightsOf(t).filter { $0.model.family == family }
        release(affected.map { $0.id } + (t == .all ? [Self.allKey] : []))
        if lookOf(t).power != true { applyPower(true, t) }
        for light in affected {
            var look = looks[light.id] ?? allLook
            look.builtin = code
            look.builtinFamily = family.rawValue
            look.flowID = nil
            looks[light.id] = look
            hub.send(.effect(code), to: light)
        }
        if t == .all {
            allLook.builtin = code
            allLook.builtinFamily = family.rawValue
            allLook.flowID = nil
        }
        saveSoon()
        stopMeterIfUnused()
    }

    /// Ein Licht kurz blinken lassen, damit man sieht, welches es ist
    func identify(_ light: Light) {
        guard light.state == .on else { return }
        Task { @MainActor [self] in
            for on in [false, true, false, true] {
                hub.send(.power(on), to: light)
                try? await Task.sleep(for: .milliseconds(380))
            }
            if looks[light.id]?.power == false { hub.send(.power(false), to: light) }
        }
    }

    // MARK: - Szenen

    func apply(_ scene: LightScene) { applyScene(scene, target) }

    private func applyScene(_ scene: LightScene, _ t: Target) {
        applyBrightness(scene.brightness, t)
        update(t) { $0.speed = scene.speed }
        if let id = scene.flowID, let f = Flow.all.first(where: { $0.id == id }) {
            update(t) { $0.base = scene.color }
            if lookOf(t).flowID != f.id { applyFlow(f, t, toggle: false) }     // läuft er schon, nicht anhalten
        } else {
            applyColor(scene.color, t, instant: false)
        }
        if t == target { sceneID = scene.id }
    }

    /// Aktuelle Farbe oder laufenden Flow samt Helligkeit und Tempo als Szene speichern
    func saveScene(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let flow = flowID == Flow.music.id ? nil : flowID
        let scene = LightScene(name: trimmed.isEmpty ? suggestedSceneName : trimmed, color: base, flowID: flow,
                               brightness: brightness, speed: speed)
        scenes.append(scene)
        sceneID = scene.id
        Store.save(scenes, key: Self.scenesKey)
    }

    func deleteScene(_ scene: LightScene) {
        scenes.removeAll { $0.id == scene.id }
        if sceneID == scene.id { sceneID = nil }
        Store.save(scenes, key: Self.scenesKey)
    }

    // MARK: - Kurzbefehle (ledcontrol://…), wirken immer auf alle Lichter

    /// Befehle von außen, z. B. aus der Kurzbefehle-App:
    /// ledcontrol://on · off · toggle · color?hex=FF7A00 · brightness?value=40 · scene?name=Kino · flow?id=rainbow
    func handle(url: URL) {
        guard url.scheme?.lowercased() == "ledcontrol" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var values: [String: String] = [:]
        for item in items { values[item.name.lowercased()] = item.value ?? "" }
        run((url.host ?? "").lowercased(), values)
    }

    /// Befehl ausführen; ohne Verbindung wartet er, bis das erste Licht verbunden ist
    func run(_ action: String, _ values: [String: String] = [:]) {
        start()
        guard let job = job(for: action, values) else {
            note("Kurzbefehl nicht erkannt: \(action)")
            return
        }
        if demo || hub.hasTargets {
            job()
        } else {
            pending = [job]
            note("Kurzbefehl wartet auf die Verbindung …")
        }
    }

    private func job(for action: String, _ values: [String: String]) -> (() -> Void)? {
        switch action {
        case "on", "an":
            return { [weak self] in self?.applyPower(true, .all) }
        case "off", "aus":
            return { [weak self] in self?.applyPower(false, .all) }
        case "toggle":
            return { [weak self] in
                guard let self else { return }
                self.applyPower(self.allLook.power != true, .all)
            }
        case "color", "farbe":
            guard let c = RGB(hexString: values["hex"] ?? "") else { return nil }
            return { [weak self] in self?.applyColor(c, .all, instant: false) }
        case "brightness", "helligkeit":
            guard let v = Int(values["value"] ?? "") else { return nil }
            return { [weak self] in self?.applyBrightness(min(max(v, 0), 100), .all) }
        case "scene", "szene":
            let name = (values["name"] ?? "").lowercased()
            guard let scene = scenes.first(where: { $0.name.lowercased() == name }) else { return nil }
            return { [weak self] in self?.applyScene(scene, .all) }
        case "flow", "effekt":
            guard let f = Flow.all.first(where: { $0.id == values["id"] }) else { return nil }
            return { [weak self] in self?.applyFlow(f, .all, toggle: false) }
        default:
            return nil
        }
    }
}
