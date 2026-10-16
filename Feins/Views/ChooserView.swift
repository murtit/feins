import SwiftData
import SwiftUI

/// "Was gits feins?" – der Random Chooser.
struct ChooserView: View {
    @Environment(AppModel.self) private var model
    @Query private var dishes: [Dish]
    @AppStorage(SettingsKeys.chooserSource) private var source: ChooserSource = .mine
    @State private var ingredients: [String] = []
    @State private var ingredientDraft = ""
    @State private var result: DishIdea?
    @State private var shown: Set<String> = []
    @State private var isThinking = false
    @State private var emptyMessage: String?
    @State private var rolls = 0
    @State private var isRolling = false
    @State private var faces = DieFaces.showing(5)
    @State private var seeded = SeededGenerator(seed: 42)

    private let chooser = DishChooser()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dieStage
                    surpriseButton
                    if let result {
                        ResultCard(idea: result, onAgain: { Task { await surprise() } })
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                            .id(result.id)
                    } else if let emptyMessage {
                        Text(emptyMessage)
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .feinsCard()
                            .accessibilityIdentifier("chooser.empty")
                    }
                    optionsCard
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .feinsScreenBackground()
            .navigationTitle("Was gits feins?")
            .navigationDestination(for: DishIdea.self) { idea in
                if case .mine(let id) = idea.source, let dish = dishes.first(where: { $0.id == id }) {
                    DishDetailView(dish: dish)
                } else {
                    IdeaDetailView(idea: idea)
                }
            }
        }
    }

    /// Der grosse Würfel: antippen würfelt genauso wie der Knopf.
    private var dieStage: some View {
        VStack(spacing: 4) {
            Button {
                Task { await surprise() }
            } label: {
                RollingDie(faces: faces, rolls: rolls)
            }
            .buttonStyle(.plain)
            .disabled(isRolling)
            .accessibilityLabel("Würfeln")
            .accessibilityValue("Zeigt \(faces.top)")
            .accessibilityIdentifier("chooser.die")
            Text(result == nil ? "Tipp auf den Würfel oder den Knopf." : " ")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    /// Optionen sind zweitrangig: wer nichts einstellt, bekommt eine völlige Überraschung.
    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optional")
                .font(.feinsLabel())
                .foregroundStyle(Theme.muted)
                .textCase(.uppercase)
            sourcePicker
            ingredientsCard
        }
    }

    private var sourcePicker: some View {
        Picker("Vorschläge aus", selection: $source) {
            ForEach(ChooserSource.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("chooser.source")
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kochen mit …")
                .font(.feinsTitle(.title3))
            HStack {
                TextField("Zutat, z.B. Tomaten", text: $ingredientDraft)
                    .submitLabel(.done)
                    .onSubmit(addIngredient)
                    .accessibilityIdentifier("chooser.ingredientField")
                Button(action: addIngredient) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(ingredientDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Zutat hinzufügen")
                .accessibilityIdentifier("chooser.addIngredient")
            }
            if !ingredients.isEmpty {
                FlowLayout {
                    ForEach(ingredients, id: \.self) { ingredient in
                        Button {
                            withAnimation(.snappy) { ingredients.removeAll { $0 == ingredient } }
                        } label: {
                            HStack(spacing: 4) {
                                Text(ingredient)
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                            }
                            .font(.feinsLabel(.subheadline))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(Theme.ink)
                            .background(Theme.accent.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(ingredient) entfernen")
                    }
                }
            } else {
                Text("Leer lassen für völlige Überraschung.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
        .feinsCard()
    }

    private var surpriseButton: some View {
        Button {
            Task { await surprise() }
        } label: {
            HStack(spacing: 10) {
                if isThinking {
                    ProgressView()
                        .tint(.white)
                }
                Text(result == nil ? "Überrasch mich" : "Nochmal würfeln")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(isRolling)
        .accessibilityIdentifier("chooser.surprise")
    }

    private func addIngredient() {
        let value = ingredientDraft.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        withAnimation(.snappy) {
            if !ingredients.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                ingredients.append(value)
            }
            ingredientDraft = ""
        }
    }

    private func surprise() async {
        guard !isRolling else { return }
        isRolling = true
        defer { isRolling = false }
        let started = Date.now
        rolls += 1
        emptyMessage = nil
        let shuffle = Task { await shuffleFaces() }
        let mine = dishes.map(\.asIdea)
        let request = ChooserRequest(source: source, ingredients: ingredients, excluding: shown)
        var pick: DishIdea?

        // Mit Apple Intelligence kommen bei "Auch neue Ideen" ab und zu ganz frische Vorschläge.
        let hasLocalCandidates = !chooser.candidates(from: mine, for: request).isEmpty
        if source == .everything, model.usesOnDeviceAI, !hasLocalCandidates || Int.random(in: 0..<3) == 0 {
            isThinking = true
            let avoiding = mine.map(\.name) + (result.map { [$0.name] } ?? [])
            if let draft = try? await model.assistant.inventIdea(ingredients: ingredients, avoiding: avoiding) {
                pick = DishIdea(draft: draft, source: .ai)
            }
            isThinking = false
        }
        if pick == nil {
            pick = model.launch.isUITesting
                ? chooser.pick(from: mine, for: request, using: &seeded)
                : chooser.pick(from: mine, for: request)
        }

        // Erst wenn der Würfel liegt, kommt das Ergebnis.
        let remaining = RollingDie.rollDuration - Date.now.timeIntervalSince(started)
        if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
        shuffle.cancel()
        faces = DieFaces.showing(Int.random(in: 1...6))

        withAnimation(.spring(duration: 0.45, bounce: 0.35)) {
            result = pick
            if let pick {
                shown.insert(pick.id)
            } else {
                emptyMessage = emptyText(mineIsEmpty: mine.isEmpty)
            }
        }
    }

    /// Während des Flugs wechseln die Augen, damit es nach echtem Würfeln aussieht.
    private func shuffleFaces() async {
        var generator = SystemRandomNumberGenerator()
        while !Task.isCancelled {
            faces = DieFaces.random(using: &generator)
            try? await Task.sleep(for: .milliseconds(90))
        }
    }

    private func emptyText(mineIsEmpty: Bool) -> String {
        if !ingredients.isEmpty {
            return "Mit diesen Zutaten habe ich nichts gefunden. Entferne eine Zutat oder wähle „\(ChooserSource.everything.title)“."
        }
        if mineIsEmpty, source == .mine {
            return "Du hast noch keine Gerichte gespeichert. Füge eines hinzu oder wähle „\(ChooserSource.everything.title)“."
        }
        return "Gerade ist mir nichts eingefallen."
    }
}

private struct ResultCard: View {
    let idea: DishIdea
    var onAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(idea.category.emoji)
                    .font(.system(size: 44))
                Spacer()
                Text(idea.isMine ? "Aus deinen Gerichten" : "Neue Idee")
                    .font(.feinsLabel())
                    .foregroundStyle(idea.isMine ? Theme.ink.opacity(0.7) : Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((idea.isMine ? Theme.ink : Theme.accent).opacity(0.1), in: Capsule())
            }
            Text(idea.name)
                .font(.feinsTitle(.title))
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("chooser.result.name")
            if !idea.summary.isEmpty {
                Text(idea.summary)
                    .foregroundStyle(Theme.muted)
            }
            HStack(spacing: 14) {
                CategoryChip(category: idea.category)
                if !idea.ingredients.isEmpty {
                    Label("\(idea.durationMinutes) Min.", systemImage: "clock")
                        .font(.feinsLabel())
                        .foregroundStyle(Theme.muted)
                }
            }
            NavigationLink(value: idea) {
                Label("Rezept ansehen", systemImage: "book")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .accessibilityIdentifier("chooser.result.open")
        }
        .feinsCard()
    }
}
