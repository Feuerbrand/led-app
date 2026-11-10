import Foundation
import Observation

/// Fragt bei GitHub nach, ob es eine neuere Version der App gibt.
/// Neue Versionen veröffentlicht der Build-Workflow als GitHub-Release `ios-v1.1.<Build>`
/// samt AltStore-Quelle (altstore.json), über die AltStore die App aktualisiert.
@Observable
final class Updater {
    struct Release: Equatable {
        let version: String
        let build: Int
        let page: URL
    }

    enum Status: Equatable {
        case idle, checking, upToDate, noRelease, failed
    }

    static let repo = "Feuerbrand/led-app"
    static let sourceURL = "https://github.com/\(repo)/releases/latest/download/altstore.json"
    static let releasesPage = URL(string: "https://github.com/\(repo)/releases")!

    /// Öffnet AltStore und fügt die Quelle hinzu (danach kommen Updates über AltStore)
    static var addSourceLink: URL {
        var parts = URLComponents()
        parts.scheme = "altstore"
        parts.host = "source"
        parts.queryItems = [URLQueryItem(name: "url", value: sourceURL)]
        return parts.url ?? releasesPage
    }

    static let openAltStore = URL(string: "altstore://")!

    private(set) var latest: Release? = nil
    private(set) var status: Status = .idle
    private(set) var automatic: Bool

    let version: String
    let build: Int
    /// Über TestFlight installiert: Updates kommen dann von Apple, nicht über GitHub
    let viaTestFlight: Bool

    static let openTestFlight = URL(string: "itms-beta://")!

    @ObservationIgnored private var lastCheck: Date? = nil
    private static let autoKey = "led-app.updates.auto"

    /// Neuere Version als die installierte, sonst nil
    var available: Release? {
        guard !viaTestFlight, let latest, latest.build > build else { return nil }
        return latest
    }

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        version = info["CFBundleShortVersionString"] as? String ?? "1.0"
        build = Int(info["CFBundleVersion"] as? String ?? "") ?? 0
        let defaults = UserDefaults.standard
        automatic = defaults.object(forKey: Self.autoKey) as? Bool ?? true
        // TestFlight-Apps haben eine Test-Quittung, aber (anders als selbst signierte) kein eingebettetes Profil
        let sandbox = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        let profile = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
        viaTestFlight = sandbox && !profile
    }

    func setAutomatic(_ on: Bool) {
        automatic = on
        UserDefaults.standard.set(on, forKey: Self.autoKey)
        if on { check() }
    }

    /// Nachsehen; ohne `force` höchstens alle 30 Minuten und nur, wenn automatisch eingeschaltet
    func check(force: Bool = false) {
        if viaTestFlight || status == .checking { return }
        if !force {
            guard automatic else { return }
            if let lastCheck, Date().timeIntervalSince(lastCheck) < 30 * 60 { return }
        }
        lastCheck = Date()
        status = .checking
        Task { @MainActor [self] in
            status = await fetch()
        }
    }

    private struct GitHubRelease: Decodable {
        let tag_name: String
        let html_url: String
    }

    private func fetch() async -> Status {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else { return .failed }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 404 { return .noRelease }           // noch nichts veröffentlicht
            guard code == 200 else { return .failed }
            let info = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard let release = Self.parse(tag: info.tag_name, page: info.html_url) else { return .noRelease }
            latest = release
            return .upToDate
        } catch {
            return .failed
        }
    }

    /// „ios-v1.1.42“ -> Version 1.1.42, Build 42
    static func parse(tag: String, page: String) -> Release? {
        let prefix = "ios-v"
        guard tag.hasPrefix(prefix), let url = URL(string: page) else { return nil }
        let version = String(tag.dropFirst(prefix.count))
        guard let last = version.split(separator: ".").last, let build = Int(last) else { return nil }
        return Release(version: version, build: build, page: url)
    }
}
