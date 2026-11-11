import AppIntents
import SwiftUI
import UIKit

/// Einstellungen: Updates, Lichter-Optionen, Siri und Kurzbefehle, Protokoll, Info
struct SettingsView: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        Page {
            PageTitle(title: "Einstellungen", subtitle: "Updates, Lichter, Kurzbefehle und Protokoll")
            SectionTitle("Updates").rise(1)
            switch updater.source {
            case .sideloaded: UpdatesTile().rise(2)
            case .testFlight: TestFlightTile().rise(2)
            case .appStore: AppStoreTile().rise(2)
            }
            SectionTitle("Lichter").rise(3)
            VStack(spacing: 12) {
                DemoTile()
                ShowAllTile()
            }
            .rise(4)
            SectionTitle("Siri & Kurzbefehle").rise(5)
            ShortcutsTile().rise(6)
            SectionTitle("Protokoll").rise(7)
            LogTile().rise(8)
            AboutTile().rise(9)
            Footer().rise(10)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .pageBackground()
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
    @State private var showTip = true

    private static let phrases = [
        "„LED Control an“ / „LED Control aus“",
        "„Schalte Wohnzimmer mit LED Control an“",
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
                Text("„Hey Siri, LED Control an“")
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
