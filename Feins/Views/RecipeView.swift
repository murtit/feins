import SwiftUI

/// Darstellung eines Rezepts, gemeinsam genutzt von eigenen Gerichten und neuen Ideen.
struct RecipeView<Footer: View>: View {
    let name: String
    let category: DishCategory
    let summary: String
    let ingredients: [String]
    let steps: [String]
    let servings: Int
    let durationMinutes: Int
    var isEnriching = false
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if isEnriching {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Feins schreibt gerade das Rezept …")
                            .foregroundStyle(Theme.muted)
                    }
                    .feinsCard()
                } else if ingredients.isEmpty && steps.isEmpty {
                    Text("Noch kein Rezept vorhanden. Hinterlege in den Einstellungen einen Claude API-Schlüssel, dann ergänzt Feins Rezepte automatisch.")
                        .foregroundStyle(Theme.muted)
                        .feinsCard()
                } else {
                    ingredientsCard
                    stepsCard
                }
                footer()
            }
            .padding()
        }
        .feinsScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            CategoryChip(category: category)
            Text(name)
                .font(.feinsTitle())
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("recipe.name")
            if !summary.isEmpty {
                Text(summary)
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
            }
            if !ingredients.isEmpty {
                HStack(spacing: 16) {
                    Label("\(durationMinutes) Min.", systemImage: "clock")
                    Label("\(servings) \(servings == 1 ? "Person" : "Personen")", systemImage: "person.2")
                }
                .font(.feinsLabel(.subheadline))
                .foregroundStyle(Theme.ink.opacity(0.75))
            }
        }
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zutaten")
                .font(.feinsTitle(.title3))
            ForEach(Array(ingredients.enumerated()), id: \.offset) { _, ingredient in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                    Text(ingredient)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .feinsCard()
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Zubereitung")
                .font(.feinsTitle(.title3))
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.feinsLabel(.subheadline))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 20, alignment: .leading)
                    Text(step)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .feinsCard()
    }
}

struct DishDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var dish: Dish

    var body: some View {
        RecipeView(
            name: dish.name,
            category: dish.category,
            summary: dish.summary,
            ingredients: dish.ingredients,
            steps: dish.steps,
            servings: dish.servings,
            durationMinutes: dish.durationMinutes,
            isEnriching: model.enriching.contains(dish.id)
        ) {
            if dish.rawInput.caseInsensitiveCompare(dish.name) != .orderedSame {
                Text("Notiert als „\(dish.rawInput)“")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        model.enrich(dish, in: context)
                    } label: {
                        Label("Rezept neu schreiben", systemImage: "sparkles")
                    }
                    Picker("Kategorie", selection: $dish.categoryRaw) {
                        ForEach(DishCategory.allCases) { category in
                            Text("\(category.emoji) \(category.title)").tag(category.rawValue)
                        }
                    }
                    Button(role: .destructive) {
                        // Erst zurück navigieren, dann löschen, damit die Ansicht kein gelöschtes Objekt mehr anzeigt.
                        let dish = dish
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            context.delete(dish)
                            try? context.save()
                        }
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Mehr")
            }
        }
    }
}

struct IdeaDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    let idea: DishIdea
    @State private var saved = false

    var body: some View {
        RecipeView(
            name: idea.name,
            category: idea.category,
            summary: idea.summary,
            ingredients: idea.ingredients,
            steps: idea.steps,
            servings: idea.servings,
            durationMinutes: idea.durationMinutes
        ) {
            Button {
                _ = model.save(idea, in: context)
                withAnimation(.snappy) { saved = true }
            } label: {
                Label(saved ? "Gespeichert" : "Zu meinen Gerichten", systemImage: saved ? "checkmark" : "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(saved)
            .accessibilityIdentifier("idea.save")
        }
    }
}
