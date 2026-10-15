import Foundation
import UserNotifications

/// Mittag- und Abend-Erinnerung: "Was gits feins? Wie wär's mit …"
enum MealSlot: String, CaseIterable, Identifiable, Sendable {
    case lunch
    case dinner

    var id: String { rawValue }
    var identifier: String { "feins.reminder.\(rawValue)" }

    var title: String {
        switch self {
        case .lunch: "Mittagessen"
        case .dinner: "Abendessen"
        }
    }

    /// Standardzeit in Minuten nach Mitternacht.
    var defaultMinutes: Int {
        switch self {
        case .lunch: 11 * 60 + 15
        case .dinner: 17 * 60 + 30
        }
    }
}

enum ReminderScheduler {
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Text der Erinnerung, mit einem zufälligen eigenen Gericht, falls vorhanden.
    static func content(for slot: MealSlot, suggestion: String?) -> (title: String, body: String) {
        let title = "Was gits feins?"
        guard let suggestion else {
            return (title, "Zeit fürs \(slot.title). Lass dich vom Random Chooser inspirieren.")
        }
        return (title, "Wie wär's zum \(slot.title) mit \(suggestion)?")
    }

    /// Plant (oder entfernt) die täglichen Erinnerungen neu. `minutes == nil` bedeutet ausgeschaltet.
    static func reschedule(_ schedule: [MealSlot: Int?], dishNames: [String]) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: MealSlot.allCases.map(\.identifier))
        for slot in MealSlot.allCases {
            guard let entry = schedule[slot], let minutes = entry else { continue }
            let text = content(for: slot, suggestion: dishNames.randomElement())
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.sound = .default
            content.userInfo = ["target": "chooser"]

            var components = DateComponents()
            components.hour = minutes / 60
            components.minute = minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            do {
                try await center.add(UNNotificationRequest(identifier: slot.identifier, content: content, trigger: trigger))
            } catch {
                AppLog.reminders.error("Erinnerung konnte nicht geplant werden: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
