import Foundation
import Testing
@testable import Feins

@Suite("Random Chooser")
struct DishChooserTests {
    let mine: [DishIdea] = [
        idea("Älplermagronen", ["Hörnli", "Kartoffeln", "Käse"]),
        idea("Tomatenrisotto", ["Risottoreis", "Tomaten", "Parmesan"]),
        idea("Shakshuka", ["Eier", "Tomaten", "Peperoni"]),
    ]
    let catalog: [DishIdea] = [
        idea("Linsen-Dal", ["rote Linsen", "Kokosmilch", "Tomaten"], source: .catalog),
        idea("Shakshuka", ["Eier", "Tomaten"], source: .catalog),
        idea("Ramen", ["Nudeln", "Eier"], source: .catalog),
    ]

    var chooser: DishChooser { DishChooser(catalog: catalog) }

    @Test("Nur meine: schlägt ausschliesslich eigene Gerichte vor")
    func onlyMine() {
        let candidates = chooser.candidates(from: mine, for: ChooserRequest(source: .mine))
        #expect(candidates.map(\.name) == ["Älplermagronen", "Tomatenrisotto", "Shakshuka"])
        let allMine = candidates.allSatisfy { $0.isMine }
        #expect(allMine)
    }

    @Test("Auch neue Ideen: ergänzt den Katalog ohne Duplikate")
    func everythingAddsCatalogWithoutDuplicates() {
        let names = chooser.candidates(from: mine, for: ChooserRequest(source: .everything)).map(\.name)
        #expect(names.count == 5)
        #expect(names.filter { $0 == "Shakshuka" }.count == 1)
        #expect(names.contains("Linsen-Dal"))
        #expect(names.contains("Ramen"))
    }

    @Test("Zutatenfilter liefert nur passende Gerichte")
    func filtersByIngredients() {
        let request = ChooserRequest(source: .everything, ingredients: ["Tomate", "Eier"])
        let names = chooser.candidates(from: mine, for: request).map(\.name)
        #expect(names == ["Shakshuka"])
    }

    @Test("Ohne Treffer gibt es keinen Vorschlag")
    func noMatchGivesNil() {
        var generator = SeededGenerator(seed: 1)
        let request = ChooserRequest(source: .mine, ingredients: ["Lachs"])
        #expect(chooser.pick(from: mine, for: request, using: &generator) == nil)
    }

    @Test("Bereits gezeigte Gerichte werden vermieden")
    func avoidsRepeats() {
        var generator = SeededGenerator(seed: 7)
        let shown = Set(mine.prefix(2).map(\.id))
        for _ in 0..<20 {
            let pick = chooser.pick(from: mine, for: ChooserRequest(source: .mine, excluding: shown), using: &generator)
            #expect(pick?.name == "Shakshuka")
        }
    }

    @Test("Sind alle schon gezeigt worden, geht es wieder von vorne los")
    func restartsWhenAllShown() {
        var generator = SeededGenerator(seed: 3)
        let request = ChooserRequest(source: .mine, excluding: Set(mine.map(\.id)))
        #expect(chooser.pick(from: mine, for: request, using: &generator) != nil)
    }

    @Test("Mit gleichem Seed ist die Auswahl reproduzierbar")
    func deterministicWithSeed() {
        var first = SeededGenerator(seed: 99)
        var second = SeededGenerator(seed: 99)
        let request = ChooserRequest(source: .everything)
        for _ in 0..<10 {
            #expect(chooser.pick(from: mine, for: request, using: &first) == chooser.pick(from: mine, for: request, using: &second))
        }
    }

    @Test("Der eingebaute Katalog ist vollständig")
    func catalogIsComplete() {
        #expect(SuggestionCatalog.ideas.count >= 25)
        for idea in SuggestionCatalog.ideas {
            #expect(!idea.ingredients.isEmpty, "\(idea.name) ohne Zutaten")
            #expect(!idea.steps.isEmpty, "\(idea.name) ohne Schritte")
        }
        #expect(Set(SuggestionCatalog.ideas.map(\.name)).count == SuggestionCatalog.ideas.count)
    }

}

private func idea(_ name: String, _ ingredients: [String], source: DishIdea.Source? = nil) -> DishIdea {
    DishIdea(
        name: name,
        category: .vegetarisch,
        summary: "",
        ingredients: ingredients,
        steps: ["Kochen"],
        servings: 2,
        durationMinutes: 20,
        source: source ?? .mine(UUID())
    )
}
