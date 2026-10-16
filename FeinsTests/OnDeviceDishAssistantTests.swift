import Foundation
import Testing
@testable import Feins

@Suite("KI auf dem iPhone")
struct OnDeviceDishAssistantTests {
    @Test("Jede KI-Kategorie landet in der passenden App-Kategorie")
    func categoriesMatch() {
        #expect(GeneratedCategory.allCases.count == DishCategory.allCases.count)
        for category in GeneratedCategory.allCases {
            #expect(category.dishCategory.rawValue == String(describing: category))
        }
    }

    @Test("Antwort wird aufgeräumt und in sinnvolle Grenzen gebracht")
    func draftIsTidied() {
        let generated = GeneratedDish(
            name: "  Älplermagronen ",
            category: .pasta,
            summary: "Hörnli, Kartoffeln und Käse, dazu Apfelmus.\n",
            ingredients: ["200 g Hörnli", " ", "150 g Bergkäse"],
            steps: ["Kochen.", ""],
            servings: 0,
            durationMinutes: 900
        )
        let draft = generated.draft
        #expect(draft.name == "Älplermagronen")
        #expect(draft.category == .pasta)
        #expect(draft.summary == "Hörnli, Kartoffeln und Käse, dazu Apfelmus.")
        #expect(draft.ingredients == ["200 g Hörnli", "150 g Bergkäse"])
        #expect(draft.steps == ["Kochen."])
        #expect(draft.servings == 1)
        #expect(draft.durationMinutes == 600)
    }

    @Test("Jeder Status erklärt, was Feins gerade kann", arguments: [
        OnDeviceAIStatus.ready, .notEnabled, .notReady, .unsupported,
    ])
    func statusTexts(status: OnDeviceAIStatus) {
        #expect(!status.title.isEmpty)
        #expect(!status.explanation.isEmpty)
        #expect(OnDeviceAIStatus(rawValue: status.rawValue) == status)
    }

    @Test("Die drei Prüfschritte zeigen, wo es hängt", arguments: [
        (OnDeviceAIStatus.unsupported, [AICheck.State.failed, .skipped, .skipped]),
        (.notEnabled, [.done, .failed, .skipped]),
        (.notReady, [.done, .done, .inProgress]),
        (.ready, [.done, .done, .done]),
    ])
    func checks(status: OnDeviceAIStatus, expected: [AICheck.State]) {
        #expect(status.checks.map(\.state) == expected)
    }

    @Test("Knopf zu den Einstellungen nur, wenn man dort etwas tun kann")
    func settingsButton() {
        #expect(OnDeviceAIStatus.notEnabled.canFixInSettings)
        #expect(OnDeviceAIStatus.notReady.canFixInSettings)
        #expect(!OnDeviceAIStatus.ready.canFixInSettings)
        #expect(!OnDeviceAIStatus.unsupported.canFixInSettings)
    }

    @Test("Ohne Schlüssel und ohne Konto: Feins fragt nie nach einem API-Schlüssel")
    @MainActor
    func noKeyNeeded() {
        let model = AppModel(launch: LaunchOptions(isUITesting: true, forcedAIStatus: .ready))
        #expect(model.aiStatus == .ready)
        // Im UI-Test bleibt Feins beim berechenbaren Offline-Modus.
        #expect(!model.usesOnDeviceAI)
    }

    @Test("Bei Fehlern fällt Feins auf den Offline-Assistenten zurück")
    func smartAssistantFallsBack() async throws {
        let draft = try await SmartDishAssistant(primary: FailingAssistant()).enrich("spagetti carbonara")
        #expect(draft.name == "Spaghetti Carbonara")
        let idea = try await SmartDishAssistant(primary: FailingAssistant()).inventIdea(ingredients: [], avoiding: [])
        #expect(!idea.name.isEmpty)
    }

    @Test("Leere Eingabe wird abgelehnt, bevor das Modell rechnet")
    func emptyInputIsRejected() async {
        await #expect(throws: DishAssistantError.emptyInput) {
            try await OnDeviceDishAssistant().enrich("   ")
        }
    }

    /// Echter Aufruf, wie ihn die App macht: Das Modell auf dem Gerät antwortet, oder Feins fällt auf offline zurück.
    /// Auf CI-Runnern meldet der Simulator das Modell manchmal als verfügbar, obwohl es nicht rechnen kann.
    @Test("Live: Modell auf dem Gerät oder Rückfall liefert immer ein Rezept", .enabled(if: OnDeviceAIStatus.current == .ready))
    func live() async throws {
        let draft = try await SmartDishAssistant(primary: OnDeviceDishAssistant()).enrich("älplermakronen")
        #expect(!draft.name.isEmpty)
        #expect(draft.isRecipeComplete)
    }
}

private struct FailingAssistant: DishAssistant {
    struct Failure: Error {}
    func enrich(_ rawInput: String) async throws -> DishDraft { throw Failure() }
    func inventIdea(ingredients: [String], avoiding: [String]) async throws -> DishDraft { throw Failure() }
}
