import Foundation

/// Woher der Random Chooser seine Vorschläge nimmt.
enum ChooserSource: String, CaseIterable, Identifiable, Sendable {
    case mine
    case everything

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mine: "Nur meine"
        case .everything: "Auch neue Ideen"
        }
    }
}

struct ChooserRequest: Equatable, Sendable {
    var source: ChooserSource = .mine
    var ingredients: [String] = []
    var excluding: Set<String> = []
}

/// Reine Auswahl-Logik des Random Choosers, ohne UI und ohne Netzwerk, damit sie gut testbar ist.
struct DishChooser {
    var catalog: [DishIdea] = SuggestionCatalog.ideas

    /// Alle Gerichte, die zur Anfrage passen.
    func candidates(from mine: [DishIdea], for request: ChooserRequest) -> [DishIdea] {
        var pool = mine
        if request.source == .everything {
            let myNames = Set(mine.map { IngredientMatcher.normalize($0.name) })
            pool += catalog.filter { !myNames.contains(IngredientMatcher.normalize($0.name)) }
        }
        let wanted = request.ingredients.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !wanted.isEmpty {
            pool = pool.filter { IngredientMatcher.dish($0.ingredients, containsAll: wanted) }
        }
        return pool
    }

    /// Wählt zufällig ein passendes Gericht. Bereits gezeigte Gerichte werden vermieden, solange es Alternativen gibt.
    func pick<G: RandomNumberGenerator>(
        from mine: [DishIdea],
        for request: ChooserRequest,
        using generator: inout G
    ) -> DishIdea? {
        let all = candidates(from: mine, for: request)
        let fresh = all.filter { !request.excluding.contains($0.id) }
        return (fresh.isEmpty ? all : fresh).randomElement(using: &generator)
    }

    func pick(from mine: [DishIdea], for request: ChooserRequest) -> DishIdea? {
        var generator = SystemRandomNumberGenerator()
        return pick(from: mine, for: request, using: &generator)
    }
}

/// Deterministischer Zufallsgenerator für Tests und UI-Tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
