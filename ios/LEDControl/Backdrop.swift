import SwiftUI

/// Hintergrund aller Seiten: warmes Schwarz mit feinem Lochraster wie bei einer Gerätefront
struct Backdrop: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 18
            let dot: CGFloat = 1.2
            let color = Color.white.opacity(0.045)
            var y = step / 2
            while y < size.height {
                var x = step / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)), with: .color(color))
                    x += step
                }
                y += step
            }
        }
        .background(Theme.bg)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
