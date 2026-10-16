import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Query private var dishes: [Dish]
    @AppStorage(SettingsKeys.appearance) private var appearance: Appearance = .system
    @Environment(\.openURL) private var openURL

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
                    ForEach(model.aiStatus.checks) { check in
                        AICheckRow(check: check)
                    }
                    if model.aiStatus.canFixInSettings {
                        Button {
                            openSettings()
                        } label: {
                            Label("iPhone-Einstellungen öffnen", systemImage: "gear")
                        }
                        .accessibilityIdentifier("settings.ai.open")
                    }
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
            .task(id: model.aiStatus) { await watchAIStatus() }
        }
    }

    /// Während Apple Intelligence eingeschaltet wird oder lädt, schaut Feins alle paar Sekunden nach.
    private func watchAIStatus() async {
        while model.aiStatus.mayChange, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            model.refreshAIStatus()
        }
    }

    /// Apple bietet keinen öffentlichen Direktlink zu „Apple Intelligence & Siri“; das ist der nächste erlaubte Einstieg.
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct AICheckRow: View {
    let check: AICheck

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 22)
            Text(check.title)
                .foregroundStyle(check.state == .skipped ? Theme.muted : Theme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(stateText)
        .accessibilityIdentifier("settings.ai.\(check.id)")
    }

    @ViewBuilder private var icon: some View {
        switch check.state {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
        case .failed:
            Image(systemName: "xmark.circle").foregroundStyle(Theme.muted)
        case .inProgress:
            ProgressView()
        case .skipped:
            Image(systemName: "circle.dashed").foregroundStyle(Theme.muted.opacity(0.6))
        }
    }

    private var stateText: String {
        switch check.state {
        case .done: "erfüllt"
        case .failed: "nicht erfüllt"
        case .inProgress: "läuft"
        case .skipped: "noch offen"
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
