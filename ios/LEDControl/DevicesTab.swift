import SwiftUI
import UIKit

/// Reiter „Geräte“: eigene Lichter (verbinden, umbenennen, finden, entfernen) und Lichter in der Nähe
struct DevicesTab: View {
    @Environment(LightController.self) private var light

    var body: some View {
        let hub = light.hub
        TabPage {
            PageTitle(title: "Geräte", subtitle: "Alle eingeschalteten Lichter werden gemeinsam gesteuert")

            if hub.bluetooth != .ready {
                BluetoothProblem(state: hub.bluetooth).rise(1)
            }

            SectionTitle("Meine Lichter").rise(2)
            if hub.mine.isEmpty {
                Hint(text: hub.setupDone
                     ? "Noch kein Licht. Tippe unten bei „In der Nähe“ auf ein Licht, um es hinzuzufügen."
                     : "Die App sucht deine ELK-Leiste und übernimmt sie beim ersten Fund automatisch.")
                    .rise(3)
            } else {
                VStack(spacing: 10) {
                    ForEach(hub.mine) { item in
                        MyLightRow(item: item)
                    }
                }
                .rise(3)
            }

            HStack(alignment: .lastTextBaseline) {
                SectionTitle("In der Nähe")
                if hub.bluetooth == .ready {
                    SearchingMark()
                        .padding(.bottom, 10)
                }
            }
            .rise(4)
            NearbyList().rise(5)

            ShowAllTile().rise(6)

            Hint(text: "Lotus Lamp X und andere Licht-Apps vorher ganz schließen – ein Licht nimmt immer nur eine Verbindung an.")
                .padding(.top, 12)
                .rise(7)
        }
        .onAppear { hub.setBrowsing(true) }
        .onDisappear { hub.setBrowsing(false) }
    }
}

// MARK: - Eigene Lichter

private struct MyLightRow: View {
    let item: Light

    @Environment(LightController.self) private var light
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmRemove = false

    private var stateText: String {
        if !item.enabled { return "Getrennt" }
        switch item.state {
        case .on: return "Verbunden"
        case .busy: return item.rssi == nil ? "Nicht in Reichweite – wartet" : "Verbindet …"
        case .off: return "Getrennt"
        }
    }

    var body: some View {
        let hub = light.hub
        let on = item.state == .on
        HStack(spacing: 12) {
            StatusDot(state: item.enabled ? item.state : .off)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.geist(16, 600))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(item.model.label) · \(stateText)")
                    .font(.geist(12, 400))
                    .foregroundStyle(on ? Theme.text.opacity(0.75) : Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            SignalBars(rssi: item.rssi)
            Menu {
                Button {
                    light.identify(item)
                } label: {
                    Label("Blinken lassen", systemImage: "light.max")
                }
                .disabled(!on)
                Button {
                    newName = item.title
                    renaming = true
                } label: {
                    Label("Umbenennen", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    confirmRemove = true
                } label: {
                    Label("Entfernen", systemImage: "trash")
                }
            } label: {
                Icon(kind: .dots, size: 20, color: Theme.text)
                    .frame(width: 34, height: 40)
                    .contentShape(Rectangle())
            }
            Toggle("", isOn: Binding(get: { item.enabled }, set: { hub.setEnabled(item, $0) }))
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .background(Theme.tile, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(on ? Theme.accent.opacity(0.7) : Theme.soft, lineWidth: Theme.border)
        }
        .overlay {
            if item.enabled && item.state == .busy && item.rssi != nil { ScanBorder() }
        }
        .alert("Licht umbenennen", isPresented: $renaming) {
            TextField(item.name, text: $newName)
            Button("Sichern") { hub.rename(item, to: newName == item.name ? "" : newName) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Gerätename: \(item.name)")
        }
        .confirmationDialog("\(item.title) entfernen?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Entfernen", role: .destructive) { hub.remove(item) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Verbindung wird getrennt. Du kannst das Licht jederzeit wieder hinzufügen.")
        }
    }
}

/// Empfangsstärke als drei Balken; ohne Wert gedimmt
private struct SignalBars: View {
    let rssi: Int?

    private var level: Int {
        guard let rssi else { return 0 }
        if rssi > -62 { return 3 }
        if rssi > -78 { return 2 }
        return 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i <= level ? Theme.text : Color.white.opacity(0.18))
                    .frame(width: 3, height: CGFloat(4 + i * 3))
            }
        }
        .frame(height: 14, alignment: .bottom)
        .accessibilityLabel(level == 0 ? "Kein Empfang" : "Empfang \(level) von 3")
    }
}

// MARK: - In der Nähe

private struct NearbyList: View {
    @Environment(LightController.self) private var light

    var body: some View {
        let hub = light.hub
        let list = hub.nearby.sorted { ($0.rssi ?? -200) > ($1.rssi ?? -200) }
        if list.isEmpty {
            Hint(text: hub.bluetooth == .ready
                 ? "Suche … Lichter einschalten und in die Nähe gehen."
                 : "Ohne Bluetooth kann die App keine Lichter finden.")
        } else {
            VStack(spacing: 10) {
                ForEach(list) { item in
                    NearbyRow(item: item)
                }
            }
        }
    }
}

private struct NearbyRow: View {
    let item: Light

    @Environment(LightController.self) private var light

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.geist(15, 600))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(item.model.known ? item.model.label : "Unbekannt – Versuch mit ELK-Befehlen")
                    .font(.geist(12, 400))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            SignalBars(rssi: item.rssi)
            Button {
                light.hub.add(item)
            } label: {
                HStack(spacing: 6) {
                    Icon(kind: .plus, size: 13)
                    Text("Hinzufügen")
                }
                .font(.geist(13, 500))
            }
            .buttonStyle(CompactButtonStyle())
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.soft, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
    }
}

private struct ShowAllTile: View {
    @Environment(LightController.self) private var light

    var body: some View {
        let hub = light.hub
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { hub.showAll }, set: { hub.setShowAll($0) })) {
                Text("Alle Bluetooth-Geräte zeigen")
                    .font(.geist(15, 500))
                    .foregroundStyle(Theme.text)
            }
            .tint(Theme.accent)
            Text("Für Lichter mit anderem Namen. Die App versucht es dann mit den Befehlen der ELK-Leiste – das klappt nicht bei jedem Gerät.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
        }
        .tile()
        .padding(.top, 12)
    }
}

/// Kleiner, sich drehender Bogen neben „In der Nähe“
private struct SearchingMark: View {
    var body: some View {
        Clock { t in
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 11, height: 11)
                .rotationEffect(.degrees((t * 300).truncatingRemainder(dividingBy: 360)))
        }
        .accessibilityLabel("Sucht")
    }
}

private struct BluetoothProblem: View {
    let state: BluetoothState

    @Environment(\.openURL) private var openURL

    private var text: String {
        switch state {
        case .off: return "Bluetooth ist ausgeschaltet. Bitte im Kontrollzentrum einschalten."
        case .denied: return "Die App darf Bluetooth nicht benutzen. Bitte in den Einstellungen erlauben."
        case .unsupported: return "Dieses Gerät kann kein Bluetooth LE."
        default: return "Bluetooth startet …"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Icon(kind: .bluetooth, size: 17, color: Theme.accent)
                Text(text)
                    .font(.geist(14, 500))
                    .foregroundStyle(Theme.text)
            }
            if state == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Einstellungen öffnen") { openURL(url) }
                    .buttonStyle(OutlineButtonStyle(on: true))
            }
        }
        .tile()
        .padding(.top, 12)
    }
}

/// Grauer Hinweistext unter oder zwischen Kacheln
struct Hint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.geist(12, 400))
            .foregroundStyle(Theme.muted)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

/// Kleiner Knopf mit gelbem Rahmen (Hinzufügen, Kopieren …)
struct CompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.text)
            .environment(\.iconTint, Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Theme.hot : Theme.fill, in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.accent, lineWidth: Theme.border)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
