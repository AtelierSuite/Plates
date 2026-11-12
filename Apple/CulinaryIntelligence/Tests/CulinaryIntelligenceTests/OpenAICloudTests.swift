import Foundation
import FoundationModels
import Testing
@testable import CulinaryIntelligence

/// GPT 6.1 Sol has not been run against OpenAI yet, so these hold the client to the Responses
/// API as OpenAI documents it: the body, the streamed events, and the errors.
@MainActor
@Suite(.serialized)
struct OpenAICloudTests {
    let cloud = OpenAICloud(key: { "sk-proj-test-stub" })

    @Test func readsTextDeltasAndSkipsTheRest() throws {
        #expect(try OpenAICloud.text(inEvent: #" {"type":"response.output_text.delta","item_id":"msg_1","output_index":1,"content_index":0,"delta":"Egg"}"#) == "Egg")
        #expect(try OpenAICloud.text(inEvent: #"{"type":"response.created","response":{"id":"resp_1","status":"in_progress"}}"#) == nil)
        #expect(try OpenAICloud.text(inEvent: #"{"type":"response.output_item.added","output_index":0,"item":{"type":"reasoning","id":"rs_1"}}"#) == nil)
        #expect(try OpenAICloud.text(inEvent: #"{"type":"response.output_text.done","text":"Egg"}"#) == nil)
        #expect(try OpenAICloud.text(inEvent: #"{"type":"response.completed","response":{"id":"resp_1","status":"completed"}}"#) == nil)
        #expect(try OpenAICloud.text(inEvent: "not json") == nil)
    }

    @Test func endsOnARefusalAFailureOrAnErrorEvent() {
        #expect(throws: OpenAIError.refused) {
            try OpenAICloud.text(inEvent: #"{"type":"response.refusal.delta","delta":"I can't help with that."}"#)
        }
        #expect(throws: OpenAIError.overloaded) {
            try OpenAICloud.text(inEvent: #"{"type":"response.failed","response":{"status":"failed","error":{"code":"server_error","message":"Something went wrong"}}}"#)
        }
        #expect(throws: OpenAIError.rateLimited) {
            try OpenAICloud.text(inEvent: #"{"type":"error","code":"rate_limit_exceeded","message":"Slow down","param":null}"#)
        }
    }

    @Test func endsACutOffAnswer() {
        #expect(throws: CloudError.cutOff) {
            try OpenAICloud.text(inEvent: #"{"type":"response.incomplete","response":{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"}}}"#)
        }
        #expect(throws: OpenAIError.refused) {
            try OpenAICloud.text(inEvent: #"{"type":"response.incomplete","response":{"status":"incomplete","incomplete_details":{"reason":"content_filter"}}}"#)
        }
    }

    @Test func mapsFailures() {
        #expect(OpenAIError.from(status: 401, type: "invalid_request_error", code: "invalid_api_key", message: "Incorrect API key provided") == .badKey)
        #expect(OpenAIError.from(status: 429, type: "insufficient_quota", code: "insufficient_quota", message: nil) == .noCredit)
        #expect(OpenAIError.from(status: 429, type: nil, code: "credit_balance_exhausted", message: nil) == .noCredit)
        #expect(OpenAIError.from(status: 429, type: nil, code: "project_spend_limit_exceeded", message: nil) == .noCredit)
        #expect(OpenAIError.from(status: 429, type: nil, code: "organization_usage_limit_exceeded", message: nil) == .noCredit)
        #expect(OpenAIError.from(status: 429, type: "requests", code: "rate_limit_exceeded", message: nil) == .rateLimited)
        #expect(OpenAIError.from(status: 429, type: "rate_limit_error", code: "slow_down", message: nil) == .rateLimited)
        #expect(OpenAIError.from(status: 429, type: nil, code: nil, message: "Rate limit reached for requests") == .rateLimited)
        #expect(OpenAIError.from(status: 404, type: "invalid_request_error", code: "model_not_found", message: nil) == .notPermitted)
        #expect(OpenAIError.from(status: 403, type: nil, code: "unsupported_country_region_territory", message: nil) == .notPermitted)
        #expect(OpenAIError.from(status: 503, type: "service_unavailable_error", code: "server_is_overloaded", message: nil) == .overloaded)
        #expect(OpenAIError.from(status: 500, type: "server_error", code: nil, message: nil) == .overloaded)
        #expect(OpenAIError.from(status: 400, type: "invalid_request_error", code: nil, message: "bad") == .server(400, "bad"))
    }

    @Test func sendsNoSamplingSettingsAndStoresNothing() throws {
        let data = OpenAICloud.body(system: "S", prompt: "P", maximumTokens: 1400)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["model"] as? String == "gpt-6.1-sol")
        #expect(body["instructions"] as? String == "S")
        #expect(body["max_output_tokens"] as? Int == 1400 + OpenAICloud.reasoningAllowance)
        #expect((body["reasoning"] as? [String: Any])?["effort"] as? String == "medium")
        #expect(body["store"] as? Bool == false)
        #expect(body["stream"] as? Bool == true)
        #expect(body["temperature"] == nil)
        #expect(body["top_p"] == nil)
        #expect(body["text"] == nil)
    }

    @Test func sendsTheExampleAsAnEarlierExchange() throws {
        let data = OpenAICloud.body(system: "S", example: (ask: "A", answer: "B"), prompt: "P", maximumTokens: 10)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let input = try #require(body["input"] as? [[String: String]])
        #expect(input.map { $0["role"] ?? "" } == ["user", "assistant", "user"])
        #expect(input.map { $0["content"] ?? "" } == ["A", "B", "P"])
    }

    @Test func holdsAPassToItsSchemaStrictly() throws {
        let schema = try ModelPasses.jsonSchema(StructuredIngredient.generationSchema)
        let data = OpenAICloud.body(system: "S", prompt: "P", maximumTokens: 10, schema: schema)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let format = try #require((body["text"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        #expect(format["name"] as? String == "answer")
        #expect(format["strict"] as? Bool == true)
        let sent = try #require(format["schema"] as? [String: Any])
        #expect(sent["additionalProperties"] as? Bool == false)
        #expect(Set(sent["required"] as? [String] ?? []) == ["item", "section", "icon", "amount", "note"])
    }

    @Test func turnsStrictModeOffForAnOptionalProperty() throws {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "steps": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": ["title": ["type": "string"], "note": ["type": "string"]],
                        "required": ["title"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            "required": ["steps"],
        ]
        #expect(OpenAICloud.strictSchema(schema) == nil)
        let data = OpenAICloud.body(system: "S", prompt: "P", maximumTokens: 10, schema: schema)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let format = try #require((body["text"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["strict"] as? Bool == false)
    }

    @Test func closesEveryNestedObjectInAStrictSchema() throws {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "steps": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": ["title": ["type": "string"]],
                        "required": ["title"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            "required": ["steps"],
        ]
        let strict = try #require(OpenAICloud.strictSchema(schema))
        #expect(strict["additionalProperties"] as? Bool == false)
        let steps = try #require((strict["properties"] as? [String: Any])?["steps"] as? [String: Any])
        #expect((steps["items"] as? [String: Any])?["additionalProperties"] as? Bool == false)
    }

    // MARK: - Stubbed requests

    @Test func streamsARecordedAnswer() async throws {
        try await withStub(status: 200, body: Self.recordedStream) {
            var text = ""
            for try await piece in cloud.write(instructions: "S", example: nil, prompt: "P", maximumTokens: 100, temperature: 0.7) {
                text += piece
            }
            #expect(text == "Egg Fried Rice\nServes 2")
            #expect(StubProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer sk-proj-test-stub")
            #expect(StubProtocol.lastRequest?.url?.path() == "/v1/responses")
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
        let failure = #"{"error":{"message":"Incorrect API key provided: sk-proj-****stub.","type":"invalid_request_error","param":null,"code":"invalid_api_key"}}"#
        try await withStub(status: 401, body: failure) {
            await #expect(throws: OpenAIError.badKey) {
                for try await _ in cloud.write(instructions: "S", example: nil, prompt: "P", maximumTokens: 10, temperature: 0.7) {}
            }
        }
    }

    @Test func reportsNoCredit() async throws {
        let failure = #"{"error":{"message":"You exceeded your current quota.","type":"insufficient_quota","param":null,"code":"insufficient_quota"}}"#
        try await withStub(status: 429, body: failure) {
            await #expect(throws: OpenAIError.noCredit) {
                _ = try await cloud.ideate(instructions: "S", prompt: "P", maximumTokens: 10, temperature: 0.7)
            }
        }
    }

    @Test func needsAKey() async throws {
        UserDefaults.standard.set(true, forKey: Plates.allowedKey)
        let keyless = OpenAICloud(key: { nil })
        #expect(!keyless.isConfigured)
        await #expect(throws: OpenAIError.noKey) {
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
    event: response.created
    data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_1","object":"response","status":"in_progress","model":"gpt-6.1-sol"}}

    event: response.output_item.added
    data: {"type":"response.output_item.added","sequence_number":1,"output_index":0,"item":{"id":"rs_1","type":"reasoning","summary":[]}}

    event: response.output_item.done
    data: {"type":"response.output_item.done","sequence_number":2,"output_index":0,"item":{"id":"rs_1","type":"reasoning","summary":[]}}

    event: response.output_item.added
    data: {"type":"response.output_item.added","sequence_number":3,"output_index":1,"item":{"id":"msg_1","type":"message","status":"in_progress","role":"assistant","content":[]}}

    event: response.output_text.delta
    data: {"type":"response.output_text.delta","sequence_number":4,"item_id":"msg_1","output_index":1,"content_index":0,"delta":"Egg Fried Rice\\n"}

    event: response.output_text.delta
    data: {"type":"response.output_text.delta","sequence_number":5,"item_id":"msg_1","output_index":1,"content_index":0,"delta":"Serves 2"}

    event: response.output_text.done
    data: {"type":"response.output_text.done","sequence_number":6,"item_id":"msg_1","output_index":1,"content_index":0,"text":"Egg Fried Rice\\nServes 2"}

    event: response.completed
    data: {"type":"response.completed","sequence_number":7,"response":{"id":"resp_1","object":"response","status":"completed","model":"gpt-6.1-sol"}}

    """

    private static func stream(answering text: String) -> String {
        """
        event: response.output_text.delta
        data: {"type":"response.output_text.delta","output_index":1,"content_index":0,"delta":"\(text)"}

        event: response.completed
        data: {"type":"response.completed","response":{"id":"resp_1","status":"completed"}}

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

/// Answers every request to api.openai.com with a set status and body, and keeps the last
/// request so its headers can be checked.
private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host() == "api.openai.com"
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
