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
    case elk, melk, melkOx, stripX

    var title: String {
        switch self {
        case .elk: return "Standard-Effekte der Leiste"
        case .melk: return "Effekte des MELK-Lichts"
        case .melkOx: return "Effekte des MELK-Lichts"
        case .stripX: return "Effekte des MELK-Lichts"
        }
    }

    var effects: [BuiltinEffect] {
        switch self {
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

    /// false = Gerät mit unbekanntem Namen, die App versucht es mit den ELK-Befehlen
    var known: Bool { !prefix.isEmpty }

    func color(_ c: RGB) -> [UInt8] {
        Command.color(c)                    // bei allen unterstützten Bauarten gleich
    }

    func bright(_ percent: Int) -> [UInt8] { fill(brightTemplate, percent) }
    func effect(_ code: UInt8) -> [UInt8] { fill(effectTemplate, Int(code)) }
    func speed(_ percent: Int) -> [UInt8] { fill(speedTemplate, percent) }

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

    static let all: [LightModel] = [
        elk,
        elkOther,
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
    static func detect(_ name: String?) -> LightModel? {
        let upper = (name ?? "").uppercased()
        var best: LightModel?
        for model in all where upper.hasPrefix(model.prefix) {
            if best == nil || model.prefix.count > (best?.prefix.count ?? 0) { best = model }
        }
        return best
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

    func bytes(for model: LightModel) -> [UInt8] {
        switch self {
        case .power(let on): return on ? model.on : model.off
        case .bright(let percent): return model.bright(percent)
        case .effect(let code): return model.effect(code)
        case .speed(let percent): return model.speed(percent)
        }
    }
}
