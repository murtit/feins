import SwiftData
import SwiftUI

struct DishListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Dish.createdAt, order: .reverse) private var dishes: [Dish]
    @State private var draft = ""
    @State private var search = ""

    private var filtered: [Dish] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return dishes }
        return dishes.filter { dish in
            dish.name.localizedCaseInsensitiveContains(query)
                || dish.category.title.localizedCaseInsensitiveContains(query)
                || IngredientMatcher.dish(dish.ingredients, contains: query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if dishes.isEmpty {
                    EmptyDishesView()
                } else {
                    list
                }
            }
            .feinsScreenBackground()
            .navigationTitle("Meine Gerichte")
            .navigationDestination(for: Dish.self) { DishDetailView(dish: $0) }
            .safeAreaInset(edge: .bottom) {
                AddDishButton(text: $draft, speech: model.speech, onSubmit: submit)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .onChange(of: model.speech.transcript) { _, transcript in
                if !transcript.isEmpty { draft = transcript }
            }
            .onChange(of: model.speech.isListening) { wasListening, isListening in
                // Nach dem Einsprechen direkt speichern: so wenig Tippen wie möglich.
                if wasListening, !isListening, !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                    submit()
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(filtered) { dish in
                NavigationLink(value: dish) {
                    DishRow(dish: dish, isEnriching: model.enriching.contains(dish.id))
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Theme.ink.opacity(0.08))
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $search, prompt: "Gericht, Kategorie oder Zutat")
        .accessibilityIdentifier("dishList")
    }

    private func submit() {
        let input = draft
        draft = ""
        withAnimation(.snappy) {
            _ = model.addDish(from: input, in: context)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filtered[index])
        }
        try? context.save()
    }
}

struct DishRow: View {
    let dish: Dish
    var isEnriching = false

    var body: some View {
        HStack(spacing: 14) {
            Text(dish.category.emoji)
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(Theme.ink.opacity(0.06), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(dish.name)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Theme.ink)
                if isEnriching {
                    Label("Wird verfeinert …", systemImage: "sparkles")
                        .font(.feinsLabel())
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.pulse)
                } else {
                    Text(dish.summary.isEmpty ? dish.category.title : dish.summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if dish.isEnriched {
                Text("\(dish.durationMinutes)′")
                    .font(.feinsLabel())
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dish.\(dish.name)")
    }
}

struct EmptyDishesView: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            SmileyMark(size: 120)
            Text("Was gits feins?")
                .font(.feinsTitle(.title))
                .foregroundStyle(Theme.ink)
            Text("Dir ist ein Gericht eingefallen? Tipp auf den Kreis unten rechts oder zieh ihn nach oben und sprich es ein. Feins korrigiert es, sortiert es ein und schreibt das Rezept dazu.")
                .font(.body)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("emptyState")
    }
}
