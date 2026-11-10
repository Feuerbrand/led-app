import Observation
import SwiftUI
import UIKit

/// Die vier Reiter der App
enum AppTab: Int, CaseIterable {
    case light, effects, devices, more

    var title: String {
        switch self {
        case .light: return "Licht"
        case .effects: return "Effekte"
        case .devices: return "Geräte"
        case .more: return "Mehr"
        }
    }

    var icon: IconKind {
        switch self {
        case .light: return .lamp
        case .effects: return .sparkle
        case .devices: return .bluetooth
        case .more: return .sliders
        }
    }
}

/// Welcher Reiter offen ist (damit Kacheln auf andere Reiter springen können)
@Observable
final class Navigator {
    var tab: AppTab = .light
}

/// Grundgerüst: Hintergrund, Lichtpunkte, der offene Reiter und die Leiste unten
struct ContentView: View {
    @Environment(LightController.self) private var light
    @Environment(Updater.self) private var updater
    @Environment(\.scenePhase) private var scenePhase
    @State private var nav = Navigator()

    var body: some View {
        ZStack {
            Backdrop()
            ParticleField()
            Group {
                switch nav.tab {
                case .light: LightTab()
                case .effects: EffectsTab()
                case .devices: DevicesTab()
                case .more: MoreTab()
                }
            }
            .id(nav.tab)
            .transition(.opacity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(nav: nav)
        }
        .environment(nav)
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.18), value: nav.tab)
        .sensoryFeedback(.selection, trigger: nav.tab)
        .sensoryFeedback(.success, trigger: light.connectedCount)
        .onChange(of: scenePhase) { _, phase in
            // Zurück in der App: Verbindungen prüfen und nach Updates sehen
            if phase == .active {
                light.resume()
                updater.check()
            }
        }
        .onChange(of: light.keepAwake, initial: true) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        .onAppear {
            let name = UserDefaults.standard.string(forKey: "screenshotTab") ?? ""
            if let tab = AppTab.allCases.first(where: { "\($0)" == name }) { nav.tab = tab }
        }
    }
}

/// Seite eines Reiters: Inhalt mittig, höchstens 520 Punkte breit, scrollbar
struct TabPage<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: 520)
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16))
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

/// Kleine Überschrift oben auf den Reitern Effekte, Geräte und Mehr
struct PageTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text(title.uppercased())
                    .font(.geist(26, 700))
                    .tracking(2)
                    .foregroundStyle(Theme.text)
            }
            Text(subtitle)
                .font(.geist(13, 400))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
        .padding(.horizontal, 4)
        .rise(0)
    }
}

// MARK: - Leiste unten

private struct TabBar: View {
    let nav: Navigator

    @Environment(LightController.self) private var light
    @Environment(Updater.self) private var updater

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                item(tab)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background {
            Rectangle()
                .fill(Color(rgb: 0x0B0A07))
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.soft).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func item(_ tab: AppTab) -> some View {
        let on = nav.tab == tab
        return Button {
            nav.tab = tab
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Icon(kind: tab.icon, size: 22, color: on ? Theme.accent : Theme.muted)
                        .shadow(color: Theme.accent.opacity(on ? 0.6 : 0), radius: 8)
                    badge(tab)
                        .offset(x: 6, y: -3)
                }
                Text(tab.title)
                    .font(.geist(11, on ? 600 : 500))
                    .foregroundStyle(on ? Theme.text : Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: on ? 22 : 0, height: 3)
                    .offset(y: -8)
                    .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.35), value: on)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.92))
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Kleiner Punkt: Geräte = Anzahl verbundener Lichter, Mehr = Update verfügbar
    @ViewBuilder
    private func badge(_ tab: AppTab) -> some View {
        switch tab {
        case .devices:
            let count = light.hub.targets.count
            if count > 0 {
                Text("\(count)")
                    .font(.geist(10, 700))
                    .foregroundStyle(Color(rgb: 0x14130E))
                    .frame(minWidth: 15, minHeight: 15)
                    .background(Theme.accent, in: Capsule())
            }
        case .more:
            if updater.available != nil {
                Circle().fill(Theme.accent).frame(width: 9, height: 9)
            }
        default:
            EmptyView()
        }
    }
}
