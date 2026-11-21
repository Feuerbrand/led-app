import Darwin
import Foundation
import Observation
import UIKit

/// Claude-Modus (21.11.2026): Die Lichter zeigen, was Claude Code am PC gerade macht.
/// Am PC meldet ein kleiner Dienst („claude-light“, Port 8796) den Zustand. Die App fragt ihn jede Sekunde
/// im WLAN ab und färbt alle Lichter: Orange = Claude arbeitet, Grün = fertig, Weiß = wartet auf deine Antwort.
/// Den PC findet die App selbst (fragt alle Adressen im eigenen WLAN); die Adresse lässt sich auch eintippen.
/// Läuft, solange die App offen ist; der Bildschirm bleibt dabei an.
@Observable
final class ClaudeMode {
    static let shared = ClaudeMode()
    static let port = 8796
    private static let hostKey = "led-app.claude.host"
    private static let onKey = "led-app.claude.on"

    enum Phase: String { case working, done, waiting }
    enum Link: Equatable { case off, searching, connected, lost }

    private(set) var enabled = false
    private(set) var phase: Phase? = nil
    private(set) var link: Link = .off
    private(set) var host: String = UserDefaults.standard.string(forKey: ClaudeMode.hostKey) ?? ""

    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var misses = 0

    /// Farben der drei Zustände
    static func color(_ p: Phase) -> RGB {
        switch p {
        case .working: return RGB(255, 90, 0)
        case .done: return RGB(0, 255, 60)
        case .waiting: return RGB(255, 255, 255)
        }
    }

    static func label(_ p: Phase) -> String {
        switch p {
        case .working: return "Claude arbeitet"
        case .done: return "Claude ist fertig"
        case .waiting: return "Claude wartet auf dich"
        }
    }

    /// Nach dem Start der App: war der Modus an, läuft er weiter
    func restore() {
        if UserDefaults.standard.bool(forKey: Self.onKey) && !enabled { setEnabled(true) }
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        UserDefaults.standard.set(on, forKey: Self.onKey)
        UIApplication.shared.isIdleTimerDisabled = on
        loop?.cancel()
        loop = nil
        phase = nil
        misses = 0
        guard on else { link = .off; return }
        link = host.isEmpty ? .searching : .lost
        loop = Task { @MainActor [weak self] in await self?.run() }
    }

    /// Adresse von Hand (leer = wieder suchen)
    func setHost(_ value: String) {
        host = value.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(host, forKey: Self.hostKey)
        if enabled { setEnabled(true) }
    }

    @MainActor private func run() async {
        if host.isEmpty { await search() }
        while !Task.isCancelled && enabled {
            if host.isEmpty {
                link = .lost
                try? await Task.sleep(for: .seconds(3))
                if Task.isCancelled { break }
                await search()
                continue
            }
            if let p = await Self.fetch(host) {
                misses = 0
                link = .connected
                if p != phase {
                    phase = p
                    LightController.shared.showStatus(Self.color(p))
                }
            } else {
                misses += 1
                if misses >= 4 { link = .lost }
                // Der PC hat vielleicht eine neue Adresse bekommen: im WLAN neu suchen
                if misses == 12 { await search() }
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Sucht den PC im WLAN: fragt alle Adressen im eigenen Netz (x.x.x.1 bis 254) auf Port 8796
    @MainActor func search() async {
        let before = link
        link = .searching
        guard let prefix = Self.localPrefix() else { link = before == .connected ? .connected : .lost; return }
        let found: String? = await withTaskGroup(of: String?.self) { group in
            for i in 1...254 {
                let ip = "\(prefix).\(i)"
                group.addTask { await Self.fetch(ip, timeout: 1.5) != nil ? ip : nil }
            }
            for await hit in group {
                if let hit {
                    group.cancelAll()
                    return hit
                }
            }
            return nil
        }
        if let found {
            host = found
            UserDefaults.standard.set(found, forKey: Self.hostKey)
            misses = 0
            link = .connected
        } else {
            link = .lost
        }
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    /// Fragt den Dienst am PC: {"app":"claude-light","state":"working|done|waiting"}
    static func fetch(_ host: String, timeout: TimeInterval = 2) async -> Phase? {
        guard let url = URL(string: "http://\(host):\(port)/status") else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["app"] as? String == "claude-light",
              let state = json["state"] as? String else { return nil }
        return Phase(rawValue: state) ?? .done
    }

    /// Eigene WLAN-Adresse (en0) ohne die letzte Zahl, z. B. „192.168.178“
    static func localPrefix() -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            let entry = current.pointee
            if String(cString: entry.ifa_name) == "en0", let addr = entry.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                var name = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &name, socklen_t(name.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let parts = String(cString: name).split(separator: ".")
                    if parts.count == 4 { return parts.prefix(3).joined(separator: ".") }
                }
            }
            cursor = entry.ifa_next
        }
        return nil
    }
}
