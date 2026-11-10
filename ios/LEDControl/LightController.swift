import Foundation
import Observation
import QuartzCore

/// Zustand der App und die Lichtlogik aus index.html: An/Aus, Farbe, Flow-Effekte, Senden.
/// Läuft komplett auf dem Hauptthread.
@Observable
final class LightController {
    enum Bar {
        case hue, white
    }

    // MARK: - Was die Oberfläche anzeigt

    private(set) var link: LinkState = .busy
    private(set) var status = "Bluetooth startet …"
    private(set) var log = ""
    /// Zählt bei jeder neuen Verbindung hoch (löst den Lichtring aus)
    private(set) var connectedCount = 0

    /// nil = unbekannt, sonst zuletzt gesendeter Zustand
    private(set) var power: Bool? = nil
    /// Zuletzt gewählte feste Farbe (Grundfarbe für „Atmen“)
    private(set) var base = RGB(255, 0, 0)
    /// Farbe der Leiste, wie sie in der Oberfläche leuchtet (gedrosselt nachgeführt)
    private(set) var led = RGB(255, 210, 63)
    private(set) var flowID: String? = nil
    private(set) var builtin: UInt8? = nil
    private(set) var swatch: Int? = nil
    private(set) var bar: Bar? = nil
    private(set) var huePos = 0.0
    private(set) var whitePos = 0.0
    private(set) var brightness = 100
    private(set) var speed = 50

    /// Verbunden und nicht ausgeschaltet -> die Oberfläche leuchtet in der Farbe der Leiste
    var live: Bool { link == .on && power != false }

    /// Bildschirm anlassen, solange ein Flow läuft (sonst hält iOS die App an).
    /// Nach „Trennen“ darf das iPhone wieder normal schlafen.
    var keepAwake: Bool { flowID != nil && link != .off }

    // MARK: - Intern

    private let ble = BLEManager()
    @ObservationIgnored private var queue = SendQueue()
    @ObservationIgnored private var pumping = false
    @ObservationIgnored private var cur = RGB(255, 0, 0)     // zuletzt ausgegebene Farbe
    @ObservationIgnored private var anim = 0                 // Nummer der laufenden Farb-Animation (Flow oder Überblendung)
    @ObservationIgnored private var phase = 0.0
    @ObservationIgnored private var glowAt = 0.0

    private static let whites = [RGB(255, 147, 41), RGB(255, 214, 170), RGB(255, 255, 255), RGB(201, 226, 255)]

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init() {
        ble.onState = { [weak self] state, text in self?.setLink(state, text) }
        ble.onLog = { [weak self] message in self?.note(message) }
        ble.onReady = { [weak self] in self?.linkReady() }
        ble.onLost = { [weak self] in self?.queue.clear() }
        note("Bereit. Lotus Lamp X vorher schließen!")
    }

    // MARK: - Verbindung

    /// Beim App-Start: Bluetooth einschalten, die Leiste wird dann von selbst gesucht
    func start() { ble.start() }
    func connect() { ble.connect() }
    func disconnect() { ble.disconnect() }
    func resume() { ble.resume() }

    private func setLink(_ state: LinkState, _ text: String) {
        if link != state { link = state }
        if status != text { status = text }
    }

    private func linkReady() {
        queue.forgetLast()
        connectedCount += 1
    }

    private func note(_ message: String) {
        let line = Self.clock.string(from: Date()) + "  " + message + "\n"
        log = String((line + log).prefix(2000))
    }

    // MARK: - Senden

    /// Schickt die Warteschlange an die Leiste, mit 28 ms Pause zwischen zwei Paketen (rund 25 pro Sekunde).
    private func pump() {
        if pumping { return }
        pumping = true
        Task { @MainActor [self] in
            var stalled = 0
            while ble.isReady, !queue.isEmpty {
                if !ble.canSend, stalled < 12 {
                    // Sendepuffer von iOS ist voll: kurz warten, nichts verwerfen
                    stalled += 1
                    try? await Task.sleep(for: .milliseconds(15))
                    continue
                }
                stalled = 0
                guard let bytes = queue.next() else { continue }
                ble.write(bytes)
                try? await Task.sleep(for: .milliseconds(28))
            }
            if !ble.isReady { queue.clear() }
            pumping = false
        }
    }

    private func sendCtrl(_ key: String, _ bytes: [UInt8]) {
        queue.control(key, bytes)
        pump()
    }

    /// Farbe ausgeben: an die Leiste schicken und in der Oberfläche spiegeln (höchstens alle 80 ms)
    private func show(_ c: RGB, force: Bool = false) {
        cur = c
        queue.color(c)
        pump()
        let now = CACurrentMediaTime()
        if force || now - glowAt >= 0.08 {
            glowAt = now
            if led != c { led = c }
        }
    }

    // MARK: - Licht

    func setPower(_ on: Bool) {
        power = on
        sendCtrl("power", on ? Command.on : Command.off)
    }

    func setBrightness(_ percent: Int) {
        brightness = percent
        sendCtrl("bright", Command.bright(percent))
    }

    func setSpeed(_ percent: Int) {
        speed = percent
        // Flow-Effekte lesen das Tempo direkt, nur die eingebauten Effekte brauchen den Befehl
        if builtin != nil { sendCtrl("speed", Command.speed(percent)) }
    }

    /// Laufende Animation beenden, die Leiste bleibt auf der aktuellen Farbe
    private func halt() {
        anim += 1
        if flowID != nil { flowID = nil }
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
        swatch = index
        bar = which
        if power != true { setPower(true) }
        base = c
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
        swatch = nil
        bar = nil
        if power != true { setPower(true) }
        flowID = f.id
        if f.kind == .rainbow { phase = ColorMath.hue(of: cur) / 360 }      // beim aktuellen Farbton einsteigen
        let from = cur
        anim += 1
        let my = anim
        let t0 = CACurrentMediaTime()
        Task { @MainActor [self] in
            var last = t0
            while my == anim {
                let now = CACurrentMediaTime()
                let dt = min(now - last, 0.1)
                last = now
                if link == .on, power != false {
                    phase = (phase + dt * f.rate / period).truncatingRemainder(dividingBy: 1)
                    var c = f.color(at: phase, base: base)
                    let k = (now - t0) / 0.9                                // Einstieg: 0,9 s von der alten Farbe überblenden
                    if k < 1 { c = ColorMath.mix(from, c, ColorMath.ease(k)) }
                    show(c)
                }
                try? await Task.sleep(for: .milliseconds(34))
            }
        }
    }

    func startBuiltin(_ code: UInt8) {
        halt()
        swatch = nil
        bar = nil
        if power != true { setPower(true) }
        builtin = code
        sendCtrl("effect", Command.effect(code))
    }
}
