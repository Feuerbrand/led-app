import SwiftUI
import UIKit

/// Reiter „Mehr“: Updates, Siri und Kurzbefehle, Protokoll, Info
struct MoreTab: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        TabPage {
            PageTitle(title: "Mehr", subtitle: "Updates, Kurzbefehle und Protokoll")
            SectionTitle("Updates").rise(1)
            switch updater.source {
            case .sideloaded: UpdatesTile().rise(2)
            case .testFlight: TestFlightTile().rise(2)
            case .appStore: AppStoreTile().rise(2)
            }
            SectionTitle("Siri & Kurzbefehle").rise(3)
            ShortcutsTile().rise(4)
            SectionTitle("Protokoll").rise(5)
            LogTile().rise(6)
            AboutTile().rise(7)
            Footer().rise(8)
        }
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
            Text("In der TestFlight-App bei LED Control „Automatische Updates“ einschalten. Jede Version läuft 90 Tage; GitHub baut jeden Monat automatisch eine neue.")
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
                Text("„Hey Siri, LED Control an“")
                    .font(.geist(15, 600))
                    .foregroundStyle(Theme.text)
            }
            Text("Funktioniert auch mit „… aus“ und „… umschalten“. In der Kurzbefehle-App gibt es außerdem „Szene starten“ und „Helligkeit setzen“ – gut für Automationen (z. B. Licht an bei Sonnenuntergang) und die Aktionstaste.")
                .font(.geist(12, 400))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.soft, lineWidth: 1)
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
                Text("CONTROL").foregroundStyle(Theme.accent)
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
