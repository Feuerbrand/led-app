import SwiftUI

/// Licht hinzufügen: zeigt nur passende LED-Lichter in der Nähe, danach bekommt das Licht einen eigenen Namen
struct AddLightSheet: View {
    @Environment(LightController.self) private var light
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Light? = nil
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Group {
                if let chosen {
                    NameStep(item: chosen, name: $name, back: { withAnimation(.snappy) { self.chosen = nil } }) {
                        light.add(chosen, name: name.isEmpty ? chosen.model.label : name)
                        dismiss()
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    ListStep { item in
                        name = ""
                        withAnimation(.snappy) { chosen = item }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .pageBackground()
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
        .onAppear { light.hub.setBrowsing(true) }
        .onDisappear { light.hub.setBrowsing(false) }
    }
}

// MARK: - Schritt 1: Licht auswählen

private struct ListStep: View {
    let choose: (Light) -> Void

    @Environment(LightController.self) private var light

    var body: some View {
        let hub = light.hub
        let found = hub.nearby.sorted { ($0.rssi ?? -200) > ($1.rssi ?? -200) }
        Page {
            PageTitle(title: "Licht hinzufügen", subtitle: "Nur passende LED-Lichter in der Nähe")

            VStack(alignment: .leading, spacing: 12) {
                if hub.bluetooth == .ready {
                    ScannerLEDs()
                } else {
                    LEDPanel(colors: [RGB(255, 210, 63)], live: false)
                }
                HStack(spacing: 8) {
                    StatusLED(state: hub.bluetooth == .ready ? .busy : .off)
                    Text((hub.bluetooth == .ready ? "Suche · \(found.count) gefunden" : "Bluetooth nicht bereit").uppercased())
                        .font(.geistMono(11, 600))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                }
            }
            .tile()
            .padding(.top, 18)

            if hub.bluetooth != .ready {
                BluetoothProblem(state: hub.bluetooth)
            }

            if found.isEmpty {
                Hint(text: "Licht einschalten und in die Nähe gehen. Andere Licht-Apps (z. B. die App des Herstellers) vorher ganz schließen – ein Licht nimmt immer nur eine Verbindung an.")
                    .padding(.top, 14)
            } else {
                SectionTitle("Gefunden")
                VStack(spacing: 8) {
                    ForEach(found) { item in
                        Button {
                            choose(item)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.name)
                                        .font(.geist(17, 600))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                    HStack(spacing: 8) {
                                        PixelBadge(kind: item.model.pixels)
                                        Text((item.model.known ? item.model.label : "Unbekannt – Versuch mit ELK-Befehlen").uppercased())
                                            .font(.geistMono(10, 500))
                                            .tracking(0.8)
                                            .foregroundStyle(Theme.muted)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 8)
                                SignalBars(rssi: item.rssi)
                                Icon(kind: .plus, size: 18, color: Theme.accent)
                            }
                            .padding(14)
                            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 4))
                            .overlay {
                                RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.hair, lineWidth: 1)
                            }
                        }
                        .buttonStyle(PressStyle(scale: 0.98))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.snappy, value: found.map { $0.id })
            }

            Toggle(isOn: Binding(get: { hub.showAll }, set: { hub.setShowAll($0) })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Auch andere Bluetooth-Geräte zeigen")
                        .font(.geist(14, 500))
                        .foregroundStyle(Theme.text)
                    Text("Nur für Lichter mit anderem Namen. Die App versucht es dann mit den Befehlen der ELK-Leiste.")
                        .font(.geist(12, 400))
                        .foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.accent)
            .tile()
            .padding(.top, 18)
        }
    }
}

// MARK: - Schritt 2: Namen vergeben

private struct NameStep: View {
    let item: Light
    @Binding var name: String
    let back: () -> Void
    let add: () -> Void

    @FocusState private var focused: Bool

    private static let ideas = ["Wohnzimmer", "Schlafzimmer", "Bett", "Schreibtisch", "Fernseher", "Küche", "Flur", "Gaming"]
    private static let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        Page {
            PageTitle(title: "Wie soll es heißen?", subtitle: "\(item.name) · \(item.model.label)")

            TextField("", text: $name, prompt: Text(item.model.label).foregroundStyle(Theme.muted))
                .font(.geist(22, 600))
                .foregroundStyle(Theme.text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(add)
                .padding(.horizontal, 14)
                .frame(height: 58)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4).strokeBorder(focused ? Theme.accent : Theme.hair, lineWidth: 1)
                }
                .padding(.top, 22)

            LazyVGrid(columns: Self.columns, spacing: 8) {
                ForEach(Self.ideas, id: \.self) { idea in
                    let on = name == idea
                    Button {
                        name = idea
                    } label: {
                        Text(idea)
                            .font(.geist(13, 500))
                            .foregroundStyle(on ? Theme.ink : Theme.text)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(on ? Theme.accent : Theme.panel, in: RoundedRectangle(cornerRadius: 4))
                            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(on ? Theme.accent : Theme.hair, lineWidth: 1) }
                    }
                    .buttonStyle(PressStyle(scale: 0.94))
                }
            }
            .padding(.top, 14)

            Button(action: add) {
                HStack(spacing: 8) {
                    Icon(kind: .plus, size: 15)
                    Text("Hinzufügen")
                }
            }
            .buttonStyle(AccentButtonStyle())
            .padding(.top, 26)

            Button(action: back) {
                Text("ANDERES LICHT WÄHLEN")
                    .font(.geistMono(11, 600))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 16)
        }
        .onAppear { focused = true }
    }
}
