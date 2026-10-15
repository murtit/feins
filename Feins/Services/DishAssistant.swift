import Foundation

/// Korrigiert, kategorisiert und ergänzt Gerichte mit einem Rezept, und erfindet auf Wunsch neue Ideen.
protocol DishAssistant: Sendable {
    /// Aus einer (evtl. fehlerhaften) Eingabe ein sauberes Gericht mit Rezept machen.
    func enrich(_ rawInput: String) async throws -> DishDraft
    /// Eine neue Gerichtsidee vorschlagen, optional mit bestimmten Zutaten.
    func inventIdea(ingredients: [String], avoiding: [String]) async throws -> DishDraft
}

/// Nutzt Claude, wenn ein API-Schlüssel hinterlegt ist, und fällt sonst (oder bei Fehlern) auf die lokale Logik zurück.
struct SmartDishAssistant: DishAssistant {
    var primary: (any DishAssistant)?
    var fallback: any DishAssistant = LocalDishAssistant()

    func enrich(_ rawInput: String) async throws -> DishDraft {
        if let primary {
            do { return try await primary.enrich(rawInput) } catch is CancellationError { throw CancellationError() } catch {
                AppLog.assistant.error("Claude-Anreicherung fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            }
        }
        return try await fallback.enrich(rawInput)
    }

    func inventIdea(ingredients: [String], avoiding: [String]) async throws -> DishDraft {
        if let primary {
            do { return try await primary.inventIdea(ingredients: ingredients, avoiding: avoiding) } catch is CancellationError { throw CancellationError() } catch {
                AppLog.assistant.error("Claude-Idee fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            }
        }
        return try await fallback.inventIdea(ingredients: ingredients, avoiding: avoiding)
    }
}
