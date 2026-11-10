import Foundation

#if os(iOS)
import AVFoundation
#endif

/// Misst über das Mikrofon, wie laut es gerade ist, und liefert daraus einen Pegel 0…1 für den Musik-Modus.
/// Der Pegel passt sich an die Umgebung an: leise Musik schlägt genauso aus wie laute.
final class SoundMeter {
    /// Aktueller Pegel 0…1 (nur auf dem Hauptthread lesen)
    private(set) var level = 0.0
    private(set) var running = false

    private var floorLevel = 0.0     // leisester Wert der letzten Zeit
    private var peakLevel = 0.02     // lautester Wert der letzten Zeit

    /// Neuer Messwert (Lautstärke des letzten Tonstücks)
    private func push(_ rms: Double) {
        if !running { return }
        // Grenzen wandern langsam mit, damit sich der Ausschlag an die Lautstärke im Raum anpasst
        floorLevel = rms < floorLevel ? rms : floorLevel + (rms - floorLevel) * 0.002
        peakLevel = rms > peakLevel ? rms : max(0.02, peakLevel * 0.9995)
        let span = max(peakLevel - floorLevel, 0.01)
        level = min(max((rms - floorLevel) / span, 0), 1)
    }

    #if os(iOS)
    private let engine = AVAudioEngine()

    /// Mikrofon einschalten. `done(false)`, wenn es nicht erlaubt ist oder nicht startet.
    func start(_ done: @escaping (Bool) -> Void) {
        if running {
            done(true)
            return
        }
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self, granted else {
                    done(false)
                    return
                }
                done(self.begin())
            }
        }
    }

    private func begin() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            // Andere Apps (Musik) spielen weiter, die App hört nur mit
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { return false }
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                guard let samples = buffer.floatChannelData?[0] else { return }
                let count = Int(buffer.frameLength)
                if count == 0 { return }
                var sum: Float = 0
                for i in 0..<count {
                    sum += samples[i] * samples[i]
                }
                let rms = Double((sum / Float(count)).squareRoot())
                DispatchQueue.main.async { self?.push(rms) }
            }
            engine.prepare()
            try engine.start()
            floorLevel = 0
            peakLevel = 0.02
            level = 0
            running = true
            return true
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            return false
        }
    }

    func stop() {
        if !running { return }
        running = false
        level = 0
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    #else
    // Auf dem Mac (nur für den Selbsttest) gibt es keinen Musik-Modus
    func start(_ done: @escaping (Bool) -> Void) { done(false) }
    func stop() { running = false }
    #endif
}
