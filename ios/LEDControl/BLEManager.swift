import CoreBluetooth
import Foundation

/// off = getrennt, busy = sucht/verbindet, on = verbunden
enum LinkState {
    case off, busy, on
}

/// Findet die ELK-Leiste ohne Geräteliste, verbindet und baut die Verbindung bei Abbruch selbst neu auf.
/// Alle Rückrufe kommen auf dem Hauptthread.
final class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var onState: (LinkState, String) -> Void = { _, _ in }
    var onLog: (String) -> Void = { _ in }
    var onReady: () -> Void = {}
    var onLost: () -> Void = {}

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var wantConnected = true        // true = Nutzer will verbunden sein -> bei Abbruch automatisch neu verbinden
    private var lostLink = false            // true = es gab schon eine Verbindung, die abgerissen ist
    private var tries = 0
    private var searchedAll = false
    private var retry: DispatchWorkItem?    // läuft, solange ein Verbindungsversuch offen ist
    private var lastErrAt = Date.distantPast

    private static let storeKey = "led-app.device"

    var isReady: Bool { writeChar != nil }

    /// false, solange der Sendepuffer von iOS voll ist
    var canSend: Bool { peripheral?.canSendWriteWithoutResponse ?? false }

    static func isStrip(_ name: String?) -> Bool {
        (name ?? "").uppercased().hasPrefix(Command.namePrefix)
    }

    // MARK: - Bedienung

    /// Bluetooth starten. Beim ersten Mal fragt iOS hier nach der Bluetooth-Erlaubnis.
    func start() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func connect() {
        wantConnected = true
        lostLink = false
        tries = 0
        if central?.state == .poweredOn {
            attempt()
        } else {
            reportUnavailable()
        }
    }

    func disconnect() {
        let was = isReady
        wantConnected = false
        dropLink()
        onLost()
        onState(.off, "Nicht verbunden")
        onLog(was ? "Verbindung getrennt" : "Abgebrochen")
    }

    /// App ist wieder im Vordergrund: fehlt die Verbindung und läuft kein Versuch, neu verbinden
    func resume() {
        guard wantConnected, !isReady, retry == nil else { return }
        attempt()
    }

    func write(_ bytes: [UInt8]) {
        guard let p = peripheral, let c = writeChar else { return }
        let type: CBCharacteristicWriteType = c.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        p.writeValue(Data(bytes), for: c, type: type)
    }

    // MARK: - Verbindungsaufbau

    /// Ein Versuch: bekannte Leiste direkt ansprechen und gleichzeitig nach ELK-BLED… suchen.
    /// Klappt es nicht innerhalb von 12 s, startet der nächste Versuch.
    private func attempt() {
        guard wantConnected, let central, central.state == .poweredOn, !isReady else { return }
        tries += 1
        searchedAll = false
        // Ein noch wartender Verbindungsaufbau bleibt bestehen (iOS verbindet, sobald die Leiste auftaucht).
        // Alles andere – abgerissen oder verbunden, aber ohne Dienst hängen geblieben – wird verworfen.
        if let old = peripheral, old.state != .connecting {
            peripheral = nil
            old.delegate = nil
            if old.state != .disconnected { central.cancelPeripheralConnection(old) }
        }
        if peripheral == nil, let p = knownPeripheral(central) {
            if tries == 1 && !lostLink { onLog("Bekannte Leiste – verbinde automatisch …") }
            link(p, central)
        }
        central.stopScan()
        central.scanForPeripherals(withServices: nil, options: nil)
        announce()
        schedule(after: 12)
    }

    /// Leiste von früher (gespeicherte Kennung) oder eine, die iOS gerade schon verbunden hält
    private func knownPeripheral(_ central: CBCentralManager) -> CBPeripheral? {
        if let text = UserDefaults.standard.string(forKey: Self.storeKey),
           let id = UUID(uuidString: text),
           let p = central.retrievePeripherals(withIdentifiers: [id]).first {
            return p
        }
        return central.retrieveConnectedPeripherals(withServices: [Command.service]).first { Self.isStrip($0.name) }
    }

    private func link(_ p: CBPeripheral, _ central: CBCentralManager) {
        peripheral = p
        p.delegate = self
        central.connect(p, options: nil)
    }

    /// Alles Laufende beenden: Suche, offenen Versuch, bestehende Verbindung
    private func dropLink() {
        retry?.cancel()
        retry = nil
        writeChar = nil
        guard let central, central.state == .poweredOn else {
            peripheral = nil
            return
        }
        central.stopScan()
        if let p = peripheral {
            peripheral = nil
            p.delegate = nil
            central.cancelPeripheralConnection(p)
        }
    }

    private func schedule(after seconds: TimeInterval) {
        retry?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.attempt() }
        retry = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func announce() {
        if lostLink {
            onState(.busy, "Verbinde neu … (Versuch \(tries))")
        } else if let p = peripheral {
            onState(.busy, "Verbinde mit \(p.name ?? "LED-Leiste") …")
        } else {
            onState(.busy, "Suche die LED-Leiste …")
        }
    }

    private func reportUnavailable() {
        switch central?.state {
        case .poweredOff:
            onState(.off, "Bluetooth ist ausgeschaltet")
            onLog("Bluetooth ist aus – bitte im Kontrollzentrum oder in den Einstellungen einschalten.")
        case .unauthorized:
            onState(.off, "Bluetooth nicht erlaubt")
            onLog("Bitte erlauben: Einstellungen → Apps → LED Control → Bluetooth.")
        case .unsupported:
            onState(.off, "Kein Bluetooth LE")
            onLog("Dieses Gerät kann kein Bluetooth LE.")
        default:
            onState(.busy, "Bluetooth startet …")
        }
    }

    /// Verbindung ist weg oder kam nicht zustande
    private func linkEnded(_ p: CBPeripheral) {
        // Meldungen zu einer früheren, inzwischen ersetzten Verbindung nicht beachten
        guard p === peripheral, p.state == .disconnected else { return }
        let was = isReady
        writeChar = nil
        if was { onLost() }
        guard wantConnected else { return }
        if was {
            lostLink = true
            tries = 0
            onLog("Verbindung verloren – verbinde automatisch neu …")
            onState(.busy, "Verbinde neu …")
        }
        schedule(after: was ? 0.3 : 1)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if wantConnected { attempt() }
        case .poweredOff, .unauthorized, .unsupported, .resetting:
            // Alle bisherigen Verbindungen sind jetzt ungültig
            let was = isReady
            retry?.cancel()
            retry = nil
            peripheral?.delegate = nil
            peripheral = nil
            writeChar = nil
            if was { onLost() }
            reportUnavailable()
        default:
            break                           // .unknown: abwarten
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover found: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let adName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard wantConnected, !isReady, Self.isStrip(adName) || Self.isStrip(found.name) else { return }
        if let current = peripheral {
            // Schon dabei, genau diese Leiste zu verbinden -> nichts tun
            if current.identifier == found.identifier || current.state == .connected { return }
            current.delegate = nil
            central.cancelPeripheralConnection(current)
        }
        onLog("Leiste gefunden: \(adName ?? found.name ?? "ELK-BLEDOM")")
        link(found, central)
        announce()
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        guard p === peripheral else {
            central.cancelPeripheralConnection(p)
            return
        }
        central.stopScan()
        schedule(after: 10)                 // Frist, um Dienst und Merkmal zu finden
        p.discoverServices([Command.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        linkEnded(p)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        linkEnded(p)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard p === peripheral else { return }
        let services = p.services ?? []
        let wanted = services.filter { $0.uuid == Command.service }
        if wanted.isEmpty && !searchedAll {
            // Manche Nachbauten melden FFF0 nur in der vollen Liste
            searchedAll = true
            p.discoverServices(nil)
            return
        }
        if wanted.isEmpty {
            onLog("Dienst FFF0 nicht gefunden – suche das Schreib-Merkmal FFF3 in allen Diensten.")
        }
        for s in (wanted.isEmpty ? services : wanted) {
            p.discoverCharacteristics([Command.characteristic], for: s)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard p === peripheral, writeChar == nil,
              let c = service.characteristics?.first(where: { $0.uuid == Command.characteristic }) else { return }
        writeChar = c
        retry?.cancel()
        retry = nil
        lostLink = false
        tries = 0
        UserDefaults.standard.set(p.identifier.uuidString, forKey: Self.storeKey)
        let name = p.name ?? "LED-Leiste"
        onState(.on, "Verbunden mit \(name)")
        onLog("Verbunden mit \(name) ✓")
        onReady()
    }

    func peripheral(_ p: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let error, Date().timeIntervalSince(lastErrAt) > 3 else { return }
        lastErrAt = Date()
        onLog("Fehler: \(error.localizedDescription)")
    }
}
