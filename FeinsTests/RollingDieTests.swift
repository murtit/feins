import CoreGraphics
import Testing
@testable import Feins

@Suite("3D-Würfel")
struct RollingDieTests {
    @Test("Jede Zahl hat genau so viele Augen", arguments: 1...6)
    func pipCount(value: Int) {
        let pips = DiePips.positions(for: value)
        #expect(pips.count == value)
        #expect(pips.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        #expect(Set(pips.map { "\($0.x),\($0.y)" }).count == value, "Augen dürfen sich nicht überlagern")
    }

    @Test("Sichtbare Seiten sind echte Nachbarn", arguments: 1...6)
    func facesAreAdjacent(top: Int) {
        let faces = DieFaces.showing(top)
        let visible = [faces.top, faces.left, faces.right]
        #expect(Set(visible).count == 3)
        for a in visible {
            for b in visible where a != b {
                #expect(a + b != 7, "Gegenüberliegende Seiten \(a) und \(b) sind nie gleichzeitig sichtbar")
            }
        }
    }

    @Test("Ungültige Werte werden auf 1…6 begrenzt")
    func clampsValues() {
        #expect(DieFaces.showing(0).top == 1)
        #expect(DieFaces.showing(9).top == 6)
    }

    @Test("Die Seiten setzen sich zu einem Sechseck ohne Lücke zusammen")
    func geometryMeetsAtCenter() {
        let center = CGPoint(x: 100, y: 100)
        let geometry = DieGeometry(center: center, edge: 50)
        let corner = CGPoint(x: 1, y: 1)
        // Die untere rechte Ecke der Oberseite ist die Würfelmitte, ebenso eine Ecke der Seitenflächen.
        let topCorner = CGPoint(x: 0, y: 1).applying(geometry.top)
        let leftCorner = CGPoint(x: 1, y: 0).applying(geometry.left)
        let rightCorner = CGPoint(x: 0, y: 0).applying(geometry.right)
        for point in [topCorner, leftCorner, rightCorner] {
            #expect(abs(point.x - center.x) < 0.001 && abs(point.y - center.y) < 0.001)
        }
        // Die Seitenflächen reichen bis zur unteren Spitze.
        let bottom = corner.applying(geometry.left)
        #expect(abs(bottom.y - 150) < 0.001)
    }
}
