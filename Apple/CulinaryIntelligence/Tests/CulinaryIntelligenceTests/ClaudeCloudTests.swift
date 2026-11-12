import Foundation
import FoundationModels
import Testing
@testable import CulinaryIntelligence

@MainActor
@Suite(.serialized)
struct ClaudeCloudTests {
    let cloud = ClaudeCloud(key: { "sk-ant-test-stub" })

    @Test func readsTextDeltasAndSkipsTheRest() throws {
        #expect(try ClaudeCloud.text(inEvent: #" {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Egg"}}"#) == "Egg")
        #expect(try ClaudeCloud.text(inEvent: #"{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":""}}"#) == nil)
        #expect(try ClaudeCloud.text(inEvent: #"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}"#) == nil)
        #expect(try ClaudeCloud.text(inEvent: #"{"type":"ping"}"#) == nil)
        #expect(try ClaudeCloud.text(inEvent: #"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":12}}"#) == nil)
        #expect(try ClaudeCloud.text(inEvent: "not json") == nil)
    }

    @Test func endsOnARefusalOrAnErrorEvent() {
        #expect(throws: ClaudeError.refused) {
            try ClaudeCloud.text(inEvent: #"{"type":"message_delta","delta":{"stop_reason":"refusal"}}"#)
        }
        #expect(throws: ClaudeError.overloaded) {
            try ClaudeCloud.text(inEvent: #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#)
        }
    }

    @Test func mapsFailures() {
        #expect(ClaudeError.from(status: 401, type: "authentication_error", message: "invalid x-api-key") == .badKey)
        #expect(ClaudeError.from(status: 400, type: "invalid_request_error",
                                 message: "Your credit balance is too low to access the Anthropic API.") == .noCredit)
        #expect(ClaudeError.from(status: 402, type: "billing_error", message: nil) == .noCredit)
        #expect(ClaudeError.from(status: 403, type: "permission_error", message: nil) == .notPermitted)
        #expect(ClaudeError.from(status: 404, type: "not_found_error", message: "model: claude-opus-5-5") == .notPermitted)
        #expect(ClaudeError.from(status: 429, type: "rate_limit_error", message: nil) == .rateLimited)
        #expect(ClaudeError.from(status: 529, type: "overloaded_error", message: nil) == .overloaded)
        #expect(ClaudeError.from(status: 400, type: "invalid_request_error", message: "bad") == .server(400, "bad"))
    }

    @Test func sendsNoSamplingOrThinkingSettings() throws {
        let data = ClaudeCloud.body(.write, system: "S", prompt: "P", maximumTokens: 1400)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["model"] as? String == "claude-opus-5-5")
        #expect(body["max_tokens"] as? Int == 1400 + ClaudeCloud.thinkingAllowance)
        #expect(body["system"] as? String == "S")
        #expect(body["stream"] as? Bool == true)
        #expect(body["temperature"] == nil)
        #expect(body["thinking"] == nil)
        #expect((body["output_config"] as? [String: Any])?["effort"] as? String == "medium")
        #expect((body["output_config"] as? [String: Any])?["format"] == nil)
    }

    @Test func endsACutOffAnswer() {
        #expect(throws: CloudError.cutOff) {
            try ClaudeCloud.text(inEvent: #"{"type":"message_delta","delta":{"stop_reason":"max_tokens"}}"#)
        }
    }

    @Test func sendsTheExampleAsAnEarlierExchange() throws {
        let data = ClaudeCloud.body(.write, system: "S", example: (ask: "A", answer: "B"), prompt: "P", maximumTokens: 10)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages.map { $0["role"] ?? "" } == ["user", "assistant", "user"])
        #expect(messages.map { $0["content"] ?? "" } == ["A", "B", "P"])
    }

    @Test func sendsEachRoleToItsModel() throws {
        let models: [(ClaudeRole, String)] = [
            (.write, "claude-opus-5-5"), (.edit, "claude-opus-5-5"), (.draw, "claude-opus-5-5"),
            (.ideas, "claude-sonnet-5-5"), (.plan, "claude-sonnet-5-5"), (.parse, "claude-sonnet-5-5"),
            (.decide, "claude-haiku-5-5"), (.toppings, "claude-haiku-5-5"),
            (.sort, "claude-haiku-5-5"), (.translate, "claude-haiku-5-5"),
        ]
        for (role, model) in models {
            let body = try #require(try JSONSerialization.jsonObject(
                with: ClaudeCloud.body(role, system: "S", prompt: "P", maximumTokens: 10)
            ) as? [String: Any])
            #expect(body["model"] as? String == model)
            #expect((body["output_config"] as? [String: Any])?["effort"] as? String == "medium")
        }
    }

    @Test func holdsAPassToItsSchema() throws {
        let schema = try ModelPasses.jsonSchema(StructuredIngredient.generationSchema)
        #expect(schema["x-order"] == nil)
        #expect(schema["additionalProperties"] as? Bool == false)
        let properties = try #require(schema["properties"] as? [String: Any])
        #expect(Set(properties.keys) == ["item", "section", "icon", "amount", "note"])
        let data = ClaudeCloud.body(.sort, system: "S", prompt: "P", maximumTokens: 10, schema: schema)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let format = try #require((body["output_config"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        #expect((format["schema"] as? [String: Any])?["title"] as? String == "StructuredIngredient")

        let json = #"{"item":"eggs","section":"fresh","icon":"egg","amount":"3","note":""}"#
        let ingredient = try StructuredIngredient(GeneratedContent(json: json))
        #expect(ingredient.item == "eggs" && ingredient.amount == "3")
    }

    @Test func readsTheFirstNumber() {
        #expect(ClaudeCloud.firstNumber(in: "3") == 3)
        #expect(ClaudeCloud.firstNumber(in: "Idea 2.") == 2)
        #expect(ClaudeCloud.firstNumber(in: "0.85") == 0.85)
        #expect(ClaudeCloud.firstNumber(in: "none") == nil)
    }

    // MARK: - Stubbed requests

    @Test func streamsARecordedAnswer() async throws {
        try await withStub(status: 200, body: Self.recordedStream) {
            var text = ""
            for try await piece in cloud.write(instructions: "S", example: nil, prompt: "P", maximumTokens: 100, temperature: 0.7) {
                text += piece
            }
            #expect(text == "Egg Fried Rice\nServes 2")
            #expect(StubProtocol.lastRequest?.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test-stub")
            #expect(StubProtocol.lastRequest?.value(forHTTPHeaderField: "anthropic-version") == "2026-10-21")
        }
    }

    @Test func picksAnIdeaByNumber() async throws {
        try await withStub(status: 200, body: Self.stream(answering: "2")) {
            let pick = try await cloud.decide(
                requestID: "r", request: "dinner", ingredients: ["eggs"], tools: [],
                ideas: [("A", "a"), ("B", "b"), ("C", "c")]
            )
            #expect(pick == CloudPick(index: 1, remaining: nil))
        }
    }

    @Test func answersEveryToppingInOrder() async throws {
        try await withStub(status: 200, body: Self.stream(answering: "0.8")) {
            let answers = try await cloud.toppings(
                dish: "Carbonara", steps: [(title: "Toss", points: ["Toss with pepper."])],
                ingredients: ["pepper", "salt", "parsley", "cheese"]
            )
            #expect(answers == [0.8, 0.8, 0.8, 0.8])
        }
    }

    @Test func reportsABadKey() async throws {
        let failure = #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#
        try await withStub(status: 401, body: failure) {
            await #expect(throws: ClaudeError.badKey) {
                for try await _ in cloud.write(instructions: "S", example: nil, prompt: "P", maximumTokens: 10, temperature: 0.7) {}
            }
        }
    }

    @Test func reportsARateLimit() async throws {
        let failure = #"{"type":"error","error":{"type":"rate_limit_error","message":"Number of request tokens has exceeded your per-minute rate limit"}}"#
        try await withStub(status: 429, body: failure) {
            await #expect(throws: ClaudeError.rateLimited) {
                _ = try await cloud.ideate(instructions: "S", prompt: "P", maximumTokens: 10, temperature: 0.7)
            }
        }
    }

    @Test func reportsAMidStreamRefusal() async throws {
        let refusal = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","content":[],"model":"claude-opus-5-5"}}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"refusal"},"usage":{"output_tokens":0}}

        """
        try await withStub(status: 200, body: refusal) {
            await #expect(throws: ClaudeError.refused) {
                _ = try await cloud.ideate(instructions: "S", prompt: "P", maximumTokens: 10, temperature: 0.7)
            }
        }
    }

    @Test func needsAKey() async throws {
        UserDefaults.standard.set(true, forKey: Plates.allowedKey)
        let keyless = ClaudeCloud(key: { nil })
        #expect(!keyless.isConfigured)
        await #expect(throws: ClaudeError.noKey) {
            _ = try await keyless.ideate(instructions: "S", prompt: "P", maximumTokens: 10, temperature: 0.7)
        }
    }

    @Test func waitsForConsent() async throws {
        UserDefaults.standard.set(false, forKey: Plates.allowedKey)
        defer { UserDefaults.standard.set(true, forKey: Plates.allowedKey) }
        await #expect(throws: CloudError.notAllowed) {
            _ = try await cloud.ideate(instructions: "S", prompt: "P", maximumTokens: 10, temperature: 0.7)
        }
    }

    // MARK: - Helpers

    private static let recordedStream = """
    event: message_start
    data: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","content":[],"model":"claude-opus-5-5","stop_reason":null,"usage":{"input_tokens":20,"output_tokens":1}}}

    event: content_block_start
    data: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}}

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"abc"}}

    event: content_block_stop
    data: {"type":"content_block_stop","index":0}

    event: content_block_start
    data: {"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}

    event: ping
    data: {"type":"ping"}

    event: content_block_delta
    data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Egg Fried Rice\\n"}}

    event: content_block_delta
    data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Serves 2"}}

    event: content_block_stop
    data: {"type":"content_block_stop","index":1}

    event: message_delta
    data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":12}}

    event: message_stop
    data: {"type":"message_stop"}

    """

    private static func stream(answering text: String) -> String {
        """
        event: content_block_delta
        data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"\(text)"}}

        event: message_stop
        data: {"type":"message_stop"}

        """
    }

    private func withStub(status: Int, body: String, _ run: () async throws -> Void) async throws {
        UserDefaults.standard.set(true, forKey: Plates.allowedKey)
        StubProtocol.status = status
        StubProtocol.body = Data(body.utf8)
        URLProtocol.registerClass(StubProtocol.self)
        defer { URLProtocol.unregisterClass(StubProtocol.self) }
        try await run()
    }
}

/// Answers every request to api.anthropic.com with a set status and body, and keeps the last
/// request so its headers can be checked.
private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host() == "api.anthropic.com"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": Self.status == 200 ? "text/event-stream" : "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
