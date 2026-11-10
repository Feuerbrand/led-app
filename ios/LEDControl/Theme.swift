import CoreText
import SwiftUI

/// Stil wie der PureClient und die Webseite: warmes Schwarz, dünne helle Rahmen, Gelb nur als Akzent.
enum Theme {
    static let accent = Color(rgb: 0xFFD23F)
    static let text = Color(rgb: 0xF4F1E8)
    static let muted = Color(rgb: 0xF0ECE0, opacity: 0.5)
    static let icon = Color(rgb: 0xE9E3D2)
    static let line = Color.white.opacity(0.6)          // heller Rahmen (Knöpfe, Leisten)
    static let soft = Color.white.opacity(0.14)         // leiser Rahmen (Kacheln)
    static let fill = Color(rgb: 0x0A0907, opacity: 0.5)
    static let tile = Color(rgb: 0x161510, opacity: 0.9)
    static let hot = Color(rgb: 0x261F09, opacity: 0.82)
    static let border: CGFloat = 1.5
    /// Hintergrund der Seiten
    static let bg = Color(rgb: 0x0B0A07)
    /// Flächen (Paneele) – flach, ohne Verlauf
    static let panel = Color(rgb: 0x141310)
    /// Haarlinie um Paneele
    static let hair = Color.white.opacity(0.10)
    /// Ausgeschaltete LED
    static let ledOff = Color(rgb: 0x27251F)
    /// Dunkle Schrift auf Gelb
    static let ink = Color(rgb: 0x14130E)
    static let curve = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.7)
}

extension Color {
    init(rgb: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((rgb >> 16) & 0xff) / 255,
                  green: Double((rgb >> 8) & 0xff) / 255,
                  blue: Double(rgb & 0xff) / 255,
                  opacity: opacity)
    }
}

extension RGB {
    var color: Color {
        Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

/// Geist und Geist Mono (variable Schriften, Gewicht 100…900) aus dem Ordner Fonts.
/// Die Schrift wird direkt aus der Datei geladen; fehlt sie, nimmt die App die Systemschrift.
enum Fonts {
    private static let sans = descriptor("Geist")
    private static let mono = descriptor("GeistMono")
    private static var cache: [String: Font] = [:]

    private static func descriptor(_ file: String) -> CTFontDescriptor? {
        guard let url = Bundle.main.url(forResource: file, withExtension: "ttf"),
              let all = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { return nil }
        return all.first
    }

    private static func systemWeight(_ weight: CGFloat) -> Font.Weight {
        if weight >= 650 { return .bold }
        if weight >= 550 { return .semibold }
        if weight >= 450 { return .medium }
        return .regular
    }

    static func make(mono useMono: Bool, size: CGFloat, weight: CGFloat) -> Font {
        let key = "\(useMono)/\(size)/\(weight)"
        if let hit = cache[key] { return hit }
        let font: Font
        if let base = useMono ? mono : sans {
            let axis = NSNumber(value: 0x77676874)       // Achse 'wght' der variablen Schrift
            let variation: [NSNumber: NSNumber] = [axis: NSNumber(value: Double(weight))]
            let attributes: [String: Any] = [kCTFontVariationAttribute as String: variation]
            let sized = CTFontDescriptorCreateCopyWithAttributes(base, attributes as CFDictionary)
            font = Font(CTFontCreateWithFontDescriptor(sized, size, nil))
        } else {
            font = .system(size: size, weight: systemWeight(weight), design: useMono ? .monospaced : .default)
        }
        cache[key] = font
        return font
    }
}

extension Font {
    static func geist(_ size: CGFloat, _ weight: CGFloat = 500) -> Font {
        Fonts.make(mono: false, size: size, weight: weight)
    }

    static func geistMono(_ size: CGFloat, _ weight: CGFloat = 400) -> Font {
        Fonts.make(mono: true, size: size, weight: weight)
    }
}

// MARK: - Farbe der kleinen Symbole (Knöpfe färben sie beim Drücken gelb)

private struct IconTintKey: EnvironmentKey {
    static let defaultValue: Color = Theme.icon
}

extension EnvironmentValues {
    var iconTint: Color {
        get { self[IconTintKey.self] }
        set { self[IconTintKey.self] = newValue }
    }
}
