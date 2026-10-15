import Testing
@testable import Feins

@Suite("Offline-Assistent")
struct LocalDishAssistantTests {
    let assistant = LocalDishAssistant()

    @Test("Tippfehler bei bekannten Gerichten werden korrigiert", arguments: [
        ("älplermakronen", "Älplermagronen"),
        ("spagetti carbonara", "Spaghetti Carbonara"),
        ("kürbisuppe", "Kürbissuppe"),
        ("shakshuka", "Shakshuka"),
    ])
    func correctsTypos(input: String, expected: String) async throws {
        let draft = try await assistant.enrich(input)
        #expect(draft.name == expected)
        #expect(draft.isRecipeComplete)
    }

    @Test("Unbekannte Gerichte werden aufgeräumt und eingeordnet")
    func tidiesUnknownDishes() async throws {
        let draft = try await assistant.enrich("  grossmamis   poulet mit reis ")
        #expect(draft.name == "Grossmamis Poulet mit Reis")
        #expect(draft.category == .fleisch)
        #expect(!draft.isRecipeComplete)
    }

    @Test("Leere Eingabe wird abgelehnt")
    func rejectsEmptyInput() async {
        await #expect(throws: DishAssistantError.emptyInput) {
            try await assistant.enrich("   ")
        }
    }

    @Test("Kategorien werden über Schlüsselwörter erkannt", arguments: [
        ("Thai Curry", DishCategory.asiatisch),
        ("Lachs vom Grill", .fisch),
        ("Tomatensuppe", .suppe),
        ("Penne Rigate", .pasta),
        ("Zitronenkuchen", .dessert),
        ("Kartoffelgratin", .ofen),
        ("Ofengemüse", .ofen),
        ("Linsen mit Spinat", .vegetarisch),
    ])
    func guessesCategories(name: String, category: DishCategory) {
        #expect(LocalDishAssistant.guessCategory(for: name) == category)
    }

    @Test("Neue Idee berücksichtigt Zutaten und vermeidet bekannte Gerichte")
    func inventsIdeaWithIngredients() async throws {
        let draft = try await assistant.inventIdea(ingredients: ["Kürbis"], avoiding: [])
        #expect(draft.name == "Kürbissuppe")
        await #expect(throws: DishAssistantError.noMatchingIdea) {
            try await assistant.inventIdea(ingredients: ["Kürbis"], avoiding: ["Kürbissuppe"])
        }
    }

    @Test("Levenshtein-Distanz")
    func levenshtein() {
        #expect(LocalDishAssistant.levenshtein("kitten", "sitting") == 3)
        #expect(LocalDishAssistant.levenshtein("", "abc") == 3)
        #expect(LocalDishAssistant.levenshtein("feins", "feins") == 0)
    }

    @Test("Kategorie-Parsing ist tolerant", arguments: [
        ("pasta", DishCategory.pasta),
        ("Suppe", .suppe),
        ("FISCH", .fisch),
        ("Süsses", .dessert),
        ("unbekannt", .vegetarisch),
    ])
    func parsesCategories(raw: String, expected: DishCategory) {
        #expect(DishCategory.parse(raw) == expected)
    }
}
