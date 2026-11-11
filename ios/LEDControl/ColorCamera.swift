import AVFoundation
import Combine
import SwiftUI
import UIKit

/// „Farbe abfotografieren“: die Kamera schaut auf die Mitte des Bildes, das Licht nimmt diese Farbe an.
/// Es wird nichts aufgenommen oder gespeichert.
struct ColorCameraView: View {
    @Environment(LightController.self) private var light
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var sampler = ColorSampler()
    @State private var live = true
    @State private var lastSent: Date = .distantPast
    @State private var sent: RGB? = nil

    /// Farbe fürs Licht: kräftiger und heller als das Kamerabild, sonst wirkt sie auf der Leiste matt
    private var ledColor: RGB? {
        sampler.color.map { ColorSampler.boost($0) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if sampler.denied {
                denied
            } else {
                CameraPreview(session: sampler.session)
                    .ignoresSafeArea()
                Reticle(color: ledColor)
            }
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) {
            if !sampler.denied { bottomBar }
        }
        .preferredColorScheme(.dark)
        .onAppear { sampler.start() }
        .onDisappear { sampler.stop() }
        .onChange(of: ledColor) { _, c in
            guard live, let c else { return }
            send(c)
        }
        .sensoryFeedback(.selection, trigger: sent?.hex ?? "")
    }

    private var topBar: some View {
        HStack {
            Text("Farbe abfotografieren")
                .font(.geist(17, 700))
                .foregroundStyle(.white)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Schließen")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        let c: RGB = ledColor ?? RGB(40, 40, 40)
        return VStack(spacing: 14) {
            HStack(spacing: 14) {
                Circle()
                    .fill(c.color)
                    .frame(width: 46, height: 46)
                    .overlay { Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 2) }
                    .shadow(color: c.color.opacity(0.8), radius: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ledColor == nil ? "Kamera startet …" : ColorName.of(c))
                        .font(.geist(18, 700))
                        .foregroundStyle(.white)
                    Text(live ? "Dein Licht leuchtet live mit" : "Live aus – erst beim Übernehmen")
                        .font(.geist(13, 500))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 8)
                Toggle("Live", isOn: $live)
                    .labelsHidden()
                    .tint(Theme.accent)
            }
            Button {
                if let c = ledColor { light.pick(c, instant: true) }
                dismiss()
            } label: {
                Text("Farbe übernehmen")
                    .font(.geist(17, 700))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressStyle(scale: 0.96))
            .disabled(ledColor == nil)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var denied: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("Die App darf die Kamera nicht benutzen.")
                .font(.geist(17, 600))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Einstellungen öffnen") { openURL(url) }
                    .buttonStyle(OutlineButtonStyle(on: true))
                    .frame(maxWidth: 260)
            }
        }
        .padding(30)
    }

    /// Höchstens etwa sieben Farben pro Sekunde, und nur, wenn sie sich merklich ändert
    private func send(_ c: RGB) {
        let now = Date()
        if now.timeIntervalSince(lastSent) < 0.14 { return }
        if let sent, LightController.similar(sent, c) { return }
        lastSent = now
        sent = c
        light.pick(c, instant: true)
    }
}

/// Kreis in der Mitte: zeigt, wo die Farbe gemessen wird
private struct Reticle: View {
    let color: RGB?

    var body: some View {
        let c: Color = color?.color ?? .white
        ZStack {
            Circle()
                .strokeBorder(c, lineWidth: 8)
                .frame(width: 112, height: 112)
                .shadow(color: c.opacity(0.9), radius: 18)
            Circle()
                .strokeBorder(Color.white, lineWidth: 2)
                .frame(width: 96, height: 96)
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
        }
        .animation(.easeOut(duration: 0.15), value: color?.hex ?? "")
        .allowsHitTesting(false)
    }
}

/// Live-Bild der Kamera
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var preview: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.preview?.session = session
        view.preview?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}

/// Liest laufend die mittlere Farbe des Kamerabilds
final class ColorSampler: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published private(set) var color: RGB? = nil
    @Published private(set) var denied = false

    private let queue = DispatchQueue(label: "led-app.camera")
    private var configured = false
    private var frame = 0

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                DispatchQueue.main.async {
                    if ok { self?.run() } else { self?.denied = true }
                }
            }
        default:
            denied = true
        }
    }

    func stop() {
        let session = self.session
        queue.async { session.stopRunning() }
    }

    private func run() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured { self.configure() }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    private func configure() {
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .medium
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frame += 1
        if frame % 3 != 0 { return }
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let average = Self.average(pixels) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.color = average
        }
    }

    /// Mittelwert eines kleinen Quadrats in der Bildmitte (BGRA)
    private static func average(_ pixels: CVPixelBuffer) -> RGB? {
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixels) else { return nil }
        let width = CVPixelBufferGetWidth(pixels)
        let height = CVPixelBufferGetHeight(pixels)
        let row = CVPixelBufferGetBytesPerRow(pixels)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let half = max(min(width, height) / 14, 2)
        let cx = width / 2
        let cy = height / 2
        var r = 0
        var g = 0
        var b = 0
        var n = 0
        var y = cy - half
        while y < cy + half {
            var x = cx - half
            while x < cx + half {
                let o = y * row + x * 4
                b += Int(bytes[o])
                g += Int(bytes[o + 1])
                r += Int(bytes[o + 2])
                n += 1
                x += 2
            }
            y += 2
        }
        guard n > 0 else { return nil }
        return RGB(r / n, g / n, b / n)
    }

    /// Kamerafarbe für die LEDs aufbereiten: volle Helligkeit, etwas mehr Sättigung.
    /// Fast graue Flächen bleiben weißlich.
    static func boost(_ c: RGB) -> RGB {
        let mx = Double(max(c.r, c.g, c.b))
        let mn = Double(min(c.r, c.g, c.b))
        if mx < 1 { return RGB(255, 255, 255) }
        let saturation: Double = (mx - mn) / mx
        let hue: Double = ColorMath.hue(of: c)
        let s: Double = saturation < 0.12 ? saturation * 0.5 : min(1, saturation * 1.45 + 0.08)
        return ColorMath.hsv(hue, s, 1)
    }
}
