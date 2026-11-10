import Foundation
import Observation
import QuartzCore

/// Zustand der App und die Lichtlogik aus index.html: An/Aus, Farbe, Flow-Effekte, Tempo.
/// Dazu Szenen, Musik-Modus und Kurzbefehle. Alles geht an alle verbundenen Lichter zugleich.
/// Läuft komplett auf dem Hauptthread.
@Observable
final class LightController {
    enum Bar {
        case hue, white
    }

    /// Eine Instanz für die ganze App (auch für Siri und Kurzbefehle)
    static let shared = LightController()

    /// Bluetooth und die Liste der Lichter
    let hub = LightHub()

    // MARK: - Was die Oberfläche anzeigt

    private(set) var log = ""
    /// Zählt bei jeder neuen Verbindung hoch (löst den Lichtring aus)
    private(set) var connectedCount = 0

    /// nil = unbekannt, sonst zuletzt gesendeter Zustand
    private(set) var power: Bool? = nil
    /// Zuletzt gewählte feste Farbe (Grundfarbe für „Atmen“)
    private(set) var base = RGB(255, 0, 0)
    /// Farbe der Lichter, wie sie in der Oberfläche leuchtet (gedrosselt nachgeführt)
    private(set) var led = RGB(255, 210, 63)
    private(set) var flowID: String? = nil
    private(set) var builtin: UInt8? = nil
    private(set) var builtinFamily: EffectFamily? = nil
    private(set) var swatch: Int? = nil
    private(set) var bar: Bar? = nil
    private(set) var huePos = 0.0
    private(set) var whitePos = 0.0
    private(set) var brightness = 100
    private(set) var speed = 50
    private(set) var scenes: [LightScene] = []
    /// Zuletzt gewählte Szene (für die Markierung)
    private(set) var sceneID: UUID? = nil

    var link: LinkState { hub.summary }
    var status: String { hub.statusText }

    /// Verbunden und nicht ausgeschaltet -> die Oberfläche leuchtet in der Farbe der Lichter
    var live: Bool { hub.hasTargets && power != false }

    /// Bildschirm anlassen, solange ein Flow läuft (sonst hält iOS die App an).
    /// Ist alles getrennt, darf das iPhone wieder normal schlafen.
    var keepAwake: Bool { flowID != nil && hub.summary != .off }

    /// Vorschlag für den Namen einer neuen Szene
    var suggestedSceneName: String {
        if let id = flowID, let flow = Flow.all.first(where: { $0.id == id }) { return flow.name }
        return "Farbe \(base.hex)"
    }

    // MARK: - Intern

    @ObservationIgnored private let meter = SoundMeter()
    @ObservationIgnored private var cur = RGB(255, 0, 0)     // zuletzt ausgegebene Farbe
    @ObservationIgnored private var anim = 0                 // Nummer der laufenden Farb-Animation (Flow oder Überblendung)
    @ObservationIgnored private var phase = 0.0
    @ObservationIgnored private var glowAt = 0.0
    @ObservationIgnored private var brightnessTouched = false
    @ObservationIgnored private var pending: [() -> Void] = []   // Kurzbefehl, der auf die Verbindung wartet

    private static let whites = [RGB(255, 147, 41), RGB(255, 214, 170), RGB(255, 255, 255), RGB(201, 226, 255)]
    private static let stateKey = "led-app.state"
    private static let scenesKey = "led-app.scenes"

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init() {
        if let saved = Store.load(SavedState.self, key: Self.stateKey) {
            brightness = min(max(saved.brightness, 0), 100)
            speed = min(max(saved.speed, 0), 100)
            base = RGB(saved.red, saved.green, saved.blue)
            cur = base
        }
        scenes = Store.load([LightScene].self, key: Self.scenesKey) ?? LightScene.starters
        hub.onLog = { [weak self] message in self?.note(message) }
        hub.onReady = { [weak self] light in self?.sync(light) }
        note("Bereit. Lotus Lamp X vorher schließen!")
    }

    // MARK: - Verbindung

    /// Beim App-Start: Bluetooth einschalten, die Lichter werden dann von selbst gesucht
    func start() { hub.start() }
    func resume() { hub.resume() }

    /// Ein Licht ist frisch verbunden: den aktuellen Zustand übertragen, damit alle Lichter gleich aussehen.
    /// Solange in der App noch nichts eingestellt wurde, bleibt das Licht, wie es ist.
    private func sync(_ light: Light) {
        connectedCount += 1
        if power == false {
            hub.send(.power(false), to: light)
        } else {
            // Die MELK-Anmeldung schaltet das Licht aus -> wieder einschalten
            if power == true || !light.model.login.isEmpty { hub.send(.power(true), to: light) }
            if power == true {
                if brightnessTouched { hub.send(.bright(brightness), to: light) }
                if let code = builtin, builtinFamily == light.model.family {
                    hub.send(.effect(code), to: light)
                } else if flowID == nil {
                    hub.send(color: cur, to: light)
                }
                // Ein laufender Flow erreicht das neue Licht von selbst mit dem nächsten Farbwert
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

    private func saveState() {
        Store.save(SavedState(brightness: brightness, speed: speed, red: base.r, green: base.g, blue: base.b), key: Self.stateKey)
    }

    // MARK: - Licht

    /// Farbe ausgeben: an die Lichter schicken und in der Oberfläche spiegeln (höchstens alle 80 ms)
    private func show(_ c: RGB, force: Bool = false) {
        cur = c
        hub.send(color: c)
        let now = CACurrentMediaTime()
        if force || now - glowAt >= 0.08 {
            glowAt = now
            if led != c { led = c }
        }
    }

    func setPower(_ on: Bool) {
        power = on
        hub.send(.power(on))
    }

    func setBrightness(_ percent: Int) {
        brightness = percent
        brightnessTouched = true
        hub.send(.bright(percent))
        saveState()
    }

    func setSpeed(_ percent: Int) {
        speed = percent
        // Flow-Effekte lesen das Tempo direkt, nur die eingebauten Effekte brauchen den Befehl
        if builtin != nil { hub.send(.speed(percent), only: builtinFamily) }
        saveState()
    }

    /// Laufende Animation beenden, die Lichter bleiben auf der aktuellen Farbe
    private func halt() {
        anim += 1
        if flowID != nil { flowID = nil }
        if meter.running { meter.stop() }
    }

    /// Weich von der aktuellen zur neuen Farbe
    private func fade(to target: RGB, ms: Double) {
        let from = cur
        anim += 1
        let my = anim
        let t0 = CACurrentMediaTime()
        Task { @MainActor [self] in
            while my == anim {
                let k = min(1, (CACurrentMediaTime() - t0) * 1000 / ms)
                show(ColorMath.mix(from, target, ColorMath.ease(k)), force: true)
                if k >= 1 { return }
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    /// Sekunden pro Durchlauf: Tempo 0 = langsam (90 s) … 100 = schnell (3 s)
    var period: Double {
        90 * pow(3.0 / 90.0, Double(speed) / 100)
    }

    func pick(_ c: RGB, instant: Bool = false, swatch index: Int? = nil, bar which: Bar? = nil) {
        halt()
        builtin = nil
        builtinFamily = nil
        sceneID = nil
        swatch = index
        bar = which
        if power != true { setPower(true) }
        base = c
        saveState()
        if instant {
            show(c, force: true)
        } else {
            fade(to: c, ms: 350)
        }
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
        if flowID == f.id {
            halt()
            return
        }
        halt()
        builtin = nil
        builtinFamily = nil
        sceneID = nil
        swatch = nil
        bar = nil
        if power != true { setPower(true) }
        flowID = f.id
        if f.kind == .rainbow || f.kind == .music { phase = ColorMath.hue(of: cur) / 360 }   // beim aktuellen Farbton einsteigen
        let from = cur
        anim += 1
        let my = anim
        let t0 = CACurrentMediaTime()
        if f.kind == .music { startListening(my) }
        Task { @MainActor [self] in
            var last = t0
            var envelope = 0.0
            while my == anim {
                let now = CACurrentMediaTime()
                let dt = min(now - last, 0.1)
                last = now
                if hub.hasTargets, power != false {
                    phase = (phase + dt * f.rate / period).truncatingRemainder(dividingBy: 1)
                    // Musik: sofort hochschnellen, langsamer abklingen
                    envelope = max(meter.level, envelope * 0.86)
                    var c = f.color(at: phase, base: base, level: envelope)
                    let k = (now - t0) / 0.9                                // Einstieg: 0,9 s von der alten Farbe überblenden
                    if k < 1 { c = ColorMath.mix(from, c, ColorMath.ease(k)) }
                    show(c)
                }
                try? await Task.sleep(for: .milliseconds(34))
            }
        }
    }

    /// Mikrofon für den Musik-Modus einschalten; ohne Erlaubnis hält der Flow wieder an
    private func startListening(_ my: Int) {
        meter.start { [weak self] ok in
            guard let self else { return }
            if self.anim != my {
                // Inzwischen wurde etwas anderes gewählt
                if self.flowID != Flow.music.id { self.meter.stop() }
                return
            }
            if !ok {
                self.note("Musik-Modus: Mikrofon nicht verfügbar. Erlauben unter Einstellungen → Apps → LED Control → Mikrofon.")
                self.halt()
            }
        }
    }

    /// Eingebauten Effekt starten. Er geht nur an die Lichter der passenden Bauart.
    func startBuiltin(_ code: UInt8, family: EffectFamily = .elk) {
        halt()
        sceneID = nil
        swatch = nil
        bar = nil
        if power != true { setPower(true) }
        builtin = code
        builtinFamily = family
        hub.send(.effect(code), only: family)
    }

    /// Ein Licht kurz blinken lassen, damit man sieht, welches es ist
    func identify(_ light: Light) {
        guard light.state == .on else { return }
        Task { @MainActor [self] in
            for on in [false, true, false, true] {
                hub.send(.power(on), to: light)
                try? await Task.sleep(for: .milliseconds(380))
            }
            if power == false { hub.send(.power(false), to: light) }
        }
    }

    // MARK: - Szenen

    func apply(_ scene: LightScene) {
        setBrightness(scene.brightness)
        setSpeed(scene.speed)
        if let id = scene.flowID, let flow = Flow.all.first(where: { $0.id == id }) {
            base = scene.color
            saveState()
            if flowID != flow.id { toggleFlow(flow) }        // läuft er schon, nicht anhalten
        } else {
            pick(scene.color)
        }
        sceneID = scene.id
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

    // MARK: - Kurzbefehle (ledcontrol://…)

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
        if hub.hasTargets {
            job()
        } else {
            pending = [job]
            note("Kurzbefehl wartet auf die Verbindung …")
        }
    }

    private func job(for action: String, _ values: [String: String]) -> (() -> Void)? {
        switch action {
        case "on", "an":
            return { [weak self] in self?.setPower(true) }
        case "off", "aus":
            return { [weak self] in self?.setPower(false) }
        case "toggle":
            return { [weak self] in
                guard let self else { return }
                self.setPower(self.power != true)
            }
        case "color", "farbe":
            guard let c = RGB(hexString: values["hex"] ?? "") else { return nil }
            return { [weak self] in self?.pick(c) }
        case "brightness", "helligkeit":
            guard let v = Int(values["value"] ?? "") else { return nil }
            return { [weak self] in self?.setBrightness(min(max(v, 0), 100)) }
        case "scene", "szene":
            let name = (values["name"] ?? "").lowercased()
            guard let scene = scenes.first(where: { $0.name.lowercased() == name }) else { return nil }
            return { [weak self] in self?.apply(scene) }
        case "flow", "effekt":
            guard let flow = Flow.all.first(where: { $0.id == values["id"] }) else { return nil }
            return { [weak self] in
                guard let self, self.flowID != flow.id else { return }
                self.toggleFlow(flow)
            }
        default:
            return nil
        }
    }
}
