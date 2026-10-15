import Foundation
import Observation
import SwiftData

enum AppTab: String, Hashable {
    case dishes
    case chooser
    case settings
}

enum SettingsKeys {
    static let appearance = "appearance"
    static let chooserSource = "chooserSource"
    static func reminderEnabled(_ slot: MealSlot) -> String { "reminder.\(slot.rawValue).enabled" }
    static func reminderMinutes(_ slot: MealSlot) -> String { "reminder.\(slot.rawValue).minutes" }
}

/// Zentraler App-Zustand: Datenbank, KI-Assistent und laufende Anreicherungen.
@MainActor
@Observable
final class AppModel {
    let launch: LaunchOptions
    let container: ModelContainer
    var selectedTab: AppTab
    private(set) var apiKey: String?
    private(set) var enriching: Set<UUID> = []
    var lastError: String?

    @ObservationIgnored private let keyStore = APIKeyStore()

    init(launch: LaunchOptions) {
        self.launch = launch
        selectedTab = launch.initialTab ?? .dishes
        let configuration = ModelConfiguration(isStoredInMemoryOnly: launch.isUITesting)
        do {
            container = try ModelContainer(for: Dish.self, configurations: configuration)
        } catch {
            fatalError("SwiftData-Container konnte nicht erstellt werden: \(error)")
        }
        apiKey = launch.isUITesting ? nil : keyStore.load()
        if launch.seedSampleData {
            SampleData.insert(into: container.mainContext)
        }
    }

    var hasAPIKey: Bool { apiKey != nil }

    var assistant: any DishAssistant {
        SmartDishAssistant(primary: apiKey.map { ClaudeDishAssistant(apiKey: $0) })
    }

    func updateAPIKey(_ key: String) {
        keyStore.save(key)
        apiKey = keyStore.load()
    }

    /// Speichert die Eingabe sofort und verfeinert sie danach im Hintergrund.
    @discardableResult
    func addDish(from rawInput: String, in context: ModelContext) -> Dish? {
        let tidy = LocalDishAssistant.tidy(rawInput)
        guard !tidy.isEmpty else { return nil }
        let dish = Dish(rawInput: rawInput, name: tidy, category: LocalDishAssistant.guessCategory(for: tidy))
        context.insert(dish)
        try? context.save()
        enrich(dish, in: context)
        return dish
    }

    func enrich(_ dish: Dish, in context: ModelContext) {
        let id = dish.id
        let input = dish.rawInput
        enriching.insert(id)
        let assistant = assistant
        Task {
            defer { enriching.remove(id) }
            do {
                let draft = try await assistant.enrich(input)
                dish.apply(draft)
                try? context.save()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func save(_ idea: DishIdea, in context: ModelContext) -> Dish {
        let dish = Dish(rawInput: idea.name, name: idea.name, category: idea.category)
        dish.apply(idea.asDraft)
        context.insert(dish)
        try? context.save()
        return dish
    }
}
