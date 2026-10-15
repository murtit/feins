import Foundation

/// Ergebnis der Korrektur/Kategorisierung/Rezept-Ergänzung.
struct DishDraft: Codable, Equatable, Sendable {
    var name: String
    var categoryRaw: String
    var summary: String
    var ingredients: [String]
    var steps: [String]
    var servings: Int
    var durationMinutes: Int

    enum CodingKeys: String, CodingKey {
        case name
        case categoryRaw = "category"
        case summary
        case ingredients
        case steps
        case servings
        case durationMinutes = "duration_minutes"
    }

    init(
        name: String,
        category: DishCategory,
        summary: String,
        ingredients: [String],
        steps: [String],
        servings: Int = 2,
        durationMinutes: Int = 30
    ) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.summary = summary
        self.ingredients = ingredients
        self.steps = steps
        self.servings = servings
        self.durationMinutes = durationMinutes
    }

    var category: DishCategory { DishCategory.parse(categoryRaw) }
    var isRecipeComplete: Bool { !ingredients.isEmpty && !steps.isEmpty }
}

/// Ein Vorschlag des Random Choosers, entweder aus den eigenen Gerichten oder eine neue Idee.
struct DishIdea: Identifiable, Hashable, Sendable {
    enum Source: Hashable, Sendable {
        case mine(UUID)
        case catalog
        case ai
    }

    var id: String {
        switch source {
        case .mine(let uuid): uuid.uuidString
        case .catalog, .ai: "idea-\(name)"
        }
    }

    var name: String
    var category: DishCategory
    var summary: String
    var ingredients: [String]
    var steps: [String]
    var servings: Int
    var durationMinutes: Int
    var source: Source

    var isMine: Bool {
        if case .mine = source { return true }
        return false
    }

    init(draft: DishDraft, source: Source) {
        self.init(
            name: draft.name,
            category: draft.category,
            summary: draft.summary,
            ingredients: draft.ingredients,
            steps: draft.steps,
            servings: draft.servings,
            durationMinutes: draft.durationMinutes,
            source: source
        )
    }

    init(
        name: String,
        category: DishCategory,
        summary: String,
        ingredients: [String],
        steps: [String],
        servings: Int,
        durationMinutes: Int,
        source: Source
    ) {
        self.name = name
        self.category = category
        self.summary = summary
        self.ingredients = ingredients
        self.steps = steps
        self.servings = servings
        self.durationMinutes = durationMinutes
        self.source = source
    }

    var asDraft: DishDraft {
        DishDraft(
            name: name,
            category: category,
            summary: summary,
            ingredients: ingredients,
            steps: steps,
            servings: servings,
            durationMinutes: durationMinutes
        )
    }
}
