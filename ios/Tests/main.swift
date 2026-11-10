// Selbsttest ohne iPhone: vergleicht die Logik der App mit Soll-Werten aus index.html.
// Die Soll-Werte in expected.json erzeugt make-expected.mjs mit dem echten Code der Webseite.
// Läuft im Build-Workflow auf dem Mac:  check Tests/expected.json
import Foundation

struct Expected: Decodable {
    struct HSV: Decodable { let h, s, v: Double; let out: [Int] }
    struct Hue: Decodable { let rgb: [Int]; let out: Double }
    struct Mix: Decodable { let a, b: [Int]; let e: Double; let out: [Int] }
    struct FlowCase: Decodable { let id: String; let rate: Double; let base: [Int]; let t: Double; let out: [Int] }
    struct Period: Decodable { let speed: Int; let out: Double }
    struct BarCase: Decodable { let f: Double; let out: [Int] }
    struct Cmd: Decodable { let name: String; let args: [Int]; let out: [UInt8] }
    struct Op: Decodable { let key: String?; let bytes: [UInt8]?; let color: [Int]? }
    struct Queue: Decodable { let batches: [[Op]]; let out: [[UInt8]] }

    let hsv: [HSV]
    let hue: [Hue]
    let mix: [Mix]
    let flows: [FlowCase]
    let period: [Period]
    let hueBar: [BarCase]
    let whiteBar: [BarCase]
    let commands: [Cmd]
    let queue: [Queue]
}

var checks = 0
var failures = 0

func expect(_ ok: Bool, _ what: @autoclosure () -> String) {
    checks += 1
    if ok { return }
    failures += 1
    if failures <= 25 { print("FEHLER: " + what()) }
}

func rgb(_ a: [Int]) -> RGB { RGB(a[0], a[1], a[2]) }
func list(_ c: RGB) -> [Int] { [c.r, c.g, c.b] }

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "expected.json"
let expected = try JSONDecoder().decode(Expected.self, from: Data(contentsOf: URL(fileURLWithPath: path)))

// Farbrechnung
for c in expected.hsv {
    let got = list(ColorMath.hsv(c.h, c.s, c.v))
    expect(got == c.out, "hsv(\(c.h), \(c.s), \(c.v)) = \(got), soll \(c.out)")
}
for c in expected.hue {
    let got = ColorMath.hue(of: rgb(c.rgb))
    expect(abs(got - c.out) < 1e-9, "hue(\(c.rgb)) = \(got), soll \(c.out)")
}
for c in expected.mix {
    let got = list(ColorMath.mix(rgb(c.a), rgb(c.b), c.e))
    expect(got == c.out, "mix(\(c.a), \(c.b), \(c.e)) = \(got), soll \(c.out)")
}

// Flow-Effekte: gleiche Reihenfolge, gleiches Tempo-Verhältnis, gleiche Farben
var order: [String] = []
for c in expected.flows where order.last != c.id { order.append(c.id) }
expect(Flow.all.map { $0.id } == order, "Flows \(Flow.all.map { $0.id }), soll \(order)")
for c in expected.flows {
    guard let flow = Flow.all.first(where: { $0.id == c.id }) else {
        expect(false, "Flow \(c.id) fehlt")
        continue
    }
    let got = list(flow.color(at: c.t, base: rgb(c.base)))
    expect(flow.rate == c.rate, "Flow \(c.id): rate \(flow.rate), soll \(c.rate)")
    expect(got == c.out, "Flow \(c.id) bei t=\(c.t), Grundfarbe \(c.base) = \(got), soll \(c.out)")
}

// Tempo-Regler und die beiden Farbleisten (über die echte Steuerlogik der App)
let light = LightController()
for c in expected.period {
    light.setSpeed(c.speed)
    expect(abs(light.period - c.out) < 1e-9, "Tempo \(c.speed) = \(light.period) s, soll \(c.out) s")
}
for c in expected.hueBar {
    light.dragHue(c.f)
    expect(list(light.base) == c.out, "Farbton-Leiste \(c.f) = \(list(light.base)), soll \(c.out)")
}
for c in expected.whiteBar {
    light.dragWhite(c.f)
    expect(list(light.base) == c.out, "Weißton-Leiste \(c.f) = \(list(light.base)), soll \(c.out)")
}

// Befehle an die Leiste
var effectCodes: [Int] = []
for c in expected.commands {
    let got: [UInt8]
    switch c.name {
    case "on": got = Command.on
    case "off": got = Command.off
    case "color": got = Command.color(rgb(c.args))
    case "bright": got = Command.bright(c.args[0])
    case "speed": got = Command.speed(c.args[0])
    case "effect":
        got = Command.effect(UInt8(c.args[0]))
        effectCodes.append(c.args[0])
    default: got = []
    }
    expect(got == c.out, "Befehl \(c.name) \(c.args) = \(got), soll \(c.out)")
}
expect(BuiltinEffect.all.map { Int($0.code) } == effectCodes, "Eingebaute Effekte \(BuiltinEffect.all.map { $0.code })")

// Sende-Warteschlange: jede Gruppe komplett einreihen, dann leeren (wie pump)
for (n, scenario) in expected.queue.enumerated() {
    var queue = SendQueue()
    var sent: [[UInt8]] = []
    for batch in scenario.batches {
        for op in batch {
            if let c = op.color {
                queue.color(rgb(c))
            } else if let key = op.key, let bytes = op.bytes {
                queue.control(key, bytes)
            }
        }
        while !queue.isEmpty {
            if let bytes = queue.next() { sent.append(bytes) }
        }
    }
    expect(sent == scenario.out, "Warteschlange \(n + 1): \(sent), soll \(scenario.out)")
}

// Nur die eigene Leiste, nie der MELK-Controller nebenan
expect(BLEManager.isStrip("ELK-BLEDDM"), "ELK-BLEDDM muss erkannt werden")
expect(BLEManager.isStrip("ELK-BLEDOM"), "ELK-BLEDOM muss erkannt werden")
expect(BLEManager.isStrip("elk-bledom   "), "Kleinschreibung muss erkannt werden")
expect(!BLEManager.isStrip("MELK-OA10"), "MELK-… darf nicht erkannt werden")
expect(!BLEManager.isStrip("ELK-BLE"), "ELK-BLE darf nicht erkannt werden")
expect(!BLEManager.isStrip(nil), "Gerät ohne Namen darf nicht erkannt werden")

print("\(checks) Prüfungen, \(failures) Fehler")
exit(failures == 0 ? 0 : 1)
