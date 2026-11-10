import SwiftUI

/// Hauptmenü: Zähler, „Alle Lichter“ und jedes Licht als Zeile mit LED-Reihe und Schalter
struct HomeView: View {
    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav
    @State private var adding = false

    private var statusLine: String {
        let hub = light.hub
        if light.demo && hub.mine.isEmpty { return "Vorführmodus" }
        switch hub.bluetooth {
        case .off: return "Bluetooth aus"
        case .denied: return "Bluetooth nicht erlaubt"
        case .unsupported: return "Kein Bluetooth"
        case .starting: return "Startet"
        case .ready: break
        }
        let on = hub.targets.count
        if on > 0 { return "\(on) verbunden" }
        if hub.mine.contains(where: { $0.state == .busy }) || !hub.setupDone { return "Sucht" }
        return "Nicht verbunden"
    }

    var body: some View {
        let hub = light.hub
        let mine = hub.mine
        Page {
            // Kopfzeile
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 10, height: 10)
                HStack(spacing: 0) {
                    Text("LED").foregroundStyle(Theme.text)
                    Text("CONTROL").foregroundStyle(Theme.accent)
                }
                .font(.geistMono(14, 700))
                .tracking(2.2)
                Spacer()
                SquareIconButton(icon: .plus, label: "Licht hinzufügen") { adding = true }
                SquareIconButton(icon: .sliders, label: "Einstellungen") { nav.path.append(.settings) }
            }
            .padding(.top, 4)

            // Großanzeige
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(String(format: "%02d", mine.count))
                    .font(.geistMono(72, 600))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText(value: Double(mine.count)))
                    .animation(.snappy, value: mine.count)
                VStack(alignment: .leading, spacing: 6) {
                    Text(mine.count == 1 ? "LICHT" : "LICHTER")
                        .font(.geistMono(14, 700))
                        .tracking(2)
                        .foregroundStyle(Theme.text)
                    HStack(spacing: 7) {
                        StatusLED(state: light.link)
                        Text(statusLine.uppercased())
                            .font(.geistMono(11, 500))
                            .tracking(1.2)
                            .foregroundStyle(Theme.muted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 22)
            .padding(.bottom, 6)
            .rise(0)

            UpdateBanner().rise(1)

            if hub.bluetooth != .ready && hub.bluetooth != .starting && !light.demo {
                BluetoothProblem(state: hub.bluetooth).rise(1)
            }

            if mine.isEmpty && !light.demo {
                EmptyHome(adding: $adding).rise(2)
            } else {
                if mine.count > 1 || light.demo {
                    AllLightsPanel()
                        .padding(.top, 14)
                        .rise(2)
                }
                SectionTitle("Meine Lichter").rise(3)
                VStack(spacing: 10) {
                    ForEach(mine) { item in
                        LightRow(item: item)
                    }
                    AddRow { adding = true }
                }
                .rise(4)
                Hint(text: "Antippen zum Steuern. Gedrückt halten: blinken lassen, umbenennen, entfernen.")
                    .padding(.top, 12)
                    .rise(5)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .pageBackground()
        .sheet(isPresented: $adding) {
            AddLightSheet()
        }
        .onAppear { light.select(.all) }
    }
}

// MARK: - Alle Lichter

/// Paneel für alle Lichter: jedes Licht als eigener Abschnitt in der LED-Reihe
private struct AllLightsPanel: View {
    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav

    /// Zeile unter dem Titel, z. B. „2/2 VERBUNDEN · POLARLICHT · WELLE“
    private static func info(lights: Int, connected: Int, effect: String?, wave: Bool) -> String {
        var parts = [lights == 0 ? "Vorführmodus" : "\(connected)/\(lights) verbunden"]
        if let effect {
            parts.append(effect)
            if wave && lights > 1 { parts.append("Welle") }
        }
        return parts.joined(separator: " · ").uppercased()
    }

    var body: some View {
        let lights = light.lightsOf(.all)
        let live = light.isLive(.all)
        let colors = lights.isEmpty ? [light.glow(.all)] : lights.map { light.glow(.light($0.id)) }
        let connected = lights.filter { $0.state == .on }.count
        let look = light.lookOf(.all)
        let effect = look.flowID.flatMap { id in Flow.everything.first { $0.id == id }?.name }
        let info = Self.info(lights: lights.count, connected: connected, effect: effect, wave: light.wave)
        Button {
            nav.path.append(.control(.all))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Alle Lichter")
                        .font(.geist(20, 600))
                        .foregroundStyle(Theme.text)
                    Text(info)
                        .font(.geistMono(11, 500))
                        .tracking(1)
                        .foregroundStyle(effect != nil ? Theme.accent : Theme.muted)
                        .lineLimit(1)
                }
                .padding(.trailing, 70)
                LEDPanel(colors: colors, live: live, brightness: look.brightness, rows: 2, dot: 7, gap: 5)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4).strokeBorder(live ? Theme.accent.opacity(0.6) : Theme.hair, lineWidth: 1)
            }
        }
        .buttonStyle(PressStyle(scale: 0.985))
        .overlay(alignment: .topTrailing) {
            PowerSwitch(target: .all)
                .padding(14)
        }
    }
}

// MARK: - Ein Licht

/// Zeile für ein Licht: Status-LED, Name, Typ und Empfang, LED-Reihe in der echten Farbe, Schalter
private struct LightRow: View {
    let item: Light

    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmRemove = false

    private var stateText: String {
        let t = Target.light(item.id)
        if !item.enabled { return "Getrennt" }
        switch item.state {
        case .busy:
            return item.rssi == nil ? "Nicht in Reichweite" : "Verbindet"
        case .off:
            return "Getrennt"
        case .on:
            let look = light.lookOf(t)
            if look.power == false { return "Aus" }
            if let id = look.flowID, let flow = Flow.everything.first(where: { $0.id == id }) { return flow.name }
            if look.builtin != nil { return "Eingebauter Effekt" }
            return "\(look.brightness) %"
        }
    }

    var body: some View {
        let t = Target.light(item.id)
        let live = light.isLive(t)
        let look = light.lookOf(t)
        let running = live && (look.flowID != nil || look.builtin != nil)
        Button {
            nav.path.append(.control(t))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        StatusLED(state: item.enabled ? item.state : .off)
                        Text(item.title)
                            .font(.geist(20, 600))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    HStack(spacing: 8) {
                        PixelBadge(kind: item.model.pixels)
                        Text("\(item.name) · \(stateText)".uppercased())
                            .font(.geistMono(11, 500))
                            .tracking(0.8)
                            .foregroundStyle(running ? Theme.accent : Theme.muted)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if item.state == .on || item.rssi != nil {
                            SignalBars(rssi: item.rssi)
                        }
                    }
                }
                .padding(.trailing, 70)
                LEDPanel(colors: [light.glow(t)], live: live, brightness: look.brightness, dot: 7, gap: 5)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4).strokeBorder(live ? Theme.accent.opacity(0.6) : Theme.hair, lineWidth: 1)
            }
        }
        .buttonStyle(PressStyle(scale: 0.985))
        .overlay(alignment: .topTrailing) {
            PowerSwitch(target: t)
                .padding(14)
        }
        .contextMenu {
            Button {
                light.identify(item)
            } label: {
                Label("Blinken lassen", systemImage: "light.max")
            }
            .disabled(item.state != .on)
            Button {
                newName = item.title
                renaming = true
            } label: {
                Label("Umbenennen", systemImage: "pencil")
            }
            Button {
                light.hub.setEnabled(item, !item.enabled)
            } label: {
                Label(item.enabled ? "Trennen" : "Verbinden", systemImage: item.enabled ? "bolt.slash" : "bolt")
            }
            Button(role: .destructive) {
                confirmRemove = true
            } label: {
                Label("Entfernen", systemImage: "trash")
            }
        }
        .alert("Licht umbenennen", isPresented: $renaming) {
            TextField(item.name, text: $newName)
            Button("Sichern") { light.hub.rename(item, to: newName == item.name ? "" : newName) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Gerätename: \(item.name)")
        }
        .confirmationDialog("\(item.title) entfernen?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Entfernen", role: .destructive) { light.hub.remove(item) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Verbindung wird getrennt. Du kannst das Licht jederzeit wieder hinzufügen.")
        }
    }
}

private struct AddRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Icon(kind: .plus, size: 16, color: Theme.accent)
                Text("LICHT HINZUFÜGEN")
                    .font(.geistMono(12, 600))
                    .tracking(1.6)
                    .foregroundStyle(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.bg.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.hair, lineWidth: 1)
            }
        }
        .buttonStyle(PressStyle(scale: 0.985))
    }
}

/// Noch kein Licht: Suche, Hinzufügen und Vorführmodus
private struct EmptyHome: View {
    @Binding var adding: Bool

    @Environment(LightController.self) private var light

    var body: some View {
        let searching = !light.hub.setupDone && light.hub.bluetooth == .ready
        VStack(alignment: .leading, spacing: 14) {
            if searching {
                ScannerLEDs()
            } else {
                LEDPanel(colors: [RGB(255, 210, 63)], live: false, rows: 1)
            }
            Text(searching ? "Suche deine LED-Leiste" : "Noch kein Licht")
                .font(.geist(20, 600))
                .foregroundStyle(Theme.text)
            Text(searching
                 ? "Die erste ELK-Leiste in der Nähe übernimmt die App automatisch. Andere Licht-Apps vorher ganz schließen."
                 : "Licht einschalten, in die Nähe gehen und andere Licht-Apps ganz schließen. Dann hier hinzufügen.")
                .font(.geist(13, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
            Button {
                adding = true
            } label: {
                HStack(spacing: 8) {
                    Icon(kind: .plus, size: 15)
                    Text("Licht hinzufügen")
                }
            }
            .buttonStyle(AccentButtonStyle())
            .padding(.top, 4)
            Button {
                withAnimation(.easeOut(duration: 0.3)) { light.setDemo(true) }
            } label: {
                Text("Ohne Licht ausprobieren")
            }
            .buttonStyle(OutlineButtonStyle())
        }
        .tile()
        .padding(.top, 14)
    }
}

// MARK: - Update-Hinweis

struct UpdateBanner: View {
    @Environment(Updater.self) private var updater
    @Environment(Navigator.self) private var nav

    var body: some View {
        if let release = updater.available {
            Button {
                nav.path.append(.settings)
            } label: {
                HStack(spacing: 12) {
                    Icon(kind: .download, size: 18, color: Theme.ink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update \(release.version)")
                            .font(.geist(15, 600))
                        Text("ANTIPPEN FÜR DIE ANLEITUNG")
                            .font(.geistMono(10, 600))
                            .tracking(1)
                    }
                    .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(PressStyle(scale: 0.98))
            .padding(.top, 14)
        }
    }
}
