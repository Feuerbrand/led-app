import SwiftUI

/// Die Linien-Symbole der Webseite, im selben 24er-Raster wie die SVG-Symbole in index.html.
enum IconKind {
    case bluetooth, power, moon, sun, drop, speed, list, chevron
}

private func pt(_ x: Double, _ y: Double) -> CGPoint {
    CGPoint(x: x, y: y)
}

/// Skaliert einen Pfad aus dem 24er-Raster auf die gewünschte Größe
private func fit(_ path: Path, in rect: CGRect) -> Path {
    let s = min(rect.width, rect.height) / 24
    return path
        .applying(CGAffineTransform(scaleX: s, y: s))
        .offsetBy(dx: rect.minX, dy: rect.minY)
}

struct IconShape: Shape {
    let kind: IconKind

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch kind {
        case .bluetooth:
            p.addLines([pt(7, 7), pt(17, 17), pt(12, 22), pt(12, 2), pt(17, 7), pt(7, 17)])

        case .power:
            p.move(to: pt(12, 3))
            p.addLine(to: pt(12, 11))
            p.move(to: pt(7.05, 6.05))
            p.addRelativeArc(center: pt(12, 11), radius: 7, startAngle: .degrees(225), delta: .degrees(-270))

        case .moon:
            p.move(to: pt(20, 14.5))
            p.addRelativeArc(center: pt(16.8565, 7.1435), radius: 8, startAngle: .degrees(66.863), delta: .degrees(136.274))
            p.addRelativeArc(center: pt(12.6435, 11.3565), radius: 8, startAngle: .degrees(246.863), delta: .degrees(-223.726))
            p.closeSubpath()

        case .sun:
            p.addEllipse(in: CGRect(x: 8, y: 8, width: 8, height: 8))
            let rays: [(CGPoint, CGPoint)] = [
                (pt(12, 2), pt(12, 4)), (pt(12, 20), pt(12, 22)),
                (pt(2, 12), pt(4, 12)), (pt(20, 12), pt(22, 12)),
                (pt(4.9, 4.9), pt(6.3, 6.3)), (pt(17.7, 17.7), pt(19.1, 19.1)),
                (pt(4.9, 19.1), pt(6.3, 17.7)), (pt(17.7, 6.3), pt(19.1, 4.9)),
            ]
            for (a, b) in rays {
                p.move(to: a)
                p.addLine(to: b)
            }

        case .drop:
            p.move(to: pt(12, 3))
            p.addCurve(to: pt(18, 13.5), control1: pt(12, 3), control2: pt(18, 9.2))
            p.addRelativeArc(center: pt(12, 13.5), radius: 6, startAngle: .degrees(0), delta: .degrees(180))
            p.addCurve(to: pt(12, 3), control1: pt(6, 9.2), control2: pt(12, 3))
            p.closeSubpath()

        case .speed:
            p.addEllipse(in: CGRect(x: 4, y: 5, width: 16, height: 16))
            p.move(to: pt(12, 13))
            p.addLine(to: pt(15, 10))
            p.move(to: pt(10, 2))
            p.addLine(to: pt(14, 2))

        case .list:
            p.move(to: pt(4, 6))
            p.addLine(to: pt(20, 6))
            p.move(to: pt(4, 12))
            p.addLine(to: pt(20, 12))
            p.move(to: pt(4, 18))
            p.addLine(to: pt(14, 18))

        case .chevron:
            p.addLines([pt(6, 9), pt(12, 15), pt(18, 9)])
        }
        return fit(p, in: rect)
    }
}

/// Symbol mit runder Linie. Ohne eigene Farbe nimmt es die Farbe, die der Knopf vorgibt.
struct Icon: View {
    let kind: IconKind
    var size: CGFloat = 17
    var color: Color? = nil

    @Environment(\.iconTint) private var tint

    var body: some View {
        IconShape(kind: kind)
            .stroke(color ?? tint, style: StrokeStyle(lineWidth: size * 2.2 / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

/// Glaskolben der Lampe
struct BulbGlass: Shape {
    func path(in rect: CGRect) -> Path {
        let neck = 55.085        // Winkel, an dem der runde Kolben in den Hals übergeht
        var p = Path()
        p.move(to: pt(12, 2))
        p.addRelativeArc(center: pt(12, 9), radius: 7, startAngle: .degrees(-90), delta: .degrees(-90 - neck))
        p.addLine(to: pt(8, 17))
        p.addRelativeArc(center: pt(9, 17), radius: 1, startAngle: .degrees(180), delta: .degrees(-90))
        p.addLine(to: pt(15, 18))
        p.addRelativeArc(center: pt(15, 17), radius: 1, startAngle: .degrees(90), delta: .degrees(-90))
        p.addLine(to: pt(16, 14.74))
        p.addRelativeArc(center: pt(12, 9), radius: 7, startAngle: .degrees(neck), delta: .degrees(-90 - neck))
        p.closeSubpath()
        return fit(p, in: rect)
    }
}

/// Sockel der Lampe
struct BulbBase: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(9, 19.5))
        p.addLine(to: pt(15, 19.5))
        p.addLine(to: pt(15, 21))
        p.addRelativeArc(center: pt(14, 21), radius: 1, startAngle: .degrees(0), delta: .degrees(90))
        p.addLine(to: pt(10, 22))
        p.addRelativeArc(center: pt(10, 21), radius: 1, startAngle: .degrees(90), delta: .degrees(90))
        p.closeSubpath()
        return fit(p, in: rect)
    }
}
