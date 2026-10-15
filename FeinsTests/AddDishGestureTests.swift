import CoreGraphics
import Testing
@testable import Feins

@Suite("Runder Hinzufügen-Knopf")
struct AddDishGestureTests {
    @Test("Kurzes Antippen öffnet das Eintippen")
    func tapMeansTyping() {
        #expect(AddDishGesture.intent(translation: .zero, predictedEnd: .zero) == .type)
        #expect(AddDishGesture.intent(translation: CGSize(width: 5, height: -6), predictedEnd: CGSize(width: 5, height: -6)) == .type)
    }

    @Test("Nach oben ziehen startet das Einsprechen", arguments: [70.0, 120.0, 300.0])
    func dragUpMeansSpeaking(distance: Double) {
        let up = CGSize(width: 0, height: -distance)
        #expect(AddDishGesture.intent(translation: up, predictedEnd: up) == .speak)
    }

    @Test("Ein schneller Wisch zählt auch, wenn der Finger früh loslässt")
    func flickUpMeansSpeaking() {
        let intent = AddDishGesture.intent(translation: CGSize(width: 0, height: -30), predictedEnd: CGSize(width: 0, height: -140))
        #expect(intent == .speak)
    }

    @Test("Halbherziges Ziehen oder Wischen zur Seite tut nichts", arguments: [
        CGSize(width: 0, height: -40),
        CGSize(width: 60, height: 0),
        CGSize(width: 0, height: 50),
    ])
    func otherDragsDoNothing(translation: CGSize) {
        #expect(AddDishGesture.intent(translation: translation, predictedEnd: translation) == .none)
    }

    @Test("Fortschritt läuft von 0 bis 1")
    func progressIsClamped() {
        #expect(AddDishGesture.progress(translation: 20) == 0)
        #expect(AddDishGesture.progress(translation: -35) == 0.5)
        #expect(AddDishGesture.progress(translation: -500) == 1)
    }
}
