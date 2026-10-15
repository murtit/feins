import Testing
@testable import Feins

@Suite("Zutaten-Vergleich")
struct IngredientMatcherTests {
    @Test("Mengenangaben werden ignoriert")
    func stripsQuantities() {
        #expect(IngredientMatcher.normalize("200 g Spaghetti") == "spaghetti")
        #expect(IngredientMatcher.normalize("1 Dose Tomaten") == "tomaten")
        #expect(IngredientMatcher.normalize("2 EL Currypaste") == "currypaste")
    }

    @Test("Einzahl und Mehrzahl passen zusammen", arguments: [
        ("Tomate", "1 Dose Tomaten"),
        ("Tomaten", "3 Tomaten"),
        ("Zwiebeln", "1 Zwiebel"),
        ("Rüebli", "1 Rüebli"),
        ("ruebli", "1 Rüebli"),
        ("Kürbis", "800 g Kürbis"),
        ("Eier", "2 Eier"),
    ])
    func matchesPlurals(wanted: String, ingredient: String) {
        #expect(IngredientMatcher.dish([ingredient], contains: wanted))
    }

    @Test("Fremde Zutaten passen nicht")
    func rejectsUnrelated() {
        #expect(!IngredientMatcher.dish(["200 g Spaghetti", "2 Eier"], contains: "Lachs"))
    }

    @Test("Alle gewünschten Zutaten müssen vorkommen")
    func requiresAll() {
        let ingredients = ["4 Eier", "1 Dose Tomaten", "1 Peperoni"]
        #expect(IngredientMatcher.dish(ingredients, containsAll: ["Eier", "Tomaten"]))
        #expect(!IngredientMatcher.dish(ingredients, containsAll: ["Eier", "Reis"]))
        #expect(IngredientMatcher.dish(ingredients, containsAll: []))
    }
}
