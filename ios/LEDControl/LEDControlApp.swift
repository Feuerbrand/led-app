import SwiftUI

/// LED Control für iPhone: steuert ELK-BLEDOM-Leisten und MELK-Lichter direkt über Bluetooth LE.
/// Die App ist die native Fassung von index.html (dieselben Befehle, Effekte und Texte) mit
/// mehreren Lichtern, Szenen, Musik-Modus, Siri-Kurzbefehlen und Update-Prüfung.
@main
struct LEDControlApp: App {
    @State private var light = LightController.shared
    @State private var updater = Updater()

    init() {
        _ = Intro.start
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(light)
                .environment(updater)
                .onAppear {
                    light.start()
                    updater.check()
                }
                .onOpenURL { url in
                    light.handle(url: url)
                }
        }
    }
}
