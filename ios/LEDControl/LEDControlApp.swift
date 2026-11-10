import SwiftUI

/// LED Control für iPhone: steuert eine ELK-BLEDOM-Leiste direkt über Bluetooth LE.
/// Die App ist die native Fassung von index.html (dieselben Befehle, Effekte und Texte).
@main
struct LEDControlApp: App {
    @State private var light = LightController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(light)
                .onAppear { light.start() }
        }
    }
}
