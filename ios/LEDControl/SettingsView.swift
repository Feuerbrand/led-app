import AppIntents
import SwiftUI
import UIKit

/// Einstellungen: nur vier Punkte, jeder öffnet eine eigene Seite
struct SettingsView: View {
    @Environment(Updater.self) private var updater

    private var updateDetail: String {
        if let release = updater.available { return "Neu: \(release.version)" }
        switch updater.status {
        case .upToDate: return "Aktuell"
        case .checking: return "…"
        default: return ""
        }
    }

    var body: some View {
        Page {
            BigTitle(text: "Einstellungen")
            VStack(spacing: 0) {
                SettingsRow(route: .updates, symbol: "arrow.down.circle.fill", colors: [RGB(59, 209, 111), RGB(26, 154, 74)],
                            title: "Updates", detail: updateDetail, highlight: updater.available != nil)
                RowDivider()
                SettingsRow(route: .shortcuts, symbol: "mic.fill", colors: [RGB(196, 90, 255), RGB(90, 59, 255)],
                            title: "Siri und Kurzbefehle", detail: "", highlight: false)
                RowDivider()
                SettingsRow(route: .manage, symbol: "lightbulb.fill", colors: [RGB(255, 210, 63), RGB(224, 160, 14)],
                            title: "Lichter verwalten", detail: "", highlight: false)
                RowDivider()
                SettingsRow(route: .help, symbol: "lifepreserver.fill", colors: [RGB(59, 176, 255), RGB(26, 90, 255)],
                            title: "Hilfe und Protokoll", detail: "", highlight: false)
            }
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.edge, lineWidth: 1)
            }
            .padding(.top, 20)
            .rise(1)
            Footer().rise(2)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .pageBackground()
    }
}

/// Große Überschrift oben auf einer Seite
struct BigTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.geist(34, 800))
            .foregroundStyle(Theme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .rise(0)
    }
}

/// Zeile mit buntem Symbol wie in den Einstellungen von iOS
private struct SettingsRow: View {
    let route: Route
    let symbol: String
    let colors: [RGB]
    let title: String
    let detail: String
    let highlight: Bool

    var body: some View {
        let light: Bool = (colors.first?.perceived ?? 0) > 0.6
        let stops: [Color] = colors.map { $0.color }
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(light ? Theme.ink : Color.white)
                    .frame(width: 34, height: 34)
                    .background(LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(title)
                    .font(.geist(16, 500))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 8)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.geist(14, 500))
                        .foregroundStyle(highlight ? Theme.accent : Theme.muted)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 62)
    }
}

// MARK: - Unterseiten

struct UpdatesPage: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        Page {
            BigTitle(text: "Updates")
            Group {
                switch updater.source {
                case .sideloaded: UpdatesTile()
                case .testFlight: TestFlightTile()
                case .appStore: AppStoreTile()
                }
            }
            .padding(.top, 20)
            .rise(1)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .pageBackground()
    }
}

struct ShortcutsPage: View {
    var body: some View {
        Page {
            BigTitle(text: "Siri und Kurzbefehle")
            ShortcutsTile()
                .padding(.top, 20)
                .rise(1)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .pageBackground()
    }
}

/// Lichter umbenennen, trennen, entfernen und hinzufügen; dazu die selteneren Schalter
struct ManageLightsPage: View {
    @Environment(LightController.self) private var light
    @State private var adding = false

    var body: some View {
        let mine = light.hub.mine
        Page {
            BigTitle(text: "Lichter verwalten")
            VStack(spacing: 10) {
                ForEach(mine) { item in
                    ManageRow(item: item)
                }
                Button {
                    adding = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                        Text("Licht hinzufügen")
                    }
                }
                .buttonStyle(AccentButtonStyle())
                .padding(.top, mine.isEmpty ? 0 : 6)
            }
            .padding(.top, 20)
            .rise(1)
            SectionTitle("Erweitert").rise(2)
            VStack(spacing: 12) {
                DemoTile()
                ShowAllTile()
            }
            .rise(3)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .pageBackground()
        .sheet(isPresented: $adding) {
            AddLightSheet()
        }
    }
}

/// Ein Licht mit seinem Menü
private struct ManageRow: View {
    let item: Light

    @Environment(LightController.self) private var light
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmRemove = false

    private var stateText: String {
        if !item.enabled { return "Getrennt" }
        switch item.state {
        case .on: return "Verbunden"
        case .busy: return item.rssi == nil ? "Nicht in Reichweite" : "Verbindet …"
        case .off: return "Getrennt"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.geist(16, 600))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(item.title == item.name ? stateText : "\(item.name) · \(stateText)")
                    .font(.geist(13, 500))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if item.state == .on || item.rssi != nil {
                SignalBars(rssi: item.rssi)
            }
            Menu {
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
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.07), in: Circle())
            }
            .accessibilityLabel("\(item.title) bearbeiten")
        }
        .tile()
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

/// Kurze Hilfe, Einführung, Protokoll und Infos zur App
struct HelpPage: View {
    @AppStorage("led-app.onboarded") private var onboarded = true

    private static let topics: [(String, String)] = [
        ("Licht wird nicht gefunden",
         "Licht einschalten, in die Nähe gehen und andere Licht-Apps ganz schließen – ein Licht kann immer nur mit einer App verbunden sein."),
        ("Effekt hört auf",
         "Die bunten Effekte rechnet die App selbst. Sie laufen, solange die App offen ist; der Bildschirm bleibt dabei an. „Effekte in der Leiste“ laufen auch ohne App."),
        ("Musik",
         "Die Lichter folgen dem Takt. Die App hört dafür über das Mikrofon mit, nimmt aber nichts auf."),
        ("Gute Nacht und Aufwachen",
         "Gute Nacht macht alle Lichter warm und dimmt sie in 10 Minuten bis aus. Aufwachen ist ein Sonnenaufgang in 90 Sekunden. Beides läuft, solange die App offen ist."),
        ("Szenen",
         "Im Hauptmenü auf „Neue Szene“ tippen oder im Licht über ⋯ „Als Szene speichern“. Gedrückt halten löscht eine Szene."),
    ]

    var body: some View {
        Page {
            BigTitle(text: "Hilfe")
            VStack(spacing: 10) {
                ForEach(Self.topics, id: \.0) { topic in
                    HelpTopic(title: topic.0, text: topic.1)
                }
                Button {
                    onboarded = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Einführung nochmal ansehen")
                    }
                }
                .buttonStyle(OutlineButtonStyle())
                .padding(.top, 4)
            }
            .padding(.top, 20)
            .rise(1)
            SectionTitle("Protokoll").rise(2)
            LogTile().rise(3)
            AboutTile().rise(4)
            Footer().rise(5)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .pageBackground()
    }
}

private struct HelpTopic: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.geist(15, 700))
                .foregroundStyle(Theme.text)
            Text(text)
                .font(.geist(13, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
        }
        .tile()
    }
}

// MARK: - Lichter

private struct DemoTile: View {
    @Environment(LightController.self) private var light

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { light.demo }, set: { light.setDemo($0) })) {
                Text("Vorführmodus")
                    .font(.geist(15, 500))
                    .foregroundStyle(Theme.text)
            }
            .tint(Theme.accent)
            Text("Die App lässt sich dann ohne Licht bedienen, zum Ausprobieren oder Vorführen. Verbundene Lichter steuert sie trotzdem mit.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
        }
        .tile()
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
            Text("Beim Hinzufügen auch Geräte mit fremdem Namen anzeigen. Die App versucht es dann mit den Befehlen der ELK-Leiste – das klappt nicht bei jedem Gerät.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
        }
        .tile()
    }
}

// MARK: - Updates

private struct UpdatesTile: View {
    @Environment(Updater.self) private var updater
    @Environment(\.openURL) private var openURL

    private var statusText: String {
        if let release = updater.available { return "Neue Version \(release.version) ist da." }
        switch updater.status {
        case .idle: return "Noch nicht nachgesehen."
        case .checking: return "Sehe nach …"
        case .upToDate: return "Du hast die neueste Version."
        case .noRelease: return "Noch keine Version veröffentlicht."
        case .failed: return "GitHub war nicht erreichbar."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Icon(kind: updater.available == nil ? .check : .download, size: 17, color: Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Version \(updater.version)")
                        .font(.geist(16, 600))
                        .foregroundStyle(Theme.text)
                    Text(statusText)
                        .font(.geist(12, 400))
                        .foregroundStyle(updater.available == nil ? Theme.muted : Theme.accent)
                }
                Spacer(minLength: 8)
                Button {
                    updater.check(force: true)
                } label: {
                    Text(updater.status == .checking ? "…" : "Prüfen")
                        .font(.geist(13, 500))
                }
                .buttonStyle(CompactButtonStyle())
                .disabled(updater.status == .checking)
            }

            if updater.available != nil {
                Text("In AltStore unter „My Apps“ auf „Update“ tippen. Wer mit Sideloadly installiert, lädt die neue Datei von der Release-Seite und installiert sie am PC neu.")
                    .font(.geist(12, 400))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(2)
                HStack(spacing: 12) {
                    Button {
                        openURL(Updater.openAltStore) { done in
                            if !done { openURL(updater.available?.page ?? Updater.releasesPage) }
                        }
                    } label: {
                        Text("AltStore öffnen")
                    }
                    .buttonStyle(OutlineButtonStyle(on: true))
                    Button {
                        openURL(updater.available?.page ?? Updater.releasesPage)
                    } label: {
                        Text("Release-Seite")
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
            }

            Divider().overlay(Theme.soft)

            VStack(alignment: .leading, spacing: 8) {
                Text("Automatische Updates mit AltStore")
                    .font(.geist(14, 600))
                    .foregroundStyle(Theme.text)
                Text("Einmal die Quelle hinzufügen: dann zeigt AltStore jede neue Version an und aktualisiert sie mit einem Tippen. AltStore erneuert dabei auch die 7-Tage-Signatur von selbst.")
                    .font(.geist(12, 400))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(2)
                Button {
                    openURL(Updater.addSourceLink) { done in
                        if !done { openURL(Updater.releasesPage) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Icon(kind: .plus, size: 14)
                        Text("Quelle zu AltStore hinzufügen")
                    }
                }
                .buttonStyle(OutlineButtonStyle())
            }

            Toggle(isOn: Binding(get: { updater.automatic }, set: { updater.setAutomatic($0) })) {
                Text("Beim Öffnen nach Updates sehen")
                    .font(.geist(14, 500))
                    .foregroundStyle(Theme.text)
            }
            .tint(Theme.accent)
        }
        .tile()
    }
}

/// Über TestFlight installiert: Updates kommen von Apple, die App muss nichts selbst prüfen
private struct TestFlightTile: View {
    @Environment(Updater.self) private var updater
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Icon(kind: .check, size: 17, color: Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Version \(updater.version) über TestFlight")
                        .font(.geist(16, 600))
                        .foregroundStyle(Theme.text)
                    Text("Neue Versionen kommen automatisch.")
                        .font(.geist(12, 400))
                        .foregroundStyle(Theme.muted)
                }
            }
            Text("In der TestFlight-App bei LED Controller „Automatische Updates“ einschalten. Jede Version läuft 90 Tage; GitHub baut jeden Monat automatisch eine neue.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
            Button {
                openURL(Updater.openTestFlight)
            } label: {
                Text("TestFlight öffnen")
            }
            .buttonStyle(OutlineButtonStyle(on: true))
        }
        .tile()
    }
}

/// Aus dem App Store: Updates kommen wie bei jeder anderen App
private struct AppStoreTile: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        HStack(spacing: 10) {
            Icon(kind: .check, size: 17, color: Theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Version \(updater.version)")
                    .font(.geist(16, 600))
                    .foregroundStyle(Theme.text)
                Text("Updates kommen automatisch über den App Store.")
                    .font(.geist(12, 400))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .tile()
    }
}

// MARK: - Siri und Kurzbefehle

private struct ShortcutsTile: View {
    @State private var copied: String? = nil
    @State private var showTip = true

    private static let phrases = [
        "„LED Controller an“ / „LED Controller aus“",
        "„Schalte Wohnzimmer mit LED Controller an“",
        "„Starte Kino mit LED Control“",
    ]

    private static let links: [(String, String)] = [
        ("ledcontrol://on", "Licht an"),
        ("ledcontrol://off", "Licht aus"),
        ("ledcontrol://toggle", "Umschalten"),
        ("ledcontrol://color?hex=FF7A00", "Farbe (Hex)"),
        ("ledcontrol://brightness?value=40", "Helligkeit in %"),
        ("ledcontrol://scene?name=Kino", "Szene nach Name"),
        ("ledcontrol://flow?id=rainbow", "Flow-Effekt"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Icon(kind: .flash, size: 17, color: Theme.accent)
                Text("„Hey Siri, LED Controller an“")
                    .font(.geist(15, 600))
                    .foregroundStyle(Theme.text)
            }
            Text("Die Befehle funktionieren sofort, ohne Einrichtung – auch für einzelne Lichter und Szenen:")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Self.phrases, id: \.self) { phrase in
                    HStack(spacing: 8) {
                        Circle().fill(Theme.accent).frame(width: 5, height: 5)
                        Text(phrase)
                            .font(.geist(13, 500))
                            .foregroundStyle(Theme.text)
                    }
                }
            }
            SiriTipView(intent: LightOnIntent(), isVisible: $showTip)
            Text("In der Kurzbefehle-App findest du alle Aktionen fertig zum Antippen – für Automationen (z. B. Licht an bei Sonnenuntergang) und die Aktionstaste:")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
            ShortcutsLink()
                .frame(maxWidth: .infinity)
            Text("Links für „URL öffnen“ – antippen zum Kopieren:")
                .font(.geist(12, 500))
                .foregroundStyle(Theme.text.opacity(0.8))
                .padding(.top, 2)
            VStack(spacing: 6) {
                ForEach(Self.links, id: \.0) { item in
                    let link = item.0
                    let label = item.1
                    Button {
                        UIPasteboard.general.string = link
                        copied = link
                    } label: {
                        HStack(spacing: 8) {
                            Text(link)
                                .font(.geistMono(12, 400))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 6)
                            Text(copied == link ? "Kopiert" : label)
                                .font(.geist(11, 500))
                                .foregroundStyle(copied == link ? Theme.accent : Theme.muted)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.edge, lineWidth: 1)
                        }
                    }
                    .buttonStyle(PressStyle(scale: 0.98))
                }
            }
        }
        .tile()
        .sensoryFeedback(.success, trigger: copied)
    }
}

// MARK: - Protokoll, Info und Fuß

private struct LogTile: View {
    @Environment(LightController.self) private var light

    var body: some View {
        ScrollView {
            Text(light.log)
                .font(.geistMono(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(height: 160)
        .tile()
    }
}

private struct AboutTile: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Über die App")
                .font(.geist(14, 600))
                .foregroundStyle(Theme.text)
            Text("Steuert ELK-BLEDOM-Leisten und MELK-Lichter direkt über Bluetooth. Die Befehle der MELK-Lichter stammen aus dem Open-Source-Projekt „elkbledom“ von dave-code-ruiz (MIT-Lizenz). Schrift: Geist (SIL Open Font License).")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
        }
        .tile()
        .padding(.top, 12)
    }
}

struct Footer: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                BulbGlass().fill(Theme.text)
                BulbBase().fill(Theme.text)
            }
            .frame(width: 16, height: 16)
            HStack(spacing: 0) {
                Text("LED").foregroundStyle(Theme.text)
                Text("CONTROLLER").foregroundStyle(Theme.accent)
            }
            .font(.geist(12, 700))
            .tracking(0.96)
            Text("iOS \(version)")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
        }
        .padding(.top, 22)
    }
}
