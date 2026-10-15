import Foundation

enum DishAssistantError: LocalizedError, Equatable {
    case emptyInput
    case noMatchingIdea

    var errorDescription: String? {
        switch self {
        case .emptyInput: "Bitte gib zuerst ein Gericht ein."
        case .noMatchingIdea: "Zu diesen Zutaten ist mir gerade nichts eingefallen."
        }
    }
}

/// Offline-Variante: räumt die Eingabe auf, erkennt bekannte Gerichte auch mit Tippfehlern
/// und ordnet sie über Schlüsselwörter einer Kategorie zu.
struct LocalDishAssistant: DishAssistant {
    var catalog: [DishIdea] = SuggestionCatalog.ideas

    func enrich(_ rawInput: String) async throws -> DishDraft {
        let cleaned = Self.tidy(rawInput)
        guard !cleaned.isEmpty else { throw DishAssistantError.emptyInput }

        if let known = Self.bestMatch(for: cleaned, in: catalog) {
            return known.asDraft
        }
        return DishDraft(
            name: cleaned,
            category: Self.guessCategory(for: cleaned),
            summary: "",
            ingredients: [],
            steps: []
        )
    }

    func inventIdea(ingredients: [String], avoiding: [String]) async throws -> DishDraft {
        let avoid = Set(avoiding.map(IngredientMatcher.normalize))
        let request = ChooserRequest(source: .everything, ingredients: ingredients)
        let options = DishChooser(catalog: catalog)
            .candidates(from: [], for: request)
            .filter { !avoid.contains(IngredientMatcher.normalize($0.name)) }
        guard let idea = options.randomElement() else { throw DishAssistantError.noMatchingIdea }
        return idea.asDraft
    }

    // MARK: - Aufräumen

    private static let lowercaseWords: Set<String> = ["mit", "und", "an", "im", "in", "auf", "nach", "aus", "vom", "von", "der", "die", "das", "dem", "den", "al", "alla", "all'", "di", "con", "e", "à", "la", "au", "sin"]

    /// Leerzeichen normalisieren und Wörter sinnvoll gross schreiben.
    static func tidy(_ input: String) -> String {
        let words = input
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        return words.enumerated().map { index, word in
            let lower = word.lowercased()
            if index > 0, lowercaseWords.contains(lower) { return lower }
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }
        .joined(separator: " ")
        .trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
    }

    // MARK: - Tippfehler-tolerantes Wiedererkennen

    static func bestMatch(for input: String, in catalog: [DishIdea]) -> DishIdea? {
        let key = IngredientMatcher.normalize(input)
        let scored = catalog.map { idea in
            (idea, similarity(key, IngredientMatcher.normalize(idea.name)))
        }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 >= 0.78 else { return nil }
        return best.0
    }

    static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let longest = max(lhs.count, rhs.count)
        guard longest > 0 else { return 1 }
        return 1 - Double(levenshtein(lhs, rhs)) / Double(longest)
    }

    static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }

    // MARK: - Kategorie raten

    private static let keywords: [(DishCategory, [String])] = [
        (.dessert, ["kuchen", "torte", "mousse", "creme", "glace", "dessert", "muffin", "brownie", "cookie", "chüechli", "chuechli", "tiramisu", "pudding", "wähe", "waehe", "crepe"]),
        (.suppe, ["suppe", "eintopf", "bouillon", "ramen", "pho", "chili", "gulasch", "dal"]),
        (.salat, ["salat", "bowl", "poke"]),
        (.asiatisch, ["curry", "sushi", "wok", "thai", "pad", "teriyaki", "dumpling", "gyoza", "bibimbap", "ramen", "pho", "satay", "tikka"]),
        (.fisch, ["fisch", "lachs", "thon", "thunfisch", "crevetten", "garnelen", "forelle", "zander", "egli", "dorsch", "kabeljau", "muscheln", "calamari"]),
        (.pasta, ["pasta", "spaghetti", "penne", "lasagne", "risotto", "nudel", "hörnli", "hoernli", "magronen", "gnocchi", "ravioli", "tagliatelle", "linguine", "maccheroni", "fusilli"]),
        (.ofen, ["gratin", "auflauf", "pizza", "quiche", "flammkuchen", "raclette", "fondue", "käseschnitte", "überbacken", "ofen"]),
        (.fleisch, ["fleisch", "poulet", "huhn", "hähnchen", "rind", "kalb", "schwein", "lamm", "steak", "schnitzel", "geschnetzeltes", "burger", "wurst", "cervelat", "braten", "hack", "speck", "kebab", "fajita"]),
        (.snack, ["sandwich", "toast", "wrap", "omelette", "brot", "bruschetta", "snack", "dip", "hummus"]),
    ]

    static func guessCategory(for name: String) -> DishCategory {
        let key = name.lowercased()
        for (category, words) in keywords where words.contains(where: { key.contains($0) }) {
            return category
        }
        return .vegetarisch
    }
}
