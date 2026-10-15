import Foundation
import SwiftData

/// Ein gespeichertes Gericht.
@Model
final class Dish {
    @Attribute(.unique) var id: UUID
    /// Was ursprünglich getippt oder eingesprochen wurde.
    var rawInput: String
    var name: String
    var categoryRaw: String
    var summary: String
    var ingredients: [String]
    var steps: [String]
    var servings: Int
    var durationMinutes: Int
    var createdAt: Date
    /// `true`, sobald das Gericht korrigiert und mit Rezept ergänzt wurde.
    var isEnriched: Bool
    var lastSuggestedAt: Date?

    init(
        id: UUID = UUID(),
        rawInput: String,
        name: String,
        category: DishCategory,
        summary: String = "",
        ingredients: [String] = [],
        steps: [String] = [],
        servings: Int = 2,
        durationMinutes: Int = 30,
        createdAt: Date = .now,
        isEnriched: Bool = false
    ) {
        self.id = id
        self.rawInput = rawInput
        self.name = name
        self.categoryRaw = category.rawValue
        self.summary = summary
        self.ingredients = ingredients
        self.steps = steps
        self.servings = servings
        self.durationMinutes = durationMinutes
        self.createdAt = createdAt
        self.isEnriched = isEnriched
    }

    var category: DishCategory {
        get { DishCategory(rawValue: categoryRaw) ?? .vegetarisch }
        set { categoryRaw = newValue.rawValue }
    }

    func apply(_ draft: DishDraft) {
        name = draft.name
        category = draft.category
        summary = draft.summary
        ingredients = draft.ingredients
        steps = draft.steps
        servings = draft.servings
        durationMinutes = draft.durationMinutes
        isEnriched = draft.isRecipeComplete
    }

    var asIdea: DishIdea {
        DishIdea(
            name: name,
            category: category,
            summary: summary,
            ingredients: ingredients,
            steps: steps,
            servings: servings,
            durationMinutes: durationMinutes,
            source: .mine(id)
        )
    }
}
