import Foundation
import SwiftData

/// Beispielgerichte für UI-Tests, Screenshots und die SwiftUI-Vorschau.
enum SampleData {
    static let names = ["Älplermagronen", "Poulet-Curry", "Shakshuka", "Kürbissuppe", "Spaghetti Carbonara"]

    @MainActor
    static func insert(into context: ModelContext) {
        let ideas = SuggestionCatalog.ideas
        for (offset, name) in names.enumerated() {
            guard let idea = ideas.first(where: { $0.name == name }) else { continue }
            let dish = Dish(
                rawInput: name.lowercased(),
                name: name,
                category: idea.category,
                createdAt: Date(timeIntervalSince1970: 1_790_000_000 - Double(offset) * 86_400)
            )
            dish.apply(idea.asDraft)
            context.insert(dish)
        }
        try? context.save()
    }
}
