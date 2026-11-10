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
                    NameStep(item: chosen, name: $name, back: { withAnimation { self.chosen = nil } }) {
                        light.add(chosen, name: name.isEmpty ? chosen.model.label : name)
                        dismiss()
                    }
                } else {
                    ListStep { item in
                        name = ""
                        withAnimation(.easeOut(duration: 0.25)) { chosen = item }
                    }
                }
            }
            .navigationTitle(chosen == nil ? "Licht hinzufügen" : "Name vergeben")
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
            HStack(spacing: 10) {
                if hub.bluetooth == .ready { SearchingMark() }
                Text(hub.bluetooth == .ready ? "Suche LED-Lichter in der Nähe …" : "Bluetooth ist nicht bereit")
                    .font(.geist(14, 500))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 4)
            .padding(.bottom, 14)

            if hub.bluetooth != .ready {
                BluetoothProblem(state: hub.bluetooth)
            }

            if found.isEmpty {
                VStack(spacing: 12) {
                    Clock { t in
                        let p = (t.truncatingRemainder(dividingBy: 2.4)) / 2.4
                        ZStack {
                            ForEach(0..<3, id: \.self) { i in
                                let k = (p + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                                Circle()
                                    .strokeBorder(Theme.accent.opacity(0.6 * (1 - k)), lineWidth: 1.5)
                                    .frame(width: 30 + 110 * k, height: 30 + 110 * k)
                            }
                            Icon(kind: .bluetooth, size: 22, color: Theme.accent)
                        }
                        .frame(height: 150)
                    }
                    Text("Noch nichts gefunden")
                        .font(.geist(16, 600))
                        .foregroundStyle(Theme.text)
                    Text("Licht einschalten und in die Nähe gehen. Andere Licht-Apps (z. B. die App des Herstellers) vorher ganz schließen – ein Licht nimmt immer nur eine Verbindung an.")
                        .font(.geist(13, 400))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .tile()
            } else {
                VStack(spacing: 10) {
                    ForEach(found) { item in
                        Button {
                            choose(item)
                        } label: {
                            HStack(spacing: 14) {
                                LampBadge(color: RGB(255, 210, 63), live: true, size: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.geist(16, 600))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                    Text(item.model.known ? item.model.label : "Unbekannt – Versuch mit ELK-Befehlen")
                                        .font(.geist(12, 400))
                                        .foregroundStyle(Theme.muted)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                PixelBadge(kind: item.model.pixels)
                                SignalBars(rssi: item.rssi)
                                Icon(kind: .plus, size: 18, color: Theme.accent)
                            }
                            .padding(14)
                            .background(Theme.tile, in: RoundedRectangle(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.soft, lineWidth: Theme.border)
                            }
                        }
                        .buttonStyle(PressStyle(scale: 0.98))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeOut(duration: 0.3), value: found.map { $0.id })
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
            VStack(spacing: 10) {
                LampBadge(color: RGB(255, 210, 63), live: true, size: 52)
                    .padding(.top, 18)
                Text("Wie soll das Licht heißen?")
                    .font(.geist(20, 600))
                    .foregroundStyle(Theme.text)
                Text("\(item.name) · \(item.model.label)")
                    .font(.geist(13, 400))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.bottom, 20)

            TextField("", text: $name, prompt: Text(item.model.label).foregroundStyle(Theme.muted))
                .font(.geist(18, 500))
                .foregroundStyle(Theme.text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(add)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(focused ? Theme.accent : Theme.line, lineWidth: Theme.border)
                }

            LazyVGrid(columns: Self.columns, spacing: 8) {
                ForEach(Self.ideas, id: \.self) { idea in
                    Button {
                        name = idea
                    } label: {
                        Text(idea)
                            .font(.geist(13, 500))
                            .foregroundStyle(name == idea ? Color(rgb: 0x14130E) : Theme.text)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(name == idea ? Theme.accent : Theme.fill, in: Capsule())
                            .overlay { Capsule().strokeBorder(name == idea ? Theme.accent : Theme.soft, lineWidth: 1) }
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
            .padding(.top, 24)

            Button("Anderes Licht wählen", action: back)
                .font(.geist(14, 500))
                .foregroundStyle(Theme.muted)
                .padding(.top, 14)
        }
        .onAppear { focused = true }
    }
}
