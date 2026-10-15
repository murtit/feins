import Foundation

/// Spricht direkt mit der Claude API (Messages API) und lässt sich die Antwort als JSON nach festem Schema geben.
struct ClaudeDishAssistant: DishAssistant {
    static let model = "claude-opus-5-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    enum ClaudeError: LocalizedError, Equatable {
        case http(status: Int, message: String)
        case refused
        case truncated
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .http(let status, let message): "Claude API Fehler \(status): \(message)"
            case .refused: "Claude hat die Anfrage abgelehnt."
            case .truncated: "Die Antwort von Claude war unvollständig."
            case .invalidResponse: "Die Antwort von Claude konnte nicht gelesen werden."
            }
        }
    }

    var apiKey: String
    var session: URLSession = .shared

    func enrich(_ rawInput: String) async throws -> DishDraft {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw DishAssistantError.emptyInput }
        let prompt = """
        Ich habe mir dieses Gericht notiert (getippt oder per Spracheingabe, kann Tipp- oder Erkennungsfehler enthalten):

        <eingabe>\(input)</eingabe>

        Finde heraus, welches Gericht gemeint ist, und gib es korrekt geschrieben zurück, ordne es einer Kategorie zu \
        und ergänze ein alltagstaugliches Rezept für 2 Personen.
        """
        return try await send(prompt)
    }

    func inventIdea(ingredients: [String], avoiding: [String]) async throws -> DishDraft {
        var prompt = "Schlag mir ein feines Gericht vor, das ich heute kochen könnte, mit Rezept für 2 Personen."
        if !ingredients.isEmpty {
            prompt += "\nEs soll diese Zutaten verwenden: \(ingredients.joined(separator: ", "))."
        }
        if !avoiding.isEmpty {
            prompt += "\nBitte nicht eines dieser Gerichte: \(avoiding.prefix(60).joined(separator: ", "))."
        }
        return try await send(prompt)
    }

    // MARK: - Request

    static let systemPrompt = """
    Du bist der Küchenassistent der iOS-App "Feins" ("Was gits feins?"). Die Nutzerin oder der Nutzer lebt in der Schweiz \
    und schreibt Deutsch oder Schweizerdeutsch. Antworte immer auf Hochdeutsch mit Schweizer Schreibweise (ss statt ß) \
    und Schweizer Begriffen, wo sie üblich sind (Rüebli, Peperoni, Rahm, Poulet).
    - name: der korrekt geschriebene, gebräuchliche Name des Gerichts, ohne Emoji.
    - category: genau eine der erlaubten Kategorien.
    - summary: ein appetitlicher Satz, höchstens 120 Zeichen.
    - ingredients: Zutaten mit Mengen, z.B. "200 g Spaghetti".
    - steps: kurze, klare Arbeitsschritte.
    - servings und duration_minutes: realistische Werte.
    """

    static func requestBody(prompt: String) -> [String: Any] {
        [
            "model": model,
            "max_tokens": 16000,
            "fallbacks": "default",
            "system": systemPrompt,
            "output_config": [
                "effort": "low",
                "format": [
                    "type": "json_schema",
                    "schema": draftSchema,
                ],
            ],
            "messages": [
                ["role": "user", "content": prompt],
            ],
        ]
    }

    static let draftSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "name": ["type": "string"],
            "category": ["type": "string", "enum": DishCategory.allCases.map(\.rawValue)],
            "summary": ["type": "string"],
            "ingredients": ["type": "array", "items": ["type": "string"]],
            "steps": ["type": "array", "items": ["type": "string"]],
            "servings": ["type": "integer"],
            "duration_minutes": ["type": "integer"],
        ],
        "required": ["name", "category", "summary", "ingredients", "steps", "servings", "duration_minutes"],
        "additionalProperties": false,
    ]

    func makeRequest(prompt: String) throws -> URLRequest {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.requestBody(prompt: prompt))
        return request
    }

    private func send(_ prompt: String) async throws -> DishDraft {
        let (data, response) = try await session.data(for: makeRequest(prompt: prompt))
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw ClaudeError.http(status: http.statusCode, message: apiError?.error.message ?? "Unbekannter Fehler")
        }
        return try Self.parse(data)
    }

    // MARK: - Response

    struct MessageResponse: Decodable {
        struct Block: Decodable {
            var type: String
            var text: String?
        }

        var content: [Block]
        var stopReason: String?

        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }

    struct APIErrorEnvelope: Decodable {
        struct Detail: Decodable { var message: String }
        var error: Detail
    }

    static func parse(_ data: Data) throws -> DishDraft {
        let message = try JSONDecoder().decode(MessageResponse.self, from: data)
        switch message.stopReason ?? "" {
        case "refusal": throw ClaudeError.refused
        case "max_tokens": throw ClaudeError.truncated
        default: break
        }
        guard let text = message.content.last(where: { $0.type == "text" })?.text,
              let json = text.data(using: .utf8) else {
            throw ClaudeError.invalidResponse
        }
        do {
            var draft = try JSONDecoder().decode(DishDraft.self, from: json)
            draft.categoryRaw = draft.category.rawValue
            draft.servings = max(1, draft.servings)
            draft.durationMinutes = max(1, draft.durationMinutes)
            return draft
        } catch {
            throw ClaudeError.invalidResponse
        }
    }
}
