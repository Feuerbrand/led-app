import AppIntents

// Siri, Kurzbefehle-App und Aktionstaste. Die Befehle sind ohne Einrichtung sofort da:
// „Hey Siri, LED Controler an“ / „… aus“, „Schalte Wohnzimmer mit LED Controler an“, „Starte Kino mit LED Control“.
// Die App öffnet sich dafür kurz, verbindet sich und führt den Befehl aus.

// MARK: - Lichter und Szenen als Auswahl

/// Ein eigenes Licht (oder „Alle Lichter“) für Siri und die Kurzbefehle-App
struct LightEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Licht"
    static var defaultQuery = LightEntityQuery()

    /// Kennung des Lichts oder „all“
    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static func all() -> [LightEntity] {
        LightHub.storedLights().map { LightEntity(id: $0.id.uuidString, name: $0.title) }
            + [LightEntity(id: "all", name: "Alle Lichter")]
    }

    /// Werte für den Befehl: einzelnes Licht oder keins (= alle)
    var values: [String: String] {
        id == "all" ? [:] : ["light": id]
    }
}

struct LightEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LightEntity] {
        LightEntity.all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [LightEntity] {
        LightEntity.all()
    }
}

/// Eine gespeicherte Szene für Siri und die Kurzbefehle-App
struct SceneEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Szene"
    static var defaultQuery = SceneEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static func all() -> [SceneEntity] {
        let scenes = Store.load([LightScene].self, key: "led-app.scenes") ?? LightScene.starters
        return scenes.map { SceneEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

struct SceneEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SceneEntity] {
        SceneEntity.all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [SceneEntity] {
        SceneEntity.all()
    }
}

// MARK: - Befehle für alle Lichter

struct LightOnIntent: AppIntent {
    static let title: LocalizedStringResource = "Licht an"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        LightController.shared.run("on")
        return .result()
    }
}

struct LightOffIntent: AppIntent {
    static let title: LocalizedStringResource = "Licht aus"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        LightController.shared.run("off")
        return .result()
    }
}

struct LightToggleIntent: AppIntent {
    static let title: LocalizedStringResource = "Licht umschalten"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        LightController.shared.run("toggle")
        return .result()
    }
}

// MARK: - Befehle für ein bestimmtes Licht

struct LightEntityOnIntent: AppIntent {
    static let title: LocalizedStringResource = "Bestimmtes Licht einschalten"
    static let openAppWhenRun = true

    @Parameter(title: "Licht")
    var light: LightEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        LightController.shared.run("on", light.values)
        return .result()
    }
}

struct LightEntityOffIntent: AppIntent {
    static let title: LocalizedStringResource = "Bestimmtes Licht ausschalten"
    static let openAppWhenRun = true

    @Parameter(title: "Licht")
    var light: LightEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        LightController.shared.run("off", light.values)
        return .result()
    }
}

struct SceneIntent: AppIntent {
    static let title: LocalizedStringResource = "Szene starten"
    static let openAppWhenRun = true

    @Parameter(title: "Szene")
    var scene: SceneEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        LightController.shared.run("scene", ["name": scene.id])
        return .result()
    }
}

struct BrightnessIntent: AppIntent {
    static let title: LocalizedStringResource = "Helligkeit setzen"
    static let openAppWhenRun = true

    @Parameter(title: "Helligkeit in Prozent")
    var value: Int

    @Parameter(title: "Licht")
    var light: LightEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        var values = light?.values ?? [:]
        values["value"] = String(value)
        LightController.shared.run("brightness", values)
        return .result()
    }
}

// MARK: - Sätze für Siri

struct LEDShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LightOnIntent(),
            phrases: ["\(.applicationName) an", "Schalte \(.applicationName) ein", "Mach \(.applicationName) an"],
            shortTitle: "Alle an",
            systemImageName: "lightbulb.fill")
        AppShortcut(
            intent: LightOffIntent(),
            phrases: ["\(.applicationName) aus", "Schalte \(.applicationName) aus", "Mach \(.applicationName) aus"],
            shortTitle: "Alle aus",
            systemImageName: "lightbulb.slash")
        AppShortcut(
            intent: LightEntityOnIntent(),
            phrases: ["Schalte \(\.$light) mit \(.applicationName) an", "\(\.$light) an mit \(.applicationName)"],
            shortTitle: "Licht an",
            systemImageName: "lightbulb.max")
        AppShortcut(
            intent: LightEntityOffIntent(),
            phrases: ["Schalte \(\.$light) mit \(.applicationName) aus", "\(\.$light) aus mit \(.applicationName)"],
            shortTitle: "Licht aus",
            systemImageName: "lightbulb")
        AppShortcut(
            intent: SceneIntent(),
            phrases: ["Starte \(\.$scene) mit \(.applicationName)", "\(.applicationName) \(\.$scene)"],
            shortTitle: "Szene",
            systemImageName: "sparkles")
        AppShortcut(
            intent: LightToggleIntent(),
            phrases: ["\(.applicationName) umschalten"],
            shortTitle: "Umschalten",
            systemImageName: "power")
    }
}
