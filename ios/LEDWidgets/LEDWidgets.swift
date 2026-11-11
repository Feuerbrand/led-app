import AppIntents
import SwiftUI
import WidgetKit

/// Knöpfe außerhalb der App: Kontrollzentrum, Sperrbildschirm und Home-Bildschirm.
/// Ein Tippen öffnet die App kurz, sie verbindet sich und schaltet die Lichter.
@main
struct LEDWidgetBundle: WidgetBundle {
    var body: some Widget {
        LightsControl()
        GoodnightControl()
        LightsWidget()
    }
}

private enum Look {
    static let accent = Color(red: 1, green: 210 / 255, blue: 63 / 255)
    static let ink = Color(red: 20 / 255, green: 19 / 255, blue: 14 / 255)
    static let bg = Color(red: 11 / 255, green: 10 / 255, blue: 7 / 255)
}

// MARK: - Kontrollzentrum und Sperrbildschirm

struct LightsControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "de.feuerbrand.ledcontrol.toggle") {
            ControlWidgetButton(action: ControlToggleIntent()) {
                Label("LED an/aus", systemImage: "lightbulb.fill")
            }
        }
        .displayName("LED an/aus")
        .description("Schaltet alle Lichter an oder aus.")
    }
}

struct GoodnightControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "de.feuerbrand.ledcontrol.goodnight") {
            ControlWidgetButton(action: ControlGoodnightIntent()) {
                Label("Gute Nacht", systemImage: "moon.stars.fill")
            }
        }
        .displayName("Gute Nacht")
        .description("Alle Lichter werden warm und dimmen in 10 Minuten bis aus.")
    }
}

// MARK: - Home-Bildschirm und Sperrbildschirm-Widget

struct LightsEntry: TimelineEntry {
    let date: Date
}

struct LightsProvider: TimelineProvider {
    func placeholder(in context: Context) -> LightsEntry {
        LightsEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (LightsEntry) -> Void) {
        completion(LightsEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LightsEntry>) -> Void) {
        completion(Timeline(entries: [LightsEntry(date: Date())], policy: .never))
    }
}

struct LightsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "de.feuerbrand.ledcontrol.lights", provider: LightsProvider()) { _ in
            LightsWidgetView()
        }
        .configurationDisplayName("LED Controller")
        .description("Lichter mit einem Tippen schalten.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

private struct LightsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularView()
        case .systemMedium:
            MediumView()
        default:
            SmallView()
        }
    }
}

/// Hintergrund: warmes Schwarz mit gelbem Schimmer
private struct GlowBackground: View {
    var body: some View {
        ZStack {
            Look.bg
            RadialGradient(colors: [Look.accent.opacity(0.35), Look.accent.opacity(0)],
                           center: UnitPoint(x: 0.2, y: 0.15), startRadius: 0, endRadius: 160)
        }
    }
}

private struct BulbBadge: View {
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: "lightbulb.fill")
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(Look.ink)
            .frame(width: size, height: size)
            .background(Look.accent, in: Circle())
            .shadow(color: Look.accent.opacity(0.6), radius: 10)
    }
}

/// Klein: ganzes Widget antippen = an/aus
private struct SmallView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BulbBadge()
            Spacer(minLength: 6)
            Text("LED Controller")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text("Antippen: an/aus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "ledcontrol://toggle"))
        .containerBackground(for: .widget) { GlowBackground() }
    }
}

/// Mittel: drei Knöpfe
private struct MediumView: View {
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                BulbBadge()
                Spacer(minLength: 6)
                Text("LED Controller")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxHeight: .infinity, alignment: .leading)
            VStack(spacing: 8) {
                WidgetLink(title: "An", symbol: "power", url: "ledcontrol://on", filled: true)
                WidgetLink(title: "Aus", symbol: "power.circle", url: "ledcontrol://off", filled: false)
                WidgetLink(title: "Gute Nacht", symbol: "moon.stars.fill", url: "ledcontrol://goodnight", filled: false)
            }
        }
        .containerBackground(for: .widget) { GlowBackground() }
    }
}

private struct WidgetLink: View {
    let title: String
    let symbol: String
    let url: String
    let filled: Bool

    var body: some View {
        Link(destination: URL(string: url) ?? URL(fileURLWithPath: "/")) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(filled ? Look.ink : Color.white)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(filled ? Look.accent : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// Sperrbildschirm: rundes Lämpchen, antippen = an/aus
private struct CircularView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 22, weight: .semibold))
        }
        .widgetURL(URL(string: "ledcontrol://toggle"))
        .containerBackground(for: .widget) { Color.clear }
    }
}
