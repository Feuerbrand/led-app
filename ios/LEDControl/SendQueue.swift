import Foundation

/// Sende-Warteschlange mit der Regel aus `pump` in index.html:
/// Steuerbefehle (An/Aus, Helligkeit, Effekt, Tempo) gehen nie verloren, je Art zählt der neueste.
/// Von Farbwerten wird immer nur der neueste geschickt, damit sich bei Animationen nichts staut.
struct SendQueue {
    private var ctrl: [(key: String, bytes: [UInt8])] = []
    private var frame: RGB?
    private var lastSent: RGB?

    var isEmpty: Bool { ctrl.isEmpty && frame == nil }

    /// Steuerbefehl einreihen. Gibt es die Art schon, wird nur der Inhalt ersetzt (Platz in der Reihe bleibt).
    mutating func control(_ key: String, _ bytes: [UInt8]) {
        if let i = ctrl.firstIndex(where: { $0.key == key }) {
            ctrl[i].bytes = bytes
        } else {
            ctrl.append((key: key, bytes: bytes))
        }
    }

    /// Neueste Farbe merken, eine noch nicht gesendete ältere wird überschrieben
    mutating func color(_ c: RGB) {
        frame = c
    }

    /// Nächstes Paket für die Leiste. nil = diesmal nichts zu senden (gleiche Farbe wie zuletzt).
    mutating func next() -> [UInt8]? {
        if !ctrl.isEmpty {
            lastSent = nil
            return ctrl.removeFirst().bytes
        }
        guard let f = frame else { return nil }
        frame = nil
        if f == lastSent { return nil }          // gleiche Farbe nicht doppelt schicken
        lastSent = f
        return Command.color(f)
    }

    /// Nach einer neuen Verbindung: die erste Farbe auf jeden Fall senden
    mutating func forgetLast() {
        lastSent = nil
    }

    mutating func clear() {
        ctrl.removeAll()
        frame = nil
    }
}
