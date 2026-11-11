import Observation
import SwiftUI
import UIKit

/// Seiten, die vom Hauptmenü aus geöffnet werden
enum Route: Hashable {
    case control(Target)
    case settings
}

/// Welche Seiten gerade offen sind (damit Karten und Hinweise dorthin springen können)
@Observable
final class Navigator {
    var path: [Route] = []
    /// Bereich, mit dem die nächste Steuerseite öffnet (z. B. „Szenen“ aus dem Hauptmenü)
    var section: ControlSection? = nil
}

/// Grundgerüst: Hauptmenü mit den Lichtern, von dort Steuerung und Einstellungen
struct ContentView: View {
    @Environment(LightController.self) private var light
    @Environment(Updater.self) private var updater
    @Environment(\.scenePhase) private var scenePhase
    @State private var nav = Navigator()

    /// Namen aller Lichter und Szenen (ändert sich einer, bekommt Siri die neue Liste)
    private var shortcutNames: [String] {
        light.hub.mine.map { $0.title } + light.scenes.map { $0.name }
    }

    var body: some View {
        NavigationStack(path: $nav.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .control(let target): ControlView(target: target)
                    case .settings: SettingsView()
                    }
                }
        }
        .tint(Theme.accent)
        .environment(nav)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: light.connectedCount)
        .onChange(of: scenePhase) { _, phase in
            // Zurück in der App: Verbindungen prüfen und nach Updates sehen
            if phase == .active {
                light.resume()
                updater.check()
            }
        }
        .onChange(of: light.keepAwake, initial: true) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        .onChange(of: shortcutNames, initial: true) { _, _ in
            // Siri kennt dann die aktuellen Namen der Lichter und Szenen
            LEDShortcuts.updateAppShortcutParameters()
        }
        .onAppear {
            light.start()
            // Für die automatischen App-Store-Bilder: Startseite per Startargument wählen
            switch UserDefaults.standard.string(forKey: "screenshotPage") {
            case "color", "effects", "scenes": nav.path = [.control(.all)]
            case "light": nav.path = [.control(light.hub.mine.first.map { Target.light($0.id) } ?? .all)]
            case "settings": nav.path = [.settings]
            default: break
            }
        }
    }
}
