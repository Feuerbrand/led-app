import AppIntents

// Siri, Kurzbefehle-App und Aktionstaste: „LED Control an“, „LED Control aus“, Szenen und Helligkeit.
// Die App öffnet sich dafür kurz, verbindet sich und führt den Befehl aus.

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

struct SceneIntent: AppIntent {
    static let title: LocalizedStringResource = "Szene starten"
    static let openAppWhenRun = true

    @Parameter(title: "Name der Szene")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult {
        LightController.shared.run("scene", ["name": name])
        return .result()
    }
}

struct BrightnessIntent: AppIntent {
    static let title: LocalizedStringResource = "Helligkeit setzen"
    static let openAppWhenRun = true

    @Parameter(title: "Helligkeit in Prozent")
    var value: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        LightController.shared.run("brightness", ["value": String(value)])
        return .result()
    }
}

struct LEDShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LightOnIntent(),
            phrases: ["\(.applicationName) an", "Schalte \(.applicationName) ein", "Mach \(.applicationName) an"],
            shortTitle: "Licht an",
            systemImageName: "lightbulb.fill")
        AppShortcut(
            intent: LightOffIntent(),
            phrases: ["\(.applicationName) aus", "Schalte \(.applicationName) aus", "Mach \(.applicationName) aus"],
            shortTitle: "Licht aus",
            systemImageName: "lightbulb.slash")
        AppShortcut(
            intent: LightToggleIntent(),
            phrases: ["\(.applicationName) umschalten"],
            shortTitle: "Umschalten",
            systemImageName: "power")
    }
}
