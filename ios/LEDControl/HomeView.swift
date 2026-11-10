import SwiftUI

/// Hauptmenü: alle eigenen Lichter als leuchtende Karten, „Alle Lichter“ und Hinzufügen
struct HomeView: View {
    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav
    @State private var adding = false

    private static let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    /// Begrüßung je nach Tageszeit
    private static var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: return "Guten Morgen"
        case 11..<17: return "Hallo"
        case 17..<23: return "Guten Abend"
        default: return "Gute Nacht"
        }
    }

    /// Farben aller eingeschalteten Lichter für das Farblicht im Hintergrund
    private var auroraColors: [Color] {
        let lit = light.hub.mine.filter { $0.state == .on && light.lookOf(.light($0.id)).power != false }
        if lit.isEmpty { return [light.glow(.all).color] }
        return lit.map { light.glow(.light($0.id)).color }
    }

    var body: some View {
        let hub = light.hub
        let mine = hub.mine
        Page {
            HStack(spacing: 10) {
                Spacer()
                CircleIconButton(icon: .plus, label: "Licht hinzufügen") { adding = true }
                CircleIconButton(icon: .sliders, label: "Einstellungen") { nav.path.append(.settings) }
            }
            .padding(.top, 4)

            HeroView(target: .all)
                .padding(.top, -26)

            Text(Self.greeting)
                .font(.geist(15, 500))
                .foregroundStyle(Theme.text.opacity(0.85))
                .padding(.bottom, 6)

            HStack(spacing: 10) {
                StatusDot(state: light.link)
                Text(light.status)
                    .font(.geist(13, 400))
                    .foregroundStyle(light.link == .on ? Theme.text : Theme.muted)
            }
            .padding(.bottom, 20)

            UpdateBanner().rise(0)

            if hub.bluetooth != .ready && !light.demo {
                BluetoothProblem(state: hub.bluetooth).rise(1)
            }

            if mine.isEmpty && !light.demo {
                EmptyHome(adding: $adding).rise(2)
            } else {
                if mine.count > 1 || light.demo {
                    AllLightsCard()
                        .padding(.top, 4)
                        .rise(2)
                }
                SectionTitle("Meine Lichter").rise(3)
                LazyVGrid(columns: Self.columns, spacing: 12) {
                    ForEach(mine) { item in
                        LightCard(item: item)
                    }
                    AddCard { adding = true }
                }
                .rise(4)
                Hint(text: "Antippen zum Steuern, gedrückt halten für Umbenennen, Blinken und Entfernen.")
                    .padding(.top, 12)
                    .rise(5)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(alignment: .top) {
            AuroraGlow(colors: auroraColors, live: light.isLive(.all) || light.hub.hasTargets)
                .frame(height: 620)
                .ignoresSafeArea()
        }
        .pageBackground()
        .sheet(isPresented: $adding) {
            AddLightSheet()
        }
        .onAppear { light.select(.all) }
    }
}

// MARK: - Karten

/// Großes Feld für alle Lichter zusammen; zeigt die Farben aller Lichter nebeneinander
private struct AllLightsCard: View {
    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav

    var body: some View {
        let lights = light.lightsOf(.all)
        let live = light.isLive(.all)
        let colors = lights.isEmpty ? [light.glow(.all)] : lights.map { light.glow(.light($0.id)) }
        let connected = lights.filter { $0.state == .on }.count
        Button {
            nav.path.append(.control(.all))
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    ForEach(Array(colors.prefix(4).enumerated()), id: \.offset) { i, c in
                        LampBadge(color: c, live: live, size: 26)
                            .offset(x: CGFloat(i) * 14)
                    }
                }
                .frame(width: 26 + CGFloat(max(min(colors.count, 4) - 1, 0)) * 14, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Alle Lichter")
                        .font(.geist(17, 600))
                        .foregroundStyle(Theme.text)
                    Text(light.demo && lights.isEmpty ? "Vorführmodus" : "\(connected) von \(lights.count) verbunden")
                        .font(.geist(12, 400))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                Icon(kind: .chevron, size: 15, color: Theme.muted)
                    .rotationEffect(.degrees(-90))
                    .padding(.trailing, 46)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.tile)
                    .overlay {
                        LinearGradient(colors: colors.map { $0.color.opacity(live ? 0.28 : 0.06) }, startPoint: .leading, endPoint: .trailing)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10).strokeBorder(live ? Theme.accent.opacity(0.8) : Theme.soft, lineWidth: Theme.border)
            }
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .overlay(alignment: .trailing) {
            PowerToggle(target: .all)
                .padding(.trailing, 14)
        }
    }
}

/// Karte für ein Licht: leuchtet in seiner Farbe, Knopf zum Ein- und Ausschalten
private struct LightCard: View {
    let item: Light

    @Environment(LightController.self) private var light
    @Environment(Navigator.self) private var nav
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmRemove = false

    private var statusLine: String {
        let t = Target.light(item.id)
        if !item.enabled { return "Getrennt" }
        switch item.state {
        case .busy:
            return item.rssi == nil ? "Nicht in Reichweite" : "Verbindet …"
        case .off:
            return "Getrennt"
        case .on:
            let look = light.lookOf(t)
            if look.power == false { return "Aus" }
            if let id = look.flowID, let flow = Flow.everything.first(where: { $0.id == id }) { return flow.name }
            if look.builtin != nil { return "Eingebauter Effekt" }
            return "An · \(look.brightness) %"
        }
    }

    var body: some View {
        let t = Target.light(item.id)
        let live = light.isLive(t)
        let glow = light.glow(t)
        Button {
            nav.path.append(.control(t))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    LampBadge(color: glow, live: live, size: 34)
                    PixelBadge(kind: item.model.pixels)
                        .padding(.top, 4)
                }
                .padding(.top, 2)
                Spacer(minLength: 14)
                Text(item.title)
                    .font(.geist(16, 600))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    if item.state == .busy && item.enabled { SearchingMark().scaleEffect(0.8) }
                    Text(statusLine)
                        .font(.geist(12, 400))
                        .foregroundStyle(item.state == .on ? Theme.text.opacity(0.75) : Theme.muted)
                        .lineLimit(1)
                }
                .padding(.top, 3)
                LightStrip(colors: [glow.color], live: live, height: 5)
                    .padding(.top, 12)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.tile)
                    .overlay {
                        RadialGradient(colors: [glow.color.opacity(live ? 0.42 : 0), .clear],
                                       center: .topLeading, startRadius: 0, endRadius: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(live ? glow.color.opacity(0.75) : Theme.soft, lineWidth: Theme.border)
            }
            .overlay {
                // Läuft ein Effekt, umkreist ein Lichtstreifen in der Farbe des Lichts die Karte
                if live && light.lookOf(t).flowID != nil {
                    ScanBorder(radius: 10, color: glow.color, period: 2.6, width: 2)
                }
            }
            .shadow(color: glow.color.opacity(live ? 0.35 : 0), radius: 16)
            .animation(.easeOut(duration: 0.4), value: live)
        }
        .buttonStyle(PressStyle())
        .overlay(alignment: .topTrailing) {
            PowerToggle(target: t)
                .padding(10)
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

/// Runder Ein/Aus-Knopf; gelb, wenn das Licht an ist
struct PowerToggle: View {
    let target: Target

    @Environment(LightController.self) private var light

    var body: some View {
        let usable = light.demo || light.isConnected(target)
        let on = usable && light.lookOf(target).power != false
        Button {
            light.setPower(!on, for: target)
        } label: {
            Icon(kind: .power, size: 16, color: on ? Color(rgb: 0x14130E) : Theme.text)
                .frame(width: 36, height: 36)
                .background(on ? Theme.accent : Theme.fill, in: Circle())
                .overlay { Circle().strokeBorder(on ? Theme.accent : Theme.line.opacity(0.5), lineWidth: Theme.border) }
                .shadow(color: Theme.accent.opacity(on ? 0.5 : 0), radius: 8)
        }
        .buttonStyle(PressStyle(scale: 0.88))
        .disabled(!usable)
        .opacity(usable ? 1 : 0.4)
        .sensoryFeedback(.impact(weight: .medium), trigger: on)
        .accessibilityLabel(on ? "Ausschalten" : "Einschalten")
    }
}

private struct AddCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Icon(kind: .plus, size: 24, color: Theme.accent)
                Text("Licht hinzufügen")
                    .font(.geist(14, 500))
                    .foregroundStyle(Theme.text)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Theme.line.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
        }
        .buttonStyle(PressStyle())
    }
}

/// Noch kein Licht: Hinweis, Hinzufügen und Vorführmodus
private struct EmptyHome: View {
    @Binding var adding: Bool

    @Environment(LightController.self) private var light

    var body: some View {
        let searching = !light.hub.setupDone && light.hub.bluetooth == .ready
        VStack(spacing: 14) {
            Icon(kind: .lamp, size: 34, color: Theme.accent)
            Text(searching ? "Suche deine LED-Leiste …" : "Noch kein Licht")
                .font(.geist(18, 600))
                .foregroundStyle(Theme.text)
            Text(searching
                 ? "Die erste ELK-Leiste in der Nähe übernimmt die App automatisch. Andere Licht-Apps vorher ganz schließen."
                 : "Licht einschalten, in die Nähe gehen und andere Licht-Apps ganz schließen. Dann hier hinzufügen.")
                .font(.geist(13, 400))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
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
                HStack(spacing: 8) {
                    Icon(kind: .sparkle, size: 15)
                    Text("Ohne Licht ausprobieren")
                }
            }
            .buttonStyle(OutlineButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Theme.tile, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.soft, lineWidth: Theme.border)
        }
        .overlay {
            if searching { ScanBorder(radius: 10) }
        }
        .padding(.top, 8)
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
                    Icon(kind: .download, size: 20, color: Theme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Update \(release.version) verfügbar")
                            .font(.geist(15, 600))
                            .foregroundStyle(Theme.text)
                        Text("Antippen für die Anleitung")
                            .font(.geist(12, 400))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                    Icon(kind: .chevron, size: 15, color: Theme.muted)
                        .rotationEffect(.degrees(-90))
                }
                .padding(14)
                .background(Theme.hot, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.accent, lineWidth: Theme.border)
                }
            }
            .buttonStyle(PressStyle(scale: 0.98))
            .padding(.bottom, 12)
        }
    }
}
