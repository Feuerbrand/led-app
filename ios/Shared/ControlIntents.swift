import AppIntents

// Gehört zur App und zur Widget-Erweiterung. Die Erweiterung zeigt nur die Knöpfe;
// ausgeführt wird der Befehl in der App, die sich dafür kurz öffnet (wie bei Siri).

/// Knopf im Kontrollzentrum und auf dem Sperrbildschirm: alle Lichter an oder aus
struct ControlToggleIntent: AppIntent {
    static let title: LocalizedStringResource = "LED-Lichter an/aus"
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        LightController.shared.run("toggle")
        #endif
        return .result()
    }
}

/// Knopf im Kontrollzentrum: Gute Nacht auf allen Lichtern
struct ControlGoodnightIntent: AppIntent {
    static let title: LocalizedStringResource = "Gute Nacht"
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        LightController.shared.run("goodnight")
        #endif
        return .result()
    }
}
