import CoreBluetooth
import Foundation
import Observation

/// off = getrennt, busy = sucht/verbindet/meldet an, on = verbunden und bereit
enum LinkState {
    case off, busy, on
}

enum BluetoothState {
    case starting, ready, off, denied, unsupported
}

/// Ein Licht: die ELK-Leiste, ein MELK-Licht aus Lotus Lamp X oder ein weiteres Gerät derselben Familie.
@Observable
final class Light: Identifiable {
    let id: UUID
    let model: LightModel
    fileprivate(set) var name: String
    /// Eigener Name, leer = Gerätename anzeigen
    fileprivate(set) var alias: String
    /// In „Meine Lichter“ aufgenommen
    fileprivate(set) var saved: Bool
    /// Soll verbunden sein und mitgesteuert werden
    fileprivate(set) var enabled: Bool
    fileprivate(set) var state: LinkState = .off
    /// Empfangsstärke beim Finden (dBm), nil = in dieser Sitzung noch nicht gesehen
    fileprivate(set) var rssi: Int? = nil

    @ObservationIgnored fileprivate var peripheral: CBPeripheral?
    @ObservationIgnored fileprivate var writeChar: CBCharacteristic?
    @ObservationIgnored fileprivate var queue: SendQueue
    @ObservationIgnored fileprivate var pumping = false
    @ObservationIgnored fileprivate var searchedAll = false
    @ObservationIgnored fileprivate var watchdog: DispatchWorkItem?
    /// Zählt bei jedem Verbindungswechsel hoch, damit eine alte Anmeldung nicht weiterläuft
    @ObservationIgnored fileprivate var session = 0

    var title: String { alias.isEmpty ? name : alias }

    fileprivate init(id: UUID, name: String, alias: String, model: LightModel, saved: Bool, enabled: Bool) {
        self.id = id
        self.name = name
        self.alias = alias
        self.model = model
        self.saved = saved
        self.enabled = enabled
        self.queue = SendQueue(encode: model.color)
    }
}

/// Findet Lichter, hält die Verbindungen und verteilt Befehle an alle verbundenen Lichter.
/// Jedes Licht hat seine eigene Sende-Warteschlange. Alle Rückrufe kommen auf dem Hauptthread.
@Observable
final class LightHub: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    /// Erst die eigenen Lichter, dahinter die nur gefundenen
    private(set) var lights: [Light] = []
    private(set) var bluetooth: BluetoothState = .starting
    /// Auch Bluetooth-Geräte mit fremdem Namen in der Liste zeigen
    private(set) var showAll = false
    /// Es wurde schon einmal ein Licht hinzugefügt (dann wird nichts mehr automatisch übernommen)
    private(set) var setupDone = UserDefaults.standard.bool(forKey: "led-app.setup")

    @ObservationIgnored var onLog: (String) -> Void = { _ in }
    /// Ein Licht ist frisch verbunden (und angemeldet): jetzt den aktuellen Zustand übertragen
    @ObservationIgnored var onReady: (Light) -> Void = { _ in }

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var browsing = false
    @ObservationIgnored private var scanning = false
    @ObservationIgnored private var lastErrAt = Date.distantPast

    private static let storeKey = "led-app.lights"
    private static let oldStoreKey = "led-app.device"

    private struct Stored: Codable {
        var id: UUID
        var name: String
        var alias: String
        var enabled: Bool
        /// Namensanfang der Bauart; fehlt bei Einträgen aus älteren Versionen
        var model: String?
    }

    // MARK: - Was die Oberfläche fragt

    var mine: [Light] { lights.filter { $0.saved } }
    var nearby: [Light] { lights.filter { !$0.saved && ($0.model.known || showAll) } }
    /// Lichter, die gerade Befehle bekommen
    var targets: [Light] { lights.filter { $0.state == .on } }
    var hasTargets: Bool { lights.contains { $0.state == .on } }

    var summary: LinkState {
        if hasTargets { return .on }
        if bluetooth == .starting { return .busy }
        if bluetooth != .ready { return .off }
        if mine.isEmpty { return setupDone ? .off : .busy }   // erster Start: sucht die Leiste
        return mine.contains { $0.state == .busy } ? .busy : .off
    }

    var statusText: String {
        switch bluetooth {
        case .starting: return "Bluetooth startet …"
        case .off: return "Bluetooth ist ausgeschaltet"
        case .denied: return "Bluetooth nicht erlaubt"
        case .unsupported: return "Kein Bluetooth LE"
        case .ready: break
        }
        let on = targets
        if on.count == 1 { return "Verbunden mit \(on[0].title)" }
        if on.count > 1 { return "\(on.count) Lichter verbunden" }
        if mine.isEmpty { return setupDone ? "Kein Licht – unter „Geräte“ hinzufügen" : "Suche die LED-Leiste …" }
        let busy = mine.filter { $0.state == .busy }
        if busy.count == 1 { return "Verbinde mit \(busy[0].title) …" }
        if busy.count > 1 { return "Verbinde mit \(busy.count) Lichtern …" }
        return "Nicht verbunden"
    }

    /// Bauarten der verbundenen Lichter (für die Listen der eingebauten Effekte)
    var families: [EffectFamily] {
        EffectFamily.allCases.filter { family in targets.contains { $0.model.family == family } }
    }

    // MARK: - Bedienung

    /// Bluetooth starten. Beim ersten Mal fragt iOS hier nach der Bluetooth-Erlaubnis.
    func start() {
        guard central == nil else { return }
        load()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    /// Geräteliste ist sichtbar: dauernd suchen, damit neue Lichter auftauchen,
    /// und bei verbundenen Lichtern regelmäßig die Empfangsstärke abfragen
    func setBrowsing(_ on: Bool) {
        let was = browsing
        browsing = on
        if on { adoptConnected() }
        updateScan()
        guard on, !was else { return }
        Task { @MainActor [self] in
            while browsing {
                for light in targets { light.peripheral?.readRSSI() }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func setShowAll(_ on: Bool) {
        showAll = on
    }

    /// Gespeicherte eigene Lichter (Kennung und angezeigter Name), ohne Bluetooth zu starten – für Siri und Kurzbefehle
    static func storedLights() -> [(id: UUID, title: String)] {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let list = try? JSONDecoder().decode([Stored].self, from: data) else { return [] }
        return list.map { (id: $0.id, title: $0.alias.isEmpty ? $0.name : $0.alias) }
    }

    func light(id: UUID) -> Light? {
        lights.first { $0.id == id }
    }

    /// Licht mit eigenem Namen aufnehmen und verbinden
    func add(_ light: Light, name: String) {
        light.alias = name.trimmingCharacters(in: .whitespacesAndNewlines)
        add(light)
    }

    /// Licht in „Meine Lichter“ aufnehmen und verbinden
    func add(_ light: Light) {
        light.saved = true
        light.enabled = true
        if !setupDone {
            setupDone = true
            UserDefaults.standard.set(true, forKey: "led-app.setup")
        }
        sort()
        persist()
        open(light)
        updateScan()
    }

    /// Licht vergessen. Ist es noch in Reichweite, bleibt es unter „In der Nähe“ stehen.
    func remove(_ light: Light) {
        close(light)
        light.saved = false
        light.enabled = false
        light.alias = ""
        if light.rssi == nil { lights.removeAll { $0 === light } }
        sort()
        persist()
        updateScan()
    }

    /// Verbinden und mitsteuern (an) oder trennen (aus)
    func setEnabled(_ light: Light, _ on: Bool) {
        guard light.saved, light.enabled != on else { return }
        light.enabled = on
        persist()
        if on {
            open(light)
        } else {
            close(light)
            onLog("\(light.title) getrennt")
        }
    }

    func rename(_ light: Light, to alias: String) {
        light.alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    /// App ist wieder im Vordergrund: fehlende Verbindungen neu anstoßen
    func resume() {
        guard central?.state == .poweredOn else { return }
        for light in mine where light.enabled && light.state != .on { open(light) }
        updateScan()
    }

    // MARK: - Senden

    /// Steuerbefehl an alle verbundenen Lichter (oder nur an die einer Bauart)
    func send(_ order: Order, only family: EffectFamily? = nil) {
        for light in targets where family == nil || light.model.family == family {
            send(order, to: light)
        }
    }

    func send(_ order: Order, to light: Light) {
        guard light.state == .on else { return }
        light.queue.control(order.key, order.bytes(for: light.model))
        pump(light)
    }

    /// Farbe an alle verbundenen Lichter; je Licht wird nur die neueste geschickt
    func send(color: RGB) {
        for light in targets {
            light.queue.color(color)
            pump(light)
        }
    }

    func send(color: RGB, to light: Light) {
        guard light.state == .on else { return }
        light.queue.color(color)
        pump(light)
    }

    /// Schickt die Warteschlange eines Lichts, mit 28 ms Pause zwischen zwei Paketen (rund 25 pro Sekunde).
    private func pump(_ light: Light) {
        if light.pumping { return }
        guard light.peripheral != nil else {
            light.queue.clear()                 // Beispiel-Licht ohne echte Verbindung
            return
        }
        light.pumping = true
        Task { @MainActor [self] in
            var stalled = 0
            while light.state == .on, !light.queue.isEmpty {
                if !canSend(light), stalled < 12 {
                    // Sendepuffer von iOS ist voll: kurz warten, nichts verwerfen
                    stalled += 1
                    try? await Task.sleep(for: .milliseconds(15))
                    continue
                }
                stalled = 0
                guard let bytes = light.queue.next() else { continue }
                write(bytes, to: light)
                try? await Task.sleep(for: .milliseconds(28))
            }
            if light.state != .on { light.queue.clear() }
            light.pumping = false
        }
    }

    private func canSend(_ light: Light) -> Bool {
        light.peripheral?.canSendWriteWithoutResponse ?? false
    }

    private func write(_ bytes: [UInt8], to light: Light) {
        guard let p = light.peripheral, let c = light.writeChar else { return }
        let type: CBCharacteristicWriteType = c.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        p.writeValue(Data(bytes), for: c, type: type)
    }

    /// Nur für die automatischen App-Store-Bilder: Beispiel-Lichter ohne echte Verbindung.
    /// Sie werden nicht gespeichert.
    func showSampleLights() {
        guard lights.isEmpty else { return }
        let melk = LightModel.find(prefix: "MELK-OA21") ?? LightModel.elk
        let samples: [(name: String, alias: String, model: LightModel, on: Bool, rssi: Int)] = [
            ("ELK-BLEDDM", "Leiste Wohnzimmer", LightModel.elk, true, -54),
            ("MELK-OA21", "Leiste Schlafzimmer", melk, true, -66),
            ("ELK-BLEDOM", "", LightModel.elk, false, -81),
        ]
        for s in samples {
            let light = Light(id: UUID(), name: s.name, alias: s.alias, model: s.model, saved: s.on, enabled: s.on)
            light.state = s.on ? .on : .off
            light.rssi = s.rssi
            lights.append(light)
        }
        bluetooth = .ready
    }

    // MARK: - Speichern

    private func load() {
        var stored: [Stored] = []
        if let data = UserDefaults.standard.data(forKey: Self.storeKey),
           let list = try? JSONDecoder().decode([Stored].self, from: data) {
            stored = list
        } else if let text = UserDefaults.standard.string(forKey: Self.oldStoreKey), let id = UUID(uuidString: text) {
            // Aus der ersten App-Version: eine einzelne gemerkte Leiste
            stored = [Stored(id: id, name: "ELK-BLEDOM", alias: "", enabled: true, model: LightModel.elk.prefix)]
        }
        lights = stored.map { item -> Light in
            let model = item.model.flatMap { LightModel.find(prefix: $0) } ?? LightModel.detect(item.name) ?? LightModel.generic
            return Light(id: item.id, name: item.name, alias: item.alias, model: model, saved: true, enabled: item.enabled)
        }
        if !lights.isEmpty && !setupDone {
            setupDone = true
            UserDefaults.standard.set(true, forKey: "led-app.setup")
        }
    }

    private func persist() {
        let stored = mine.map { Stored(id: $0.id, name: $0.name, alias: $0.alias, enabled: $0.enabled, model: $0.model.prefix) }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        }
    }

    private func sort() {
        lights = lights.filter { $0.saved } + lights.filter { !$0.saved }
    }

    private func entry(for p: CBPeripheral) -> Light? {
        lights.first { $0.id == p.identifier }
    }

    // MARK: - Verbindungsaufbau

    /// Verbindung zu einem Licht anstoßen. iOS hält den Versuch offen und verbindet, sobald das Licht auftaucht.
    private func open(_ light: Light) {
        guard let central, central.state == .poweredOn, light.saved, light.enabled else { return }
        if light.peripheral == nil {
            light.peripheral = central.retrievePeripherals(withIdentifiers: [light.id]).first
        }
        if light.state != .on { light.state = .busy }
        guard let p = light.peripheral else { return }          // noch unbekannt: die Suche liefert es nach
        p.delegate = self
        switch p.state {
        case .disconnected, .disconnecting:
            central.connect(p, options: nil)
        case .connected:
            if light.writeChar == nil { discover(light, p) }
        default:
            break                                               // .connecting: läuft schon
        }
    }

    private func close(_ light: Light) {
        light.session += 1
        light.watchdog?.cancel()
        light.watchdog = nil
        light.writeChar = nil
        light.queue.clear()
        light.state = .off
        if let central, central.state == .poweredOn, let p = light.peripheral {
            central.cancelPeripheralConnection(p)
        }
    }

    private func discover(_ light: Light, _ p: CBPeripheral) {
        light.searchedAll = false
        light.watchdog?.cancel()
        // Frist, um Dienst und Merkmal zu finden; sonst trennen und neu verbinden
        let item = DispatchWorkItem { [weak self, weak light] in
            guard let self, let light, light.writeChar == nil, let p = light.peripheral else { return }
            self.central?.cancelPeripheralConnection(p)
        }
        light.watchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: item)
        p.discoverServices([Command.service])
    }

    /// Schreib-Merkmal gefunden: bei MELK erst anmelden, dann ist das Licht bereit
    private func login(_ light: Light) {
        light.session += 1
        let session = light.session
        let steps = light.model.login
        if steps.isEmpty {
            ready(light)
            return
        }
        Task { @MainActor [self] in
            for bytes in steps {
                guard light.session == session, light.writeChar != nil else { return }
                write(bytes, to: light)
                try? await Task.sleep(for: .seconds(1))
            }
            guard light.session == session, light.writeChar != nil else { return }
            ready(light)
        }
    }

    private func ready(_ light: Light) {
        light.queue.clear()
        light.queue.forgetLast()
        light.state = .on
        onLog("Verbunden mit \(light.title) ✓")
        onReady(light)
    }

    /// Verbindung ist weg oder kam nicht zustande
    private func linkEnded(_ p: CBPeripheral) {
        guard let light = entry(for: p), light.peripheral === p else { return }
        let was = light.state == .on
        light.session += 1
        light.watchdog?.cancel()
        light.watchdog = nil
        light.writeChar = nil
        light.queue.clear()
        guard light.saved, light.enabled else {
            light.state = .off
            return
        }
        light.state = .busy
        if was { onLog("Verbindung zu \(light.title) verloren – verbinde automatisch neu …") }
        DispatchQueue.main.asyncAfter(deadline: .now() + (was ? 0.3 : 1)) { [weak self, weak light] in
            guard let self, let light else { return }
            self.open(light)
        }
    }

    /// Suchen, solange die Geräteliste offen ist, die Leiste beim ersten Start noch gesucht wird
    /// oder ein eigenes Licht noch nie gesehen wurde
    private func updateScan() {
        guard let central, central.state == .poweredOn else {
            scanning = false
            return
        }
        let missing = mine.contains { $0.enabled && $0.peripheral == nil }
        let want = browsing || !setupDone || missing
        if want && !scanning {
            central.scanForPeripherals(withServices: nil, options: nil)
            scanning = true
        } else if !want && scanning {
            central.stopScan()
            scanning = false
        }
    }

    /// Lichter, die iOS gerade schon verbunden hält (etwa durch Lotus Lamp X), senden keinen Namen mehr aus
    private func adoptConnected() {
        guard let central, central.state == .poweredOn else { return }
        for p in central.retrieveConnectedPeripherals(withServices: [Command.service]) {
            found(p, name: p.name, rssi: nil)
        }
    }

    private func found(_ p: CBPeripheral, name: String?, rssi: Int?) {
        if let light = entry(for: p) {
            if let rssi { light.rssi = rssi } else if light.rssi == nil { light.rssi = -60 }
            if let name, !name.isEmpty, light.name != name {
                light.name = name
                if light.saved { persist() }
            }
            if light.peripheral == nil {
                light.peripheral = p
                if light.saved && light.enabled { open(light) }
                updateScan()
            }
            return
        }
        guard let name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let model = LightModel.detect(name) ?? LightModel.generic
        let light = Light(id: p.identifier, name: name, alias: "", model: model, saved: false, enabled: false)
        light.peripheral = p
        light.rssi = rssi ?? -60
        lights.append(light)
        if model.known { onLog("Licht gefunden: \(name)") }
        // Allererster Start: die eigene ELK-Leiste ohne Nachfrage übernehmen. Andere Lichter
        // (MELK …) erscheinen nur in der Liste und werden erst nach „Hinzufügen“ verbunden.
        if !setupDone && model.autoAdopt { add(light) }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            bluetooth = .ready
            scanning = false
            adoptConnected()
            for light in mine where light.enabled { open(light) }
            updateScan()
        case .poweredOff, .unauthorized, .unsupported, .resetting:
            // Alle bisherigen Verbindungen sind jetzt ungültig
            scanning = false
            for light in lights {
                light.session += 1
                light.watchdog?.cancel()
                light.watchdog = nil
                light.peripheral = nil
                light.writeChar = nil
                light.queue.clear()
                light.rssi = nil
                light.state = .off
            }
            lights.removeAll { !$0.saved }
            switch central.state {
            case .poweredOff:
                bluetooth = .off
                onLog("Bluetooth ist aus – bitte im Kontrollzentrum oder in den Einstellungen einschalten.")
            case .unauthorized:
                bluetooth = .denied
                onLog("Bitte erlauben: Einstellungen → Apps → LED Controller → Bluetooth.")
            case .unsupported:
                bluetooth = .unsupported
                onLog("Dieses Gerät kann kein Bluetooth LE.")
            default:
                bluetooth = .starting
            }
        default:
            break                                               // .unknown: abwarten
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let adName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        found(p, name: adName ?? p.name, rssi: RSSI.intValue)
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        guard let light = entry(for: p), light.peripheral === p, light.saved, light.enabled else {
            central.cancelPeripheralConnection(p)
            return
        }
        discover(light, p)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        linkEnded(p)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        linkEnded(p)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard let light = entry(for: p), light.peripheral === p else { return }
        let services = p.services ?? []
        let wanted = services.filter { $0.uuid == Command.service }
        if wanted.isEmpty && !light.searchedAll {
            // Manche Nachbauten melden FFF0 nur in der vollen Liste
            light.searchedAll = true
            p.discoverServices(nil)
            return
        }
        if wanted.isEmpty {
            onLog("\(light.title): Dienst FFF0 nicht gefunden – suche das Schreib-Merkmal FFF3 in allen Diensten.")
        }
        for s in (wanted.isEmpty ? services : wanted) {
            p.discoverCharacteristics([Command.characteristic], for: s)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let light = entry(for: p), light.peripheral === p, light.writeChar == nil,
              let c = service.characteristics?.first(where: { $0.uuid == Command.characteristic }) else { return }
        light.writeChar = c
        light.watchdog?.cancel()
        light.watchdog = nil
        login(light)
    }

    func peripheral(_ p: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil, let light = entry(for: p) else { return }
        light.rssi = RSSI.intValue
    }

    func peripheral(_ p: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let error, Date().timeIntervalSince(lastErrAt) > 3 else { return }
        lastErrAt = Date()
        onLog("Fehler: \(error.localizedDescription)")
    }
}
