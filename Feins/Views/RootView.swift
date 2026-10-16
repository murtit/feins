import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Query private var dishes: [Dish]

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab("Gerichte", systemImage: "book.closed", value: AppTab.dishes) {
                DishListView()
            }
            Tab("Was gits feins?", systemImage: "dice", value: AppTab.chooser) {
                ChooserView()
            }
            Tab("Einstellungen", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppDelegate.openChooser)) { _ in
            model.selectedTab = .chooser
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            model.refreshAIStatus()
            guard !model.launch.isUITesting else { return }
            Task { await ReminderSettings.reschedule(dishNames: dishes.map(\.name)) }
        }
    }
}

/// Liest die Erinnerungs-Einstellungen aus den UserDefaults und plant sie neu.
enum ReminderSettings {
    static func schedule(defaults: UserDefaults = .standard) -> [MealSlot: Int?] {
        var result: [MealSlot: Int?] = [:]
        for slot in MealSlot.allCases {
            let enabled = defaults.bool(forKey: SettingsKeys.reminderEnabled(slot))
            let stored = defaults.object(forKey: SettingsKeys.reminderMinutes(slot)) as? Int
            result[slot] = enabled ? (stored ?? slot.defaultMinutes) : nil
        }
        return result
    }

    static func reschedule(dishNames: [String]) async {
        await ReminderScheduler.reschedule(schedule(), dishNames: dishNames)
    }
}
