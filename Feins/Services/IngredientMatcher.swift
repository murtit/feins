import Foundation

/// Vergleicht Zutaten tolerant: Gross-/Kleinschreibung, Umlaute und einfache deutsche Pluralformen
/// ("Tomaten" ↔ "Tomate", "Zwiebeln" ↔ "Zwiebel", "Rüebli" ↔ "Ruebli") spielen keine Rolle.
enum IngredientMatcher {
    static func normalize(_ value: String) -> String {
        var key = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_CH"))
            .replacingOccurrences(of: "ß", with: "ss")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        // Mengenangaben vorne entfernen ("200 g Spaghetti" -> "spaghetti").
        let units: Set<String> = ["g", "kg", "ml", "dl", "l", "el", "tl", "stk", "stück", "stuck", "prise", "bund", "dose", "dosen", "pck", "becher", "zehe", "zehen", "scheiben"]
        var words = key.split(separator: " ").map(String.init)
        while let first = words.first, words.count > 1,
              first.first?.isNumber == true || units.contains(first) || first == "½" || first == "¼" {
            words.removeFirst()
        }
        key = words.joined(separator: " ")
        return key
    }

    static func stem(_ value: String) -> String {
        var word = normalize(value)
        for suffix in ["en", "n", "e", "s"] where word.count > 4 && word.hasSuffix(suffix) {
            word.removeLast(suffix.count)
            break
        }
        return word
    }

    /// `true`, wenn die gewünschte Zutat in einer der Zutaten des Gerichts vorkommt.
    static func dish(_ dishIngredients: [String], contains wanted: String) -> Bool {
        let wantedStem = stem(wanted)
        guard !wantedStem.isEmpty else { return true }
        return dishIngredients.contains { ingredient in
            let normalized = normalize(ingredient)
            if normalized.contains(wantedStem) { return true }
            return normalized
                .split(whereSeparator: { !$0.isLetter })
                .contains { stem(String($0)) == wantedStem }
        }
    }

    /// `true`, wenn das Gericht alle gewünschten Zutaten verwendet.
    static func dish(_ dishIngredients: [String], containsAll wanted: [String]) -> Bool {
        wanted.allSatisfy { dish(dishIngredients, contains: $0) }
    }
}
