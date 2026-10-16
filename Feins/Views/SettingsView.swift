import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Query private var dishes: [Dish]
    @AppStorage(SettingsKeys.appearance) private var appearance: Appearance = .system

    var body: some View {
        NavigationStack {
            Form {
                Section("Darstellung") {
                    Picker("Erscheinungsbild", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.appearance")
                }

                Section {
                    ForEach(MealSlot.allCases) { slot in
                        ReminderRow(slot: slot, dishNames: dishes.map(\.name))
                    }
                } header: {
                    Text("Erinnerungen")
                } footer: {
                    Text("Feins erinnert dich zur gewählten Zeit und schlägt eines deiner Gerichte vor.")
                }

                Section {
                    HStack {
                        Text("Apple Intelligence")
                        Spacer()
                        Label(model.aiStatus.title, systemImage: model.aiStatus.systemImage)
                            .foregroundStyle(model.aiStatus == .ready ? Theme.accent : Theme.muted)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.ai")
                } header: {
                    Text("KI auf dem iPhone")
                } footer: {
                    Text(model.aiStatus.explanation)
                }

                Section("Über Feins") {
                    LabeledContent("Version", value: Bundle.main.versionString)
                    LabeledContent("Gespeicherte Gerichte", value: "\(dishes.count)")
                }
            }
            .scrollContentBackground(.hidden)
            .feinsScreenBackground()
            .navigationTitle("Einstellungen")
            .onAppear { model.refreshAIStatus() }
        }
    }
}

private struct ReminderRow: View {
    let slot: MealSlot
    let dishNames: [String]
    @AppStorage private var enabled: Bool
    @AppStorage private var minutes: Int

    init(slot: MealSlot, dishNames: [String]) {
        self.slot = slot
        self.dishNames = dishNames
        _enabled = AppStorage(wrappedValue: false, SettingsKeys.reminderEnabled(slot))
        _minutes = AppStorage(wrappedValue: slot.defaultMinutes, SettingsKeys.reminderMinutes(slot))
    }

    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }

    var body: some View {
        Toggle(slot.title, isOn: $enabled)
            .accessibilityIdentifier("settings.reminder.\(slot.rawValue)")
            .onChange(of: enabled) { _, isOn in
                Task {
                    if isOn, !(await ReminderScheduler.requestAuthorization()) {
                        enabled = false
                    }
                    await ReminderSettings.reschedule(dishNames: dishNames)
                }
            }
        if enabled {
            DatePicker("Uhrzeit", selection: time, displayedComponents: .hourAndMinute)
                .onChange(of: minutes) { _, _ in
                    Task { await ReminderSettings.reschedule(dishNames: dishNames) }
                }
        }
    }
}

extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}
