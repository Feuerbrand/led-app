import CoreBluetooth

/// ELK-BLEDOM-Protokoll. Jeder Befehl sind 9 Bytes: 7E … EF.
/// Gleiche Werte wie das Objekt `cmd` in index.html.
enum Command {
    static let service = CBUUID(string: "FFF0")          // 0000fff0-0000-1000-8000-00805f9b34fb
    static let characteristic = CBUUID(string: "FFF3")   // 0000fff3-0000-1000-8000-00805f9b34fb

    /// Nur die eigene Leiste (ELK-BLEDOM / ELK-BLEDDM). Andere Controller in Reichweite,
    /// z. B. MELK-…, fangen nicht mit diesem Text an und werden nie verbunden.
    static let namePrefix = "ELK-BLED"

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

/// Fest eingebaute Effekte der Leiste (laufen in der Leiste selbst, auch ohne App).
struct BuiltinEffect: Identifiable {
    let name: String
    let code: UInt8
    var id: UInt8 { code }

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
