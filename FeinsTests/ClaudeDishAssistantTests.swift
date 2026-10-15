import Foundation
import Testing
@testable import Feins

@Suite("Claude API", .serialized)
struct ClaudeDishAssistantTests {
    @Test("Request enthält Modell, Header und JSON-Schema")
    func buildsRequest() throws {
        let request = try ClaudeDishAssistant(apiKey: "sk-test").makeRequest(prompt: "Hallo")
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")

        let data = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["model"] as? String == "claude-opus-5-5")
        let output = try #require(body["output_config"] as? [String: Any])
        let format = try #require(output["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let schema = try #require(format["schema"] as? [String: Any])
        #expect(schema["additionalProperties"] as? Bool == false)
        let required = try #require(schema["required"] as? [String])
        #expect(Set(required) == ["name", "category", "summary", "ingredients", "steps", "servings", "duration_minutes"])
    }

    @Test("Gültige Antwort wird in ein Gericht übersetzt")
    func parsesResponse() throws {
        let draft = try ClaudeDishAssistant.parse(Self.response(text: Self.sampleJSON))
        #expect(draft.name == "Älplermagronen")
        #expect(draft.category == .pasta)
        #expect(draft.ingredients.count == 3)
        #expect(draft.isRecipeComplete)
    }

    @Test("Ablehnungen und abgeschnittene Antworten werden erkannt")
    func detectsRefusalAndTruncation() {
        #expect(throws: ClaudeDishAssistant.ClaudeError.refused) {
            try ClaudeDishAssistant.parse(Self.response(text: "", stopReason: "refusal"))
        }
        #expect(throws: ClaudeDishAssistant.ClaudeError.truncated) {
            try ClaudeDishAssistant.parse(Self.response(text: "{", stopReason: "max_tokens"))
        }
        #expect(throws: ClaudeDishAssistant.ClaudeError.invalidResponse) {
            try ClaudeDishAssistant.parse(Self.response(text: "kein json"))
        }
    }

    @Test("Netzwerkaufruf mit gestubbter Antwort")
    func sendsAndParses() async throws {
        let assistant = ClaudeDishAssistant(apiKey: "sk-test", session: StubURLProtocol.session(status: 200, body: Self.response(text: Self.sampleJSON)))
        let draft = try await assistant.enrich("älplermakaronen")
        #expect(draft.name == "Älplermagronen")
    }

    @Test("HTTP-Fehler werden mit Meldung weitergegeben")
    func surfacesHTTPErrors() async {
        let body = Data(#"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#.utf8)
        let assistant = ClaudeDishAssistant(apiKey: "falsch", session: StubURLProtocol.session(status: 401, body: body))
        await #expect(throws: ClaudeDishAssistant.ClaudeError.http(status: 401, message: "invalid x-api-key")) {
            try await assistant.enrich("pizza")
        }
    }

    @Test("Bei Fehlern fällt Feins auf den Offline-Assistenten zurück")
    func smartAssistantFallsBack() async throws {
        let failing = ClaudeDishAssistant(apiKey: "falsch", session: StubURLProtocol.session(status: 500, body: Data("{}".utf8)))
        let draft = try await SmartDishAssistant(primary: failing).enrich("spagetti carbonara")
        #expect(draft.name == "Spaghetti Carbonara")
    }

    /// Echter Aufruf, läuft nur wenn `ANTHROPIC_API_KEY` gesetzt ist (in CI über das Secret).
    @Test("Live: echte Claude API", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.isEmpty == false))
    func live() async throws {
        let key = try #require(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"])
        let draft = try await ClaudeDishAssistant(apiKey: key).enrich("älplermakaronen mit apfelmuss")
        #expect(!draft.name.isEmpty)
        #expect(draft.isRecipeComplete)
    }

    // MARK: - Hilfen

    static let sampleJSON = #"{"name":"Älplermagronen","category":"pasta","summary":"Hörnli, Kartoffeln und Käse.","ingredients":["300 g Hörnli","300 g Kartoffeln","150 g Bergkäse"],"steps":["Kochen","Mischen"],"servings":2,"duration_minutes":35}"#

    static func response(text: String, stopReason: String = "end_turn") -> Data {
        let payload: [String: Any] = [
            "id": "msg_test",
            "type": "message",
            "role": "assistant",
            "model": "claude-opus-5-5",
            "stop_reason": stopReason,
            "content": [
                ["type": "thinking", "thinking": ""],
                ["type": "text", "text": text],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }
}

/// Liefert vorbereitete Antworten statt echter Netzwerkaufrufe.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()

    static func session(status: Int, body: Data) -> URLSession {
        Self.status = status
        Self.body = body
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: ["content-type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
