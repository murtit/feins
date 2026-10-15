import Foundation
import SwiftData
import Testing
@testable import Feins

@Suite("Modell und Erinnerungen")
@MainActor
struct MiscTests {
    @Test("Ein Gericht übernimmt das Rezept aus dem Entwurf")
    func dishAppliesDraft() throws {
        let container = try ModelContainer(for: Dish.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let dish = Dish(rawInput: "spagetti", name: "Spagetti", category: .vegetarisch)
        container.mainContext.insert(dish)
        #expect(!dish.isEnriched)

        dish.apply(DishDraft(name: "Spaghetti Carbonara", category: .pasta, summary: "Cremig.", ingredients: ["Spaghetti"], steps: ["Kochen"]))
        #expect(dish.name == "Spaghetti Carbonara")
        #expect(dish.category == .pasta)
        #expect(dish.isEnriched)
        #expect(dish.asIdea.isMine)
    }

    @Test("Hinzufügen speichert sofort und verfeinert danach")
    func addDishEnrichesInBackground() async throws {
        let model = AppModel(launch: LaunchOptions(isUITesting: true))
        let context = model.container.mainContext
        let dish = try #require(model.addDish(from: "älplermakronen", in: context))
        #expect(dish.name == "Älplermakronen")
        #expect(model.enriching.contains(dish.id))

        for _ in 0..<50 where model.enriching.contains(dish.id) {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(dish.name == "Älplermagronen")
        #expect(dish.isEnriched)
        #expect(try context.fetchCount(FetchDescriptor<Dish>()) == 1)
    }

    @Test("Leere Eingaben werden nicht gespeichert")
    func ignoresEmptyInput() {
        let model = AppModel(launch: LaunchOptions(isUITesting: true))
        #expect(model.addDish(from: "   ", in: model.container.mainContext) == nil)
    }

    @Test("Erinnerungstext nennt ein eigenes Gericht")
    func reminderContent() {
        let withDish = ReminderScheduler.content(for: .dinner, suggestion: "Shakshuka")
        #expect(withDish.title == "Was gits feins?")
        #expect(withDish.body == "Wie wär's zum Abendessen mit Shakshuka?")
        let without = ReminderScheduler.content(for: .lunch, suggestion: nil)
        #expect(without.body.contains("Mittagessen"))
    }

    @Test("Erinnerungs-Einstellungen werden korrekt gelesen")
    func reminderSettings() throws {
        let defaults = try #require(UserDefaults(suiteName: "feins.tests.\(UUID().uuidString)"))
        defaults.set(true, forKey: SettingsKeys.reminderEnabled(.lunch))
        defaults.set(12 * 60, forKey: SettingsKeys.reminderMinutes(.lunch))
        let schedule = ReminderSettings.schedule(defaults: defaults)
        #expect(schedule[.lunch] == .some(720))
        #expect(schedule[.dinner] == .some(nil))
    }
}
