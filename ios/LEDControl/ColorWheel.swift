import SwiftUI

/// Farbrad zum Ziehen: rundherum der Farbton, zur Mitte hin weißer.
/// Liefert beim Ziehen laufend die Farbe an der Fingerposition.
struct ColorWheel: View {
    let color: RGB
    let onPick: (RGB) -> Void

    @State private var dragging = false

    /// Farbtöne im Uhrzeigersinn ab „3 Uhr“, passend zu SwiftUIs AngularGradient
    private static let hues: [Color] = stride(from: 0.0, through: 360.0, by: 30).map { ColorMath.hsv($0, 1, 1).color }

    /// Farbton (Grad) und Sättigung (0…1) einer Farbe
    static func position(of c: RGB) -> (hue: Double, saturation: Double) {
        let mx = Double(c.peak)
        let mn = Double(min(c.r, c.g, c.b))
        let s = mx > 0 ? (mx - mn) / mx : 0
        return (ColorMath.hue(of: c), s)
    }

    /// Farbe an einem Punkt relativ zur Mitte (dx, dy in Punkten, r = Radius)
    static func color(dx: Double, dy: Double, radius r: Double) -> RGB {
        var deg = atan2(dy, dx) * 180 / Double.pi
        if deg < 0 { deg += 360 }
        let sat = min((dx * dx + dy * dy).squareRoot() / max(r, 1), 1)
        return ColorMath.hsv(deg, sat, 1)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let r = size / 2
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let pos = Self.position(of: color)
            let angle = pos.hue * Double.pi / 180
            let knobX = cx + CGFloat(cos(angle) * pos.saturation) * r
            let knobY = cy + CGFloat(sin(angle) * pos.saturation) * r
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: Self.hues, center: .center))
                    .frame(width: size, height: size)
                    .position(x: cx, y: cy)
                Circle()
                    .fill(RadialGradient(colors: [Color.white, Color.white.opacity(0)], center: .center, startRadius: 0, endRadius: r))
                    .frame(width: size, height: size)
                    .position(x: cx, y: cy)
                Circle()
                    .strokeBorder(Theme.line, lineWidth: Theme.border)
                    .frame(width: size, height: size)
                    .position(x: cx, y: cy)
                // Knopf an der gewählten Farbe
                Circle()
                    .fill(color.color)
                    .frame(width: 30, height: 30)
                    .overlay { Circle().strokeBorder(Theme.text, lineWidth: 3) }
                    .overlay { Circle().strokeBorder(Color(rgb: 0x14130E), lineWidth: 1).padding(-1) }
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                    .scaleEffect(dragging ? 1.25 : 1)
                    .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.2), value: dragging)
                    .position(x: knobX, y: knobY)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        dragging = true
                        onPick(Self.color(dx: Double(v.location.x - cx), dy: Double(v.location.y - cy), radius: Double(r)))
                    }
                    .onEnded { _ in dragging = false }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .sensoryFeedback(.impact(weight: .light), trigger: dragging)
        .accessibilityElement()
        .accessibilityLabel("Farbrad")
        .accessibilityValue(color.hex)
    }
}
