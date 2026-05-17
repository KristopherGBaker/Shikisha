import Foundation
import Testing
@testable import Shikisha

@Suite("Anthropic provider")
struct AnthropicProviderTests {
    @Test func testInvokeDecodesText() async throws {
        let stub = StubHTTPClient()
        stub.register(path: "/v1/messages", body: """
        {
          "id": "msg_01",
          "model": "claude-test",
          "role": "assistant",
          "content": [{ "type": "text", "text": "Greetings." }],
          "stop_reason": "end_turn",
          "usage": { "input_tokens": 6, "output_tokens": 3 }
        }
        """)
        let model = AnthropicChatModel(
            config: AnthropicConfig(apiKey: "ak-test"),
            model: "claude-test",
            httpClient: stub
        )
        let messages: [any Message] = [
            SystemMessage(content: "Be brief."),
            HumanMessage(content: "Hi")
        ]
        let response = try await model.invoke(messages)
        #expect(response.content == "Greetings.")
        #expect(response.usageMetadata?.inputTokens == 6)
        #expect(response.usageMetadata?.outputTokens == 3)

        let sent = stub.requests[0]
        let body = JSONValue.parse(String(data: sent.body ?? Data(), encoding: .utf8) ?? "")
        // System lifted to top-level
        #expect(body?["system"]?.stringValue == "Be brief.")
        // Messages contain a single user entry with a single text block
        #expect(body?["messages"]?[0]?["role"]?.stringValue == "user")
        #expect(body?["messages"]?[0]?["content"]?[0]?["type"]?.stringValue == "text")
        #expect(sent.headers["x-api-key"] == "ak-test")
        #expect(sent.headers["anthropic-version"] == "2023-06-01")
    }

    @Test func testToolUseBlockBecomesToolCall() async throws {
        let stub = StubHTTPClient()
        stub.register(path: "/v1/messages", body: """
        {
          "id": "msg_02",
          "role": "assistant",
          "content": [
            { "type": "text", "text": "Calling tool" },
            { "type": "tool_use", "id": "toolu_1", "name": "lookup", "input": { "key": "swift" } }
          ]
        }
        """)
        let model = AnthropicChatModel(
            config: AnthropicConfig(apiKey: "ak"),
            model: "claude-test",
            httpClient: stub
        )
        let response = try await model.invoke([HumanMessage(content: "find swift")])
        #expect(response.content == "Calling tool")
        #expect(response.toolCalls.count == 1)
        #expect(response.toolCalls[0].name == "lookup")
        #expect(response.toolCalls[0].arguments["key"]?.stringValue == "swift")
    }

    @Test func testCacheSystemEmitsBlocks() async throws {
        let stub = StubHTTPClient()
        stub.register(path: "/v1/messages", body: """
        { "id": "x", "role": "assistant", "content": [{ "type": "text", "text": "ok" }] }
        """)
        let model = AnthropicChatModel(
            config: AnthropicConfig(apiKey: "ak"),
            model: "claude-test",
            cacheSystem: true,
            httpClient: stub
        )
        _ = try await model.invoke([SystemMessage(content: "rules"), HumanMessage(content: "hi")])
        let body = JSONValue.parse(String(data: stub.requests[0].body ?? Data(), encoding: .utf8) ?? "")
        #expect(body?["system"]?[0]?["text"]?.stringValue == "rules")
        #expect(body?["system"]?[0]?["cache_control"]?["type"]?.stringValue == "ephemeral")
    }
}
