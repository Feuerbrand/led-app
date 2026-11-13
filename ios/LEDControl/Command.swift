import CoreBluetooth

/// ELK-BLEDOM-Protokoll. Jeder Befehl sind 9 Bytes: 7E … EF.
/// Gleiche Werte wie das Objekt `cmd` in index.html.
enum Command {
    static let service = CBUUID(string: "FFF0")          // 0000fff0-0000-1000-8000-00805f9b34fb
    static let characteristic = CBUUID(string: "FFF3")   // 0000fff3-0000-1000-8000-00805f9b34fb

    static let on: [UInt8] = [0x7e, 0x00, 0x04, 0xf0, 0x00, 0x01, 0xff, 0x00, 0xef]
    static let off: [UInt8] = [0x7e, 0x00, 0x04, 0x00, 0x00, 0x00, 0xff, 0x00, 0xef]

    static func color(_ c: RGB) -> [UInt8] {
        [0x7e, 0x00, 0x05, 0x03, UInt8(clamping: c.r), UInt8(clamping: c.g), UInt8(clamping: c.b), 0x00, 0xef]
    }

    static func bright(_ percent: Int) -> [UInt8] {
        [0x7e, 0x00, 0x01, UInt8(clamping: percent), 0x00, 0x00, 0x00, 0x00, 0xef]
    }

    static func effect(_ code: UInt8) -> [UInt8] {
        [0x7e, 0x00, 0x03, code, 0x03, 0x00, 0x00, 0x00, 0xef]
    }

    static func speed(_ percent: Int) -> [UInt8] {
        [0x7e, 0x00, 0x02, UInt8(clamping: percent), 0x00, 0x00, 0x00, 0x00, 0xef]
    }
}

/// Schnittstelle und Byte-Format einer Bauart
enum Wire: String {
    case elk, triones, sp110e, sp107e, govee

    var services: [CBUUID] {
        switch self {
        case .elk: return [Command.service]
        case .triones: return [Triones.service]
        case .sp110e, .sp107e: return [SP.service]
        case .govee: return [Govee.service]
        }
    }

    /// Mögliche Schreib-Merkmale, das erste vorhandene gewinnt
    var writeChars: [CBUUID] {
        switch self {
        case .elk: return [Command.characteristic, SP.characteristic]     // LEDBLE-Nachbauten: 7E-Befehle auf FFE1
        case .triones: return [Triones.characteristic]
        case .sp110e, .sp107e: return [SP.characteristic]
        case .govee: return [Govee.characteristic]
        }
    }

    static let allServices: [CBUUID] = [Command.service, Triones.service, SP.service, Govee.service]
}

/// HappyLighting / Triones (QHM-…, LEDBlue, Triones, Dream~). Quellen: madhead/saberlight, Bluetooth-Devices/led-ble.
enum Triones {
    static let service = CBUUID(string: "FFD5")
    static let characteristic = CBUUID(string: "FFD9")
    static let on: [UInt8] = [0xcc, 0x23, 0x33]
    static let off: [UInt8] = [0xcc, 0x24, 0x33]

    static func color(_ c: RGB) -> [UInt8] {
        [0x56, UInt8(clamping: c.r), UInt8(clamping: c.g), UInt8(clamping: c.b), 0x00, 0xf0, 0xaa]
    }

    /// Tempo 0…100 % -> Pause 31 (langsam) … 1 (schnell), wie flux_led
    static func delay(_ percent: Int) -> UInt8 {
        let p = Double(min(max(percent, 0), 100))
        return UInt8(max(1, min(31, Int((31 - p * 30 / 100).rounded()))))
    }
}

/// SP110E / SP107E: 4 Bytes, drei Werte und am Ende der Befehl. Quellen: roslovets/SP110E, monty68/uniled.
enum SP {
    static let service = CBUUID(string: "FFE0")
    static let characteristic = CBUUID(string: "FFE1")

    static func frame(_ a: Int, _ b: Int, _ c: Int, _ cmd: UInt8) -> [UInt8] {
        [UInt8(clamping: a), UInt8(clamping: b), UInt8(clamping: c), cmd]
    }
}

/// Govee H6xxx: 20 Bytes, 0x33 + Befehl, am Ende XOR-Prüfsumme. Ohne Lebenszeichen alle 2 s trennt das Licht.
/// Quellen: egold555/Govee-Reverse-Engineering, Beshelmek/govee_ble_lights, Mezzle/govee-bluetooth.
enum Govee {
    static let service = CBUUID(string: "00010203-0405-0607-0809-0A0B0C0D1910")
    static let characteristic = CBUUID(string: "00010203-0405-0607-0809-0A0B0C0D2B11")
    /// Erstes Byte: 0 = unverschlüsselt. Neuere Modelle verschlüsseln, die kann die App nicht steuern.
    static let cipherInfo = CBUUID(string: "00010203-0405-0607-0809-0A0B0C0D2B12")

    static func frame(_ head: UInt8, _ body: [UInt8]) -> [UInt8] {
        var bytes = [head] + body.prefix(18)
        bytes += Array(repeating: 0, count: 19 - bytes.count)
        bytes.append(bytes.reduce(0, ^))
        return bytes
    }

    static func command(_ body: [UInt8]) -> [UInt8] { frame(0x33, body) }

    static let keepAlive = frame(0xaa, [0x01])

    /// Je nach Modell versteht ein Govee-Licht eine andere Farb-Form: alle Segmente (RGBIC),
    /// 0x0D oder die alte „manuelle“ Form. Alle drei tragen dieselbe Farbe, die passende greift.
    static func colors(_ c: RGB) -> [[UInt8]] {
        let r = UInt8(clamping: c.r), g = UInt8(clamping: c.g), b = UInt8(clamping: c.b)
        return [
            command([0x05, 0x15, 0x01, r, g, b, 0, 0, 0, 0, 0, 0xff, 0x7f]),
            command([0x05, 0x0d, r, g, b]),
            command([0x05, 0x02, r, g, b]),
        ]
    }
}

/// Fest eingebauter Effekt eines Lichts (läuft im Licht selbst, auch ohne App).
struct BuiltinEffect: Identifiable {
    let name: String
    let code: UInt8
    var id: UInt8 { code }

    /// Effekte der ELK-BLEDOM-Leiste, wie in index.html
    static let all: [BuiltinEffect] = [
        BuiltinEffect(name: "Springen RGB", code: 0x87),
        BuiltinEffect(name: "Springen bunt", code: 0x88),
        BuiltinEffect(name: "Überblenden RGB", code: 0x89),
        BuiltinEffect(name: "Überblenden bunt", code: 0x8a),
        BuiltinEffect(name: "Effekt 5", code: 0x8b),
        BuiltinEffect(name: "Effekt 6", code: 0x8c),
        BuiltinEffect(name: "Effekt 7", code: 0x8d),
        BuiltinEffect(name: "Blinken bunt", code: 0x95),
    ]
}

/// Welche eingebauten Effekte ein Licht kennt. Die Nummern unterscheiden sich je nach Bauart,
/// deshalb geht ein eingebauter Effekt immer nur an die Lichter derselben Bauart.
enum EffectFamily: String, CaseIterable {
    case elk, melk, melkOx, stripX, triones, sp, govee

    var title: String {
        switch self {
        case .elk: return "Eingebaut: ELK-Leiste"
        case .melk: return "Eingebaut: MELK-Licht"
        case .melkOx: return "Eingebaut: MELK-Licht"
        case .stripX: return "Lauflichter (eingebaut)"
        case .triones: return "Eingebaut: HappyLighting-Leiste"
        case .sp: return "Eingebaut: SP-Leiste"
        case .govee: return "Govee"
        }
    }

    var effects: [BuiltinEffect] {
        switch self {
        case .govee:
            return []                       // Govee-Szenen laufen über die Govee-App, nicht über diese Befehle
        case .sp:
            return (1...12).map { BuiltinEffect(name: "Muster \($0)", code: UInt8($0)) }
        case .triones:
            return [
                BuiltinEffect(name: "Alle Farben überblenden", code: 0x25),
                BuiltinEffect(name: "Rot pulsieren", code: 0x26),
                BuiltinEffect(name: "Grün pulsieren", code: 0x27),
                BuiltinEffect(name: "Blau pulsieren", code: 0x28),
                BuiltinEffect(name: "Gelb pulsieren", code: 0x29),
                BuiltinEffect(name: "Türkis pulsieren", code: 0x2a),
                BuiltinEffect(name: "Lila pulsieren", code: 0x2b),
                BuiltinEffect(name: "Weiß pulsieren", code: 0x2c),
                BuiltinEffect(name: "Rot-Grün", code: 0x2d),
                BuiltinEffect(name: "Rot-Blau", code: 0x2e),
                BuiltinEffect(name: "Grün-Blau", code: 0x2f),
                BuiltinEffect(name: "Alle Farben blitzen", code: 0x30),
                BuiltinEffect(name: "Rot blitzen", code: 0x31),
                BuiltinEffect(name: "Grün blitzen", code: 0x32),
                BuiltinEffect(name: "Blau blitzen", code: 0x33),
                BuiltinEffect(name: "Weiß blitzen", code: 0x37),
                BuiltinEffect(name: "Farben springen", code: 0x38),
            ]
        case .elk:
            return BuiltinEffect.all
        case .melk:
            return [
                BuiltinEffect(name: "Alle Farben", code: 0),
                BuiltinEffect(name: "Sanft überblenden", code: 1),
                BuiltinEffect(name: "Überblenden RGB", code: 5),
                BuiltinEffect(name: "Lauflicht bunt", code: 10),
                BuiltinEffect(name: "Lauflicht schnell", code: 16),
                BuiltinEffect(name: "Überblenden bunt", code: 22),
                BuiltinEffect(name: "Überblenden Rot", code: 26),
                BuiltinEffect(name: "Überblenden Grün", code: 28),
                BuiltinEffect(name: "Überblenden Türkis", code: 33),
                BuiltinEffect(name: "Lauflicht nach außen", code: 58),
                BuiltinEffect(name: "Lauflicht Weiß", code: 75),
                BuiltinEffect(name: "Lauflicht langsam", code: 77),
                BuiltinEffect(name: "Weiß-Blau links", code: 151),
                BuiltinEffect(name: "Weiß-Blau rechts", code: 152),
                BuiltinEffect(name: "Rot-Weiß links", code: 155),
                BuiltinEffect(name: "Rot-Weiß rechts", code: 156),
            ]
        case .melkOx:
            return [
                BuiltinEffect(name: "Automatik", code: 0),
                BuiltinEffect(name: "Magic Back", code: 1),
                BuiltinEffect(name: "Effekt 2", code: 2),
                BuiltinEffect(name: "Effekt 3", code: 3),
                BuiltinEffect(name: "Effekt 4", code: 4),
                BuiltinEffect(name: "Effekt 5", code: 5),
                BuiltinEffect(name: "Regenbogen", code: 16),
                BuiltinEffect(name: "Farbwelle", code: 32),
                BuiltinEffect(name: "Atmen", code: 48),
                BuiltinEffect(name: "Stroboskop", code: 64),
                BuiltinEffect(name: "Springen RGB", code: 128),
                BuiltinEffect(name: "Überblenden RGB", code: 144),
                BuiltinEffect(name: "Blauer Lauf", code: 207),
            ]
        case .stripX:
            return [
                BuiltinEffect(name: "Regenbogen hoch", code: 1),
                BuiltinEffect(name: "Regenbogen runter", code: 2),
                BuiltinEffect(name: "Lauflicht 1", code: 3),
                BuiltinEffect(name: "Lauflicht 2", code: 4),
                BuiltinEffect(name: "Lauflicht 3", code: 5),
                BuiltinEffect(name: "Lauflicht 4", code: 6),
                BuiltinEffect(name: "Lauflicht 5", code: 7),
                BuiltinEffect(name: "Lauflicht 6", code: 8),
                BuiltinEffect(name: "Lauflicht 7", code: 9),
                BuiltinEffect(name: "Lauflicht 8", code: 10),
                BuiltinEffect(name: "Lauflicht Puls 1", code: 11),
                BuiltinEffect(name: "Lauflicht Puls 2", code: 12),
            ]
        }
    }
}

/// Ob die LEDs einer Leiste einzeln angesteuert werden können
enum PixelKind {
    /// RGBIC / WS2812B: Effekte können die Leiste entlanglaufen
    case addressable
    /// Normale RGB-Leiste: alle LEDs zeigen immer dieselbe Farbe
    case singleColor
    /// Bei dieser Bauart nicht sicher bekannt
    case unknown

    var badge: String? {
        switch self {
        case .addressable: return "RGBIC"
        case .singleColor: return "RGB"
        case .unknown: return nil
        }
    }
}

/// Bauart eines Lichts: an welchem Namen man es erkennt und welche Bytes es versteht.
///
/// Die ELK-Leiste benutzt genau die Befehle aus index.html. Die MELK-Varianten (die Lichter,
/// die sonst nur Lotus Lamp X steuert) stammen aus den Tabellen des Open-Source-Projekts
/// „elkbledom“ (github.com/dave-code-ruiz/elkbledom, MIT-Lizenz): gleiche Schnittstelle FFF0/FFF3,
/// aber andere Bytes für An/Aus, Helligkeit und Effekte und eine Anmeldung nach dem Verbinden.
struct LightModel {
    /// Der Gerätename beginnt mit diesem Text (Großschreibung egal)
    let prefix: String
    /// Kurze Bezeichnung für die Geräteliste
    let label: String
    let family: EffectFamily
    let on: [UInt8]
    let off: [UInt8]
    /// Vorlagen: der Wert kommt an Stelle 3
    let brightTemplate: [UInt8]
    let effectTemplate: [UInt8]
    let speedTemplate: [UInt8]
    /// Wird nach dem Verbinden geschrieben, mit je 1 s Pause. Ohne das reagieren MELK-Lichter nicht.
    let login: [[UInt8]]
    /// Nur die eigene ELK-Leiste wird beim allerersten Start ohne Nachfrage übernommen
    let autoAdopt: Bool
    /// Schnittstelle und Byte-Format
    var wire: Wire = .elk

    /// false = Gerät mit unbekanntem Namen, die App versucht es mit den ELK-Befehlen
    var known: Bool { !prefix.isEmpty }

    /// Was die LEDs können: einzeln steuerbar (Lauflicht entlang der Leiste) oder alle in einer Farbe
    var pixels: PixelKind {
        switch family {
        case .stripX: return .addressable
        case .elk, .triones: return .singleColor
        case .melk, .melkOx, .sp, .govee: return .unknown
        }
    }

    /// Kann das Licht selbst dimmen? Sonst rechnet die App die Helligkeit in die Farbe ein.
    var nativeBrightness: Bool { wire != .triones }

    /// Erstes Farbpaket (Govee bekommt mehrere, siehe `colors`)
    func color(_ c: RGB) -> [UInt8] { colors(c)[0] }

    /// Alle Pakete für eine Farbe
    func colors(_ c: RGB) -> [[UInt8]] {
        switch wire {
        case .elk: return [Command.color(c)]
        case .triones: return [Triones.color(c)]
        case .sp110e: return [SP.frame(c.r, c.g, c.b, 0x1e)]
        case .sp107e: return [SP.frame(c.r, c.g, c.b, 0x0c)]
        case .govee: return Govee.colors(c)
        }
    }

    /// Leer = das Licht hat dafür keinen eigenen Befehl
    func bright(_ percent: Int) -> [UInt8] {
        switch wire {
        case .elk: return fill(brightTemplate, percent)
        case .triones: return []
        case .sp110e: return SP.frame(clamp(percent) * 255 / 100, 0, 0, 0x2a)
        case .sp107e: return SP.frame(clamp(percent) * 255 / 100, 0, 0, 0x0a)
        case .govee: return Govee.command([0x04, UInt8(max(clamp(percent), 1))])   // 1…100: 255 trennt manche Modelle
        }
    }

    func effect(_ code: UInt8, speed: Int = 50) -> [UInt8] {
        switch wire {
        case .elk: return fill(effectTemplate, Int(code))
        case .triones: return [0xbb, code, Triones.delay(speed), 0x44]
        case .sp110e: return SP.frame(Int(code), 0, 0, 0x2c)
        case .sp107e: return SP.frame(Int(code), 0, 0, 0x08)
        case .govee: return []
        }
    }

    /// Leer bei HappyLighting: dort steckt das Tempo im Effekt-Befehl
    func speed(_ percent: Int) -> [UInt8] {
        switch wire {
        case .elk: return fill(speedTemplate, percent)
        case .triones, .govee: return []
        case .sp110e: return SP.frame(max(1, clamp(percent) * 186 / 100), 0, 0, 0x03)
        case .sp107e: return SP.frame(max(1, clamp(percent) * 255 / 100), 0, 0, 0x09)
        }
    }

    private func clamp(_ percent: Int) -> Int { min(max(percent, 0), 100) }

    private func fill(_ template: [UInt8], _ value: Int) -> [UInt8] {
        var bytes = template
        bytes[3] = UInt8(clamping: value)
        return bytes
    }

    // MARK: Bekannte Bauarten

    static let elk = LightModel(
        prefix: "ELK-BLED", label: "ELK-Leiste", family: .elk,
        on: Command.on, off: Command.off,
        brightTemplate: Command.bright(0), effectTemplate: Command.effect(0), speedTemplate: Command.speed(0),
        login: [], autoAdopt: true)

    /// Andere ELK-Geräte (Birnen, Lampen): gleiche Befehle wie die Leiste, aber nie automatisch übernommen
    static let elkOther = LightModel(
        prefix: "ELK-", label: "ELK-Licht", family: .elk,
        on: Command.on, off: Command.off,
        brightTemplate: Command.bright(0), effectTemplate: Command.effect(0), speedTemplate: Command.speed(0),
        login: [], autoAdopt: false)

    /// Gerät mit unbekanntem Namen (nur unter „Alle Bluetooth-Geräte zeigen“): Versuch mit den ELK-Befehlen
    static let generic = LightModel(
        prefix: "", label: "Unbekanntes Gerät", family: .elk,
        on: Command.on, off: Command.off,
        brightTemplate: Command.bright(0), effectTemplate: Command.effect(0), speedTemplate: Command.speed(0),
        login: [], autoAdopt: false)

    private static let melkLogin: [[UInt8]] = [[0x7e, 0x07, 0x83], [0x7e, 0x04, 0x04]]
    private static let melkEffect: [UInt8] = [0x7e, 0x05, 0x03, 0x00, 0x06, 0xff, 0xff, 0x00, 0xef]
    private static let melkSpeed: [UInt8] = [0x7e, 0x04, 0x02, 0x00, 0xff, 0xff, 0xff, 0x00, 0xef]

    private static func melk(_ prefix: String, _ family: EffectFamily, on: [UInt8], off: [UInt8], bright: [UInt8]) -> LightModel {
        LightModel(prefix: prefix, label: "MELK-Licht", family: family, on: on, off: off,
                   brightTemplate: bright, effectTemplate: melkEffect, speedTemplate: melkSpeed,
                   login: melkLogin, autoAdopt: false)
    }

    // An/Aus und Helligkeit der MELK-Varianten
    private static let onA: [UInt8] = [0x7e, 0x04, 0x04, 0xf0, 0x00, 0x01, 0xff, 0x00, 0xef]
    private static let offA: [UInt8] = [0x7e, 0x04, 0x04, 0x00, 0x00, 0x00, 0xff, 0x00, 0xef]
    private static let brightA: [UInt8] = [0x7e, 0x04, 0x01, 0x00, 0x01, 0xff, 0xff, 0x00, 0xef]
    private static let brightB: [UInt8] = [0x7e, 0x04, 0x01, 0x00, 0xff, 0x00, 0xff, 0x00, 0xef]

    private static func elkLike(_ prefix: String) -> LightModel {
        LightModel(prefix: prefix, label: "LED-Leiste", family: .elk,
                   on: Command.on, off: Command.off,
                   brightTemplate: Command.bright(0), effectTemplate: Command.effect(0), speedTemplate: Command.speed(0),
                   login: [], autoAdopt: false)
    }

    private static func triones(_ prefix: String) -> LightModel {
        LightModel(prefix: prefix, label: "HappyLighting-Leiste", family: .triones,
                   on: Triones.on, off: Triones.off,
                   brightTemplate: [], effectTemplate: [], speedTemplate: [],
                   login: [], autoAdopt: false, wire: .triones)
    }

    private static func govee(_ prefix: String) -> LightModel {
        LightModel(prefix: prefix, label: "Govee-Licht", family: .govee,
                   on: Govee.command([0x01, 0x01]), off: Govee.command([0x01, 0x00]),
                   brightTemplate: [], effectTemplate: [], speedTemplate: [],
                   login: [], autoAdopt: false, wire: .govee)
    }

    /// „LEDBLE“ benutzen zwei Familien. Hat das Gerät kein FFD9, spricht es die ELK-Befehle.
    static let ledbleElk = elkLike("LEDBLE#ELK")
    /// Ohne bekannten Namen, aber an der Schnittstelle der Familie erkannt
    static let trionesByService = triones("#TRIONES")
    static let goveeByService = govee("#GOVEE")

    static let all: [LightModel] = [
        elk,
        elkOther,
        elkLike("XROCKER"),
        elkLike("JACKYLED"),
        elkLike("DMRRBA"),
        ledbleElk,
        triones("TRIONES"),
        triones("LEDBLUE"),
        triones("LEDBLE"),
        triones("QHM-"),
        triones("BLE-LED"),
        triones("DREAM~"),
        trionesByService,
        LightModel(prefix: "SP110E", label: "SP110E-Leiste", family: .sp,
                   on: SP.frame(0, 0, 0, 0xaa), off: SP.frame(0, 0, 0, 0xab),
                   brightTemplate: [], effectTemplate: [], speedTemplate: [],
                   login: [], autoAdopt: false, wire: .sp110e),
        LightModel(prefix: "SP107E", label: "SP107E-Leiste", family: .sp,
                   on: SP.frame(0, 0, 0, 0xaa), off: SP.frame(0, 0, 0, 0xbb),
                   brightTemplate: [], effectTemplate: [], speedTemplate: [],
                   login: [], autoAdopt: false, wire: .sp107e),
        govee("GOVEE_"),
        govee("IHOMENT_"),
        govee("GBK_"),
        govee("MINGER_"),
        goveeByService,
        melk("MELK-OG10", .melkOx,
             on: [0x7e, 0x07, 0x04, 0xff, 0x00, 0x01, 0x02, 0x01, 0xef],
             off: [0x7e, 0x07, 0x04, 0x00, 0x00, 0x00, 0x02, 0x00, 0xef],
             bright: brightB),
        melk("MELK-OF10", .melkOx, on: onA, off: offA, bright: brightA),
        melk("MELK-OC10", .melkOx, on: onA, off: offA, bright: brightA),
        melk("MELK-OA10", .melkOx, on: onA, off: offA, bright: brightA),
        melk("MELK-OA21", .stripX, on: onA, off: offA, bright: brightA),
        melk("MELK", .melk,
             on: [0x7e, 0x00, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0xef],
             off: [0x7e, 0x00, 0x04, 0x00, 0x00, 0x00, 0xff, 0x00, 0xef],
             bright: brightB),
    ]

    /// Bauart zu einer gespeicherten Kennung (dem Namensanfang)
    static func find(prefix: String) -> LightModel? {
        if prefix.isEmpty { return generic }
        return all.first { $0.prefix == prefix }
    }

    /// Bauart zum Gerätenamen. Passen mehrere, gewinnt der längste Anfang (MELK-OA10 vor MELK).
    /// Ohne passenden Namen zählt eine Schnittstelle, die nur LED-Controller haben (FFD5, Govee).
    /// Alles andere ist kein Licht und erscheint nirgends.
    static func detect(_ name: String?, services: [CBUUID] = []) -> LightModel? {
        let upper = (name ?? "").trimmingCharacters(in: .whitespaces).uppercased()
        var best: LightModel?
        for model in all where !upper.isEmpty && !model.prefix.contains("#") && upper.hasPrefix(model.prefix) {
            if best == nil || model.prefix.count > (best?.prefix.count ?? 0) { best = model }
        }
        if let best { return best }
        if services.contains(Triones.service) { return trionesByService }
        if services.contains(Govee.service) { return goveeByService }
        return nil
    }
}

/// Ein Steuerbefehl, den jedes Licht in seine eigenen Bytes übersetzt
enum Order {
    case power(Bool)
    case bright(Int)
    case effect(UInt8)
    case speed(Int)

    /// Je Art zählt in der Warteschlange nur der neueste
    var key: String {
        switch self {
        case .power: return "power"
        case .bright: return "bright"
        case .effect: return "effect"
        case .speed: return "speed"
        }
    }

    /// Leer = diese Bauart hat dafür keinen eigenen Befehl
    func bytes(for model: LightModel, speed: Int = 50) -> [UInt8] {
        switch self {
        case .power(let on): return on ? model.on : model.off
        case .bright(let percent): return model.bright(percent)
        case .effect(let code): return model.effect(code, speed: speed)
        case .speed(let percent): return model.speed(percent)
        }
    }
}
