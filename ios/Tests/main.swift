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

// Bauarten am Namen erkennen. Automatisch übernommen wird nur die eigene ELK-Leiste, nie ein MELK-Licht.
func model(_ name: String?) -> String { LightModel.detect(name)?.prefix ?? "-" }
expect(model("ELK-BLEDDM") == "ELK-BLED", "ELK-BLEDDM -> \(model("ELK-BLEDDM"))")
expect(model("ELK-BLEDOM") == "ELK-BLED", "ELK-BLEDOM -> \(model("ELK-BLEDOM"))")
expect(model("elk-bledom   ") == "ELK-BLED", "Kleinschreibung -> \(model("elk-bledom   "))")
expect(model("ELK-BULB2") == "ELK-", "ELK-BULB2 -> \(model("ELK-BULB2"))")
expect(model("MELK-OA10") == "MELK-OA10", "MELK-OA10 -> \(model("MELK-OA10"))")
expect(model("melk-og10 ") == "MELK-OG10", "melk-og10 -> \(model("melk-og10 "))")
expect(model("MELK-OA21") == "MELK-OA21", "MELK-OA21 -> \(model("MELK-OA21"))")
expect(model("MELK-XYZ") == "MELK", "MELK-XYZ -> \(model("MELK-XYZ"))")
expect(model("LEDBLE-1234") == "-", "LEDBLE darf nicht erkannt werden")
expect(model(nil) == "-", "Gerät ohne Namen darf nicht erkannt werden")
expect(LightModel.detect("ELK-BLEDDM")?.autoAdopt == true, "ELK-Leiste muss automatisch übernommen werden")
for name in ["MELK-OA10", "MELK", "ELK-BULB", "MELK-OG10"] {
    expect(LightModel.detect(name)?.autoAdopt == false, "\(name) darf nicht automatisch übernommen werden")
}
for m in LightModel.all + [LightModel.generic] {
    expect(LightModel.find(prefix: m.prefix)?.prefix == m.prefix, "Bauart \(m.prefix) muss wiedergefunden werden")
}

// Die ELK-Leiste spricht genau die Befehle aus index.html
let elk = LightModel.elk
expect(Order.power(true).bytes(for: elk) == Command.on, "ELK an")
expect(Order.power(false).bytes(for: elk) == Command.off, "ELK aus")
for v in [0, 1, 37, 100] {
    expect(Order.bright(v).bytes(for: elk) == Command.bright(v), "ELK Helligkeit \(v)")
    expect(Order.speed(v).bytes(for: elk) == Command.speed(v), "ELK Tempo \(v)")
}
for e in BuiltinEffect.all {
    expect(Order.effect(e.code).bytes(for: elk) == Command.effect(e.code), "ELK Effekt \(e.code)")
}

// MELK-Bauarten: Bytes wie in models.json von elkbledom (Wert an Stelle 3)
struct MelkCase { let prefix: String; let on: [UInt8]; let off: [UInt8]; let bright: [UInt8] }
let melkCases = [
    MelkCase(prefix: "MELK", on: [126, 0, 4, 1, 0, 0, 0, 0, 239], off: [126, 0, 4, 0, 0, 0, 255, 0, 239],
             bright: [126, 4, 1, 55, 255, 0, 255, 0, 239]),
    MelkCase(prefix: "MELK-OG10", on: [126, 7, 4, 255, 0, 1, 2, 1, 239], off: [126, 7, 4, 0, 0, 0, 2, 0, 239],
             bright: [126, 4, 1, 55, 255, 0, 255, 0, 239]),
    MelkCase(prefix: "MELK-OF10", on: [126, 4, 4, 240, 0, 1, 255, 0, 239], off: [126, 4, 4, 0, 0, 0, 255, 0, 239],
             bright: [126, 4, 1, 55, 1, 255, 255, 0, 239]),
    MelkCase(prefix: "MELK-OC10", on: [126, 4, 4, 240, 0, 1, 255, 0, 239], off: [126, 4, 4, 0, 0, 0, 255, 0, 239],
             bright: [126, 4, 1, 55, 1, 255, 255, 0, 239]),
    MelkCase(prefix: "MELK-OA10", on: [126, 4, 4, 240, 0, 1, 255, 0, 239], off: [126, 4, 4, 0, 0, 0, 255, 0, 239],
             bright: [126, 4, 1, 55, 1, 255, 255, 0, 239]),
    MelkCase(prefix: "MELK-OA21", on: [126, 4, 4, 240, 0, 1, 255, 0, 239], off: [126, 4, 4, 0, 0, 0, 255, 0, 239],
             bright: [126, 4, 1, 55, 1, 255, 255, 0, 239]),
]
for c in melkCases {
    guard let m = LightModel.find(prefix: c.prefix) else {
        expect(false, "Bauart \(c.prefix) fehlt")
        continue
    }
    expect(m.on == c.on, "\(c.prefix) an = \(m.on)")
    expect(m.off == c.off, "\(c.prefix) aus = \(m.off)")
    expect(m.bright(55) == c.bright, "\(c.prefix) Helligkeit = \(m.bright(55))")
    expect(m.effect(48) == [126, 5, 3, 48, 6, 255, 255, 0, 239], "\(c.prefix) Effekt = \(m.effect(48))")
    expect(m.speed(70) == [126, 4, 2, 70, 255, 255, 255, 0, 239], "\(c.prefix) Tempo = \(m.speed(70))")
    expect(m.color(RGB(1, 2, 3)) == [126, 0, 5, 3, 1, 2, 3, 0, 239], "\(c.prefix) Farbe")
    expect(m.login == [[0x7e, 0x07, 0x83], [0x7e, 0x04, 0x04]], "\(c.prefix) Anmeldung")
    expect(m.family != .elk, "\(c.prefix) braucht eigene Effekte")
}
expect(LightModel.elk.login.isEmpty, "ELK-Leiste braucht keine Anmeldung")

// Jede Bauart hat Effekte mit eindeutigen Nummern
for family in EffectFamily.allCases {
    let codes = family.effects.map { $0.code }
    expect(!codes.isEmpty && Set(codes).count == codes.count, "Effekte \(family) doppelt oder leer")
}

// Warteschlange mit eigener Farb-Übersetzung je Licht
var custom = SendQueue(encode: { c in [0xaa, UInt8(c.r)] })
custom.color(RGB(7, 0, 0))
expect(custom.next() == [0xaa, 7], "eigene Farb-Übersetzung")

// Kurzbefehl-Farben und Update-Kennungen
expect(RGB(hexString: "FF7A00") == RGB(255, 122, 0), "Hex FF7A00")
expect(RGB(hexString: "#00e5ff") == RGB(0, 229, 255), "Hex #00e5ff")
expect(RGB(hexString: "12345") == nil, "Hex mit 5 Stellen")
expect(RGB(hexString: "GGGGGG") == nil, "Hex mit Buchstaben")
let parsed = Updater.parse(tag: "ios-v1.1.42", page: "https://github.com/Feuerbrand/led-app/releases/tag/ios-v1.1.42")
expect(parsed?.build == 42 && parsed?.version == "1.1.42", "Release-Kennung ios-v1.1.42")
expect(Updater.parse(tag: "v2", page: "https://x") == nil, "fremde Release-Kennung")
expect(Updater.addSourceLink.absoluteString.hasPrefix("altstore://source?url=https"), "AltStore-Link \(Updater.addSourceLink)")

// Musik-Modus: leise = fast dunkel, laut = volle Helligkeit, Farbe wandert
let quiet = Flow.music.color(at: 0, base: RGB(0, 0, 0), level: 0)
let loud = Flow.music.color(at: 0, base: RGB(0, 0, 0), level: 1)
expect(quiet.peak < 20 && loud == RGB(255, 0, 0), "Musik leise \(quiet), laut \(loud)")
expect(Flow.everything.count == Flow.all.count + 1, "Musik-Modus fehlt in der Gesamtliste")

print("\(checks) Prüfungen, \(failures) Fehler")
exit(failures == 0 ? 0 : 1)
