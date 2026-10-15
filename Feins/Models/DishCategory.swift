import Foundation

/// Feste Kategorien, in die Feins jedes Gericht einordnet.
enum DishCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case pasta
    case fleisch
    case fisch
    case vegetarisch
    case suppe
    case salat
    case asiatisch
    case ofen
    case dessert
    case snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pasta: "Pasta & Risotto"
        case .fleisch: "Fleisch"
        case .fisch: "Fisch & Meer"
        case .vegetarisch: "Vegetarisch"
        case .suppe: "Suppen & Eintöpfe"
        case .salat: "Salate & Bowls"
        case .asiatisch: "Asiatisch"
        case .ofen: "Aus dem Ofen"
        case .dessert: "Süsses"
        case .snack: "Snacks & Kleines"
        }
    }

    var emoji: String {
        switch self {
        case .pasta: "🍝"
        case .fleisch: "🥩"
        case .fisch: "🐟"
        case .vegetarisch: "🥦"
        case .suppe: "🍲"
        case .salat: "🥗"
        case .asiatisch: "🥢"
        case .ofen: "🧀"
        case .dessert: "🍰"
        case .snack: "🥨"
        }
    }

    /// Tolerantes Parsen, damit auch "Suppe", "Fisch & Meer" o.ä. ankommen.
    static func parse(_ raw: String) -> DishCategory {
        let key = fold(raw)
        if let exact = DishCategory(rawValue: key) { return exact }
        return DishCategory.allCases.first { key.hasPrefix($0.rawValue) || fold($0.title) == key } ?? .vegetarisch
    }

    private static func fold(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_CH"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
