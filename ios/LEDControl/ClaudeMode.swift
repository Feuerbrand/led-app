import AVFoundation
import Darwin
import Foundation
import Observation
import UIKit

/// Claude-Modus (21.11.2026): Die Lichter zeigen, was Claude Code am PC gerade macht.
/// Am PC meldet ein kleiner Dienst („claude-light“, Port 8796) den Zustand. Die App fragt ihn jede Sekunde
/// im WLAN ab und färbt alle Lichter: Orange = Claude arbeitet, Grün = fertig, Weiß = wartet auf deine Antwort.
/// Den PC findet die App selbst (fragt alle Adressen im eigenen WLAN); die Adresse lässt sich auch eintippen.
/// Läuft auch im Hintergrund weiter: eine stumme Audio-Wiedergabe (gemischt mit anderer Musik) hält die App wach,
/// Bluetooth darf im Hintergrund senden (UIBackgroundModes audio + bluetooth-central in Info.plist).
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
        loop?.cancel()
        loop = nil
        phase = nil
        misses = 0
        guard on else { link = .off; KeepAwake.shared.stop(); return }
        KeepAwake.shared.start()
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
            // Musik-Modus oder ein Anruf kann die Audio-Sitzung beenden: dann sofort wieder wach halten
            KeepAwake.shared.ensure()
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

/// Hält die App im Hintergrund wach, solange der Claude-Modus an ist: spielt eine stumme Tonspur in Schleife,
/// gemischt mit anderer Musik (nichts zu hören, andere Apps spielen normal weiter).
final class KeepAwake {
    static let shared = KeepAwake()
    private var player: AVAudioPlayer?
    private var observers: [NSObjectProtocol] = []
    private var wanted = false

    func start() {
        wanted = true
        if observers.isEmpty {
            let center = NotificationCenter.default
            observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                if raw == AVAudioSession.InterruptionType.ended.rawValue { self?.ensure() }
            })
            observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
                self?.player = nil
                self?.ensure()
            })
        }
        ensure()
    }

    func stop() {
        wanted = false
        player?.stop()
        player = nil
    }

    /// Spielt die stumme Schleife (oder startet sie neu, falls etwas die Audio-Sitzung beendet hat)
    func ensure() {
        guard wanted else { return }
        let session = AVAudioSession.sharedInstance()
        // Der Musik-Modus nutzt playAndRecord: dann nur aktiv halten, nicht umstellen
        if session.category != .playAndRecord {
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
        try? session.setActive(true)
        if player == nil {
            player = try? AVAudioPlayer(data: Self.silence(seconds: 2))
            player?.numberOfLoops = -1
            player?.volume = 0
            player?.prepareToPlay()
        }
        if player?.isPlaying != true { player?.play() }
    }

    /// Stille als WAV im Speicher (8 kHz, 16 Bit, mono)
    private static func silence(seconds: Int) -> Data {
        let rate = 8000, samples = rate * seconds, bytes = samples * 2
        var d = Data()
        func u32(_ v: Int) { var x = UInt32(v).littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func u16(_ v: Int) { var x = UInt16(v).littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(rate); u32(rate * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(bytes)
        d.append(Data(count: bytes))
        return d
    }
}
