import SwiftUI

/// Die drei sichtbaren Seiten eines Würfels in isometrischer Ansicht.
struct DieFaces: Equatable {
    var top: Int
    var left: Int
    var right: Int

    /// Gültige Nachbarseiten für jede obere Zahl (Gegenseiten ergeben 7 und sind nie gleichzeitig sichtbar).
    private static let neighbours: [Int: (Int, Int)] = [
        1: (2, 3), 2: (1, 3), 3: (1, 2), 4: (1, 5), 5: (1, 3), 6: (2, 3),
    ]

    static func showing(_ top: Int) -> DieFaces {
        let value = min(max(top, 1), 6)
        let (left, right) = neighbours[value]!
        return DieFaces(top: value, left: left, right: right)
    }

    static func random<G: RandomNumberGenerator>(using generator: inout G) -> DieFaces {
        showing(Int.random(in: 1...6, using: &generator))
    }
}

/// Wo die Augen auf einer Seite liegen, in Einheitskoordinaten (0…1).
enum DiePips {
    static func positions(for value: Int) -> [CGPoint] {
        let lo = 0.25, mid = 0.5, hi = 0.75
        let center = CGPoint(x: mid, y: mid)
        let diagonal = [CGPoint(x: lo, y: lo), CGPoint(x: hi, y: hi)]
        let antiDiagonal = [CGPoint(x: hi, y: lo), CGPoint(x: lo, y: hi)]
        switch value {
        case 1: return [center]
        case 2: return diagonal
        case 3: return diagonal + [center]
        case 4: return diagonal + antiDiagonal
        case 5: return diagonal + antiDiagonal + [center]
        case 6: return diagonal + antiDiagonal + [CGPoint(x: lo, y: mid), CGPoint(x: hi, y: mid)]
        default: return []
        }
    }
}

/// Ein gezeichneter Würfel: drei Seiten, abgerundete Kanten, Augen perspektivisch verzerrt.
struct DieShape: View {
    var faces: DieFaces
    var size: CGFloat = 120

    var body: some View {
        Canvas { context, canvasSize in
            let geometry = DieGeometry(center: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2), edge: size * 0.5)
            draw(face: geometry.top, value: faces.top, shade: 0, in: &context)
            draw(face: geometry.left, value: faces.left, shade: 0.07, in: &context)
            draw(face: geometry.right, value: faces.right, shade: 0.16, in: &context)
        }
        .frame(width: size, height: size * 1.05)
        .accessibilityHidden(true)
    }

    private func draw(face: CGAffineTransform, value: Int, shade: Double, in context: inout GraphicsContext) {
        let tile = Path(roundedRect: CGRect(x: 0.03, y: 0.03, width: 0.94, height: 0.94), cornerRadius: 0.16)
            .applying(face)
        context.fill(tile, with: .color(Theme.card))
        if shade > 0 {
            context.fill(tile, with: .color(.black.opacity(shade)))
        }
        context.stroke(tile, with: .color(Theme.ink.opacity(0.12)), lineWidth: 1)

        let pipColor = value == 1 ? Theme.accent : Theme.ink
        let radius = value == 1 ? 0.12 : 0.085
        for point in DiePips.positions(for: value) {
            let dot = Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
                .applying(face)
            context.fill(dot, with: .color(pipColor))
        }
    }
}

/// Isometrische Lage der drei Seiten: jede Seite ist ein Einheitsquadrat, das per affiner Abbildung verzerrt wird.
struct DieGeometry {
    let top: CGAffineTransform
    let left: CGAffineTransform
    let right: CGAffineTransform

    init(center: CGPoint, edge: CGFloat) {
        let dx = edge * cos(.pi / 6)
        let dy = edge * 0.5
        let apex = CGPoint(x: center.x, y: center.y - edge)
        let leftTop = CGPoint(x: center.x - dx, y: center.y - dy)
        let rightTop = CGPoint(x: center.x + dx, y: center.y - dy)
        let leftBottom = CGPoint(x: center.x - dx, y: center.y + dy)
        let bottom = CGPoint(x: center.x, y: center.y + edge)

        top = Self.map(origin: leftTop, u: apex, v: center)
        left = Self.map(origin: leftTop, u: center, v: leftBottom)
        right = Self.map(origin: center, u: rightTop, v: bottom)
    }

    /// Bildet (0,0) auf `origin`, (1,0) auf `u` und (0,1) auf `v` ab.
    static func map(origin: CGPoint, u: CGPoint, v: CGPoint) -> CGAffineTransform {
        CGAffineTransform(a: u.x - origin.x, b: u.y - origin.y,
                          c: v.x - origin.x, d: v.y - origin.y,
                          tx: origin.x, ty: origin.y)
    }
}

/// Bewegung beim Würfeln: hochspringen, überschlagen, aufkommen.
struct DieMotion {
    var lift: CGFloat = 0
    var spin: Double = 0
    var tumble: Double = 0
    var squash: CGFloat = 1
}

/// Der Würfel mit Schatten. Jede Änderung von `rolls` löst einen Wurf aus.
struct RollingDie: View {
    var faces: DieFaces
    var rolls: Int
    var size: CGFloat = 120
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let rollDuration: Double = 0.95

    var body: some View {
        KeyframeAnimator(initialValue: DieMotion(), trigger: reduceMotion ? 0 : rolls) { motion in
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(Theme.ink.opacity(0.14))
                    .frame(width: size * 0.8, height: size * 0.16)
                    .scaleEffect(1 - min(-motion.lift, 120) / 240)
                    .blur(radius: 6)
                    .offset(y: size * 0.06)
                DieShape(faces: faces, size: size)
                    .rotation3DEffect(.degrees(motion.tumble), axis: (x: 1, y: 0.35, z: 0), perspective: 0.45)
                    .rotationEffect(.degrees(motion.spin))
                    .scaleEffect(x: 2 - motion.squash, y: motion.squash, anchor: .bottom)
                    .offset(y: motion.lift)
            }
            .frame(height: size * 1.05 + 70, alignment: .bottom)
        } keyframes: { _ in
            KeyframeTrack(\.lift) {
                CubicKeyframe(-110, duration: 0.38)
                CubicKeyframe(0, duration: 0.3)
                SpringKeyframe(-16, duration: 0.12)
                SpringKeyframe(0, duration: 0.15)
            }
            KeyframeTrack(\.spin) {
                CubicKeyframe(300, duration: 0.68)
                SpringKeyframe(360, duration: 0.27, spring: .bouncy)
            }
            KeyframeTrack(\.tumble) {
                LinearKeyframe(360, duration: 0.68)
                LinearKeyframe(360, duration: 0.27)
            }
            KeyframeTrack(\.squash) {
                LinearKeyframe(1, duration: 0.66)
                CubicKeyframe(0.86, duration: 0.06)
                SpringKeyframe(1, duration: 0.23, spring: .bouncy)
            }
        }
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: rolls)
    }
}

#Preview {
    RollingDie(faces: .showing(5), rolls: 0)
        .padding()
        .feinsScreenBackground()
}
