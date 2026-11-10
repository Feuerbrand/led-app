import Foundation

/// Eine gespeicherte Szene: Farbe oder Flow-Effekt samt Helligkeit und Tempo.
struct LightScene: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var red: Int
    var green: Int
    var blue: Int
    /// nil = feste Farbe, sonst die Kennung des Flow-Effekts
    var flowID: String?
    var brightness: Int
    var speed: Int

    var color: RGB { RGB(red, green, blue) }

    init(name: String, color: RGB, flowID: String? = nil, brightness: Int, speed: Int = 50) {
        self.name = name
        self.red = color.r
        self.green = color.g
        self.blue = color.b
        self.flowID = flowID
        self.brightness = brightness
        self.speed = speed
    }

    /// Vorschläge für den ersten Start; lassen sich löschen und durch eigene ersetzen
    static let starters: [LightScene] = [
        LightScene(name: "Warmweiß", color: RGB(255, 180, 107), brightness: 80),
        LightScene(name: "Kino", color: RGB(255, 96, 20), brightness: 20),
        LightScene(name: "Entspannen", color: RGB(0, 215, 255), flowID: "aurora", brightness: 60, speed: 25),
        LightScene(name: "Party", color: RGB(255, 0, 200), flowID: "rainbow", brightness: 100, speed: 90),
    ]
}

/// Was die App zwischen zwei Starts behält
struct SavedState: Codable {
    var brightness = 100
    var speed = 50
    var red = 255
    var green = 0
    var blue = 0
}

enum Store {
    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
