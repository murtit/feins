import Foundation
import FoundationModels

/// Nutzt Apples Sprachmodell direkt auf dem iPhone (Apple Intelligence): gratis, ohne Schlüssel, offline.
/// Nichts verlässt das Gerät.
struct OnDeviceDishAssistant: DishAssistant {
    static let instructions = """
    Du bist der Küchenassistent der iOS-App "Feins" ("Was gits feins?"). Die Person lebt in der Schweiz \
    und schreibt Deutsch oder Schweizerdeutsch. Antworte immer auf Hochdeutsch mit Schweizer Schreibweise \
    (ss statt ß) und Schweizer Begriffen, wo sie üblich sind (Rüebli, Peperoni, Rahm, Poulet). \
    Rezepte sind alltagstauglich und für 2 Personen. Zutaten immer mit Mengen, Schritte kurz und klar.
    """

    func enrich(_ rawInput: String) async throws -> DishDraft {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw DishAssistantError.emptyInput }
        let prompt = """
        Ich habe mir dieses Gericht notiert (getippt oder eingesprochen, kann Tipp- oder Erkennungsfehler enthalten): \
        "\(input)"
        Finde heraus, welches Gericht gemeint ist, schreib den Namen korrekt, ordne es einer Kategorie zu \
        und ergänze ein Rezept.
        """
        return try await generate(prompt)
    }

    func inventIdea(ingredients: [String], avoiding: [String]) async throws -> DishDraft {
        var prompt = "Schlag mir ein feines Gericht vor, das ich heute kochen könnte, mit Rezept."
        if !ingredients.isEmpty {
            prompt += "\nEs soll diese Zutaten verwenden: \(ingredients.joined(separator: ", "))."
        }
        if !avoiding.isEmpty {
            prompt += "\nNicht eines dieser Gerichte: \(avoiding.prefix(40).joined(separator: ", "))."
        }
        return try await generate(prompt)
    }

    private func generate(_ prompt: String) async throws -> DishDraft {
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(to: prompt, generating: GeneratedDish.self)
        return response.content.draft
    }
}

/// Was das Modell zurückgeben muss. Die Struktur wird beim Generieren erzwungen, es gibt kein JSON zu parsen.
@Generable
struct GeneratedDish {
    @Guide(description: "Der korrekt geschriebene, gebräuchliche Name des Gerichts, ohne Emoji.")
    var name: String
    @Guide(description: "Die passendste Kategorie.")
    var category: GeneratedCategory
    @Guide(description: "Ein appetitlicher Satz, höchstens 120 Zeichen.")
    var summary: String
    @Guide(description: "Zutaten mit Mengen, z.B. \"200 g Spaghetti\".", .count(3...14))
    var ingredients: [String]
    @Guide(description: "Kurze, klare Arbeitsschritte.", .count(2...10))
    var steps: [String]
    @Guide(description: "Anzahl Portionen.", .range(1...8))
    var servings: Int
    @Guide(description: "Gesamtdauer in Minuten.", .range(5...240))
    var durationMinutes: Int
    init(name: String, category: GeneratedCategory, summary: String, ingredients: [String],
         steps: [String], servings: Int, durationMinutes: Int) {
        self.name = name
        self.category = category
        self.summary = summary
        self.ingredients = ingredients
        self.steps = steps
        self.servings = servings
        self.durationMinutes = durationMinutes
    }
}

@Generable
enum GeneratedCategory: CaseIterable {
    case pasta, fleisch, fisch, vegetarisch, suppe, salat, asiatisch, ofen, dessert, snack
}

extension GeneratedCategory {
    var dishCategory: DishCategory { DishCategory.parse(String(describing: self)) }
}

extension GeneratedDish {
    /// Aufgeräumt in das App-eigene Format übertragen.
    var draft: DishDraft {
        let clean: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return DishDraft(
            name: clean(name),
            category: category.dishCategory,
            summary: clean(summary),
            ingredients: ingredients.map(clean).filter { !$0.isEmpty },
            steps: steps.map(clean).filter { !$0.isEmpty },
            servings: min(max(servings, 1), 12),
            durationMinutes: min(max(durationMinutes, 1), 600)
        )
    }
}

/// Ob die KI auf diesem iPhone gerade nutzbar ist, und was man sonst tun kann.
enum OnDeviceAIStatus: String, Equatable {
    case ready
    case notEnabled
    case notReady
    case unsupported

    static var current: OnDeviceAIStatus {
        switch SystemLanguageModel.default.availability {
        case .available: .ready
        case .unavailable(.appleIntelligenceNotEnabled): .notEnabled
        case .unavailable(.modelNotReady): .notReady
        default: .unsupported
        }
    }

    var title: String {
        switch self {
        case .ready: "Aktiv"
        case .notEnabled: "Ausgeschaltet"
        case .notReady: "Wird geladen"
        case .unsupported: "Nicht verfügbar"
        }
    }

    var systemImage: String {
        switch self {
        case .ready: "checkmark.seal.fill"
        case .notEnabled: "power"
        case .notReady: "arrow.down.circle"
        case .unsupported: "iphone.slash"
        }
    }

    var explanation: String {
        let offline = "Bis dahin erkennt Feins rund 30 bekannte Gerichte auch mit Tippfehlern und ergänzt deren Rezepte."
        return switch self {
        case .ready:
            "Feins korrigiert deine Eingaben, ordnet sie ein, schreibt Rezepte und erfindet neue Ideen mit Apple Intelligence direkt auf dem iPhone. Gratis, ohne Konto, und nichts verlässt dein Gerät."
        case .notEnabled:
            "Schalte Apple Intelligence in den iPhone-Einstellungen unter „Apple Intelligence & Siri“ ein, dann schreibt Feins Rezepte selbst. \(offline)"
        case .notReady:
            "Das iPhone lädt das Sprachmodell herunter. Das dauert ein paar Minuten bis einige Stunden und läuft nur im WLAN, am Strom und mit rund 7 GB freiem Speicher. Bewegt sich nichts, prüf unter „Apple Intelligence & Siri“, ob Siri dieselbe Sprache hat wie das iPhone. Feins merkt automatisch, wenn es fertig ist. \(offline)"
        case .unsupported:
            "Dieses iPhone unterstützt Apple Intelligence nicht (ab iPhone 15 Pro). Feins erkennt trotzdem rund 30 bekannte Gerichte auch mit Tippfehlern und ergänzt deren Rezepte."
        }
    }

    /// Die drei Voraussetzungen der Reihe nach: unterstützt, eingeschaltet, geladen.
    var checks: [AICheck] {
        let enabledState: AICheck.State = switch self {
        case .unsupported: .skipped
        case .notEnabled: .failed
        case .notReady, .ready: .done
        }
        let loadedState: AICheck.State = switch self {
        case .unsupported, .notEnabled: .skipped
        case .notReady: .inProgress
        case .ready: .done
        }
        let supported = AICheck(id: "supported", title: "iPhone unterstützt Apple Intelligence", state: self == .unsupported ? .failed : .done)
        let enabled = AICheck(id: "enabled", title: "Apple Intelligence eingeschaltet", state: enabledState)
        let loaded = AICheck(id: "loaded", title: "Sprachmodell geladen", state: loadedState)
        return [supported, enabled, loaded]
    }

    /// Nur wenn man in den iPhone-Einstellungen etwas tun oder nachsehen kann.
    var canFixInSettings: Bool { self == .notEnabled || self == .notReady }

    /// Solange sich der Zustand von selbst ändern kann, schaut Feins regelmässig nach.
    var mayChange: Bool { self == .notEnabled || self == .notReady }
}

struct AICheck: Identifiable, Equatable {
    enum State: Equatable {
        case done, failed, inProgress, skipped
    }

    let id: String
    let title: String
    let state: State
}
