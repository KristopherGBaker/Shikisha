import Foundation
import Testing
@testable import Shikisha

@Suite("OpenAI provider")
struct OpenAIProviderTests {
    @Test func testInvokeDecodesResponse() async throws {
        let stub = StubHTTPClient()
        stub.register(path: "/v1/chat/completions", body: """
        {
          "id": "chatcmpl-123",
          "choices": [{
            "finish_reason": "stop",
            "message": { "role": "assistant", "content": "Hello!" }
          }],
          "usage": { "prompt_tokens": 5, "completion_tokens": 2, "total_tokens": 7 }
        }
        """)

        let model = OpenAIChatModel(
            config: OpenAIConfig(apiKey: "sk-test"),
            model: "gpt-4o-mini",
            httpClient: stub
        )
        let response = try await model.invoke([HumanMessage(content: "Hi")])
        #expect(response.content == "Hello!")
        #expect(response.id == "chatcmpl-123")
        #expect(response.usageMetadata?.totalTokens == 7)
        #expect(stub.requests.count == 1)
        let sent = stub.requests[0]
        #expect(sent.headers["Authorization"] == "Bearer sk-test")
        let bodyString = String(data: sent.body ?? Data(), encoding: .utf8) ?? ""
        #expect(bodyString.contains("\"role\":\"user\""))
        #expect(bodyString.contains("\"content\":\"Hi\""))
    }

    @Test func testDecodesToolCall() async throws {
        let stub = StubHTTPClient()
        stub.register(path: "/v1/chat/completions", body: """
        {
          "id": "chatcmpl-1",
          "choices": [{
            "finish_reason": "tool_calls",
            "message": {
              "role": "assistant",
              "content": null,
              "tool_calls": [{
                "id": "call-1",
                "type": "function",
                "function": { "name": "echo", "arguments": "{\\"text\\":\\"hello\\"}" }
              }]
            }
          }]
        }
        """)
        let model = OpenAIChatModel(
            config: OpenAIConfig(apiKey: "sk-test"),
            model: "gpt-4o-mini",
            httpClient: stub
        )
        let response = try await model.invoke([HumanMessage(content: "echo hello")])
        #expect(response.toolCalls.count == 1)
        let call = response.toolCalls[0]
        #expect(call.name == "echo")
        #expect(call.arguments["text"]?.stringValue == "hello")
    }

    @Test func testStreamingAccumulatesContent() async throws {
        let stub = StubHTTPClient()
        let frames = [
            #"data: {"id":"chunk-1","choices":[{"delta":{"content":"Hel"}}]}"#,
            "",
            #"data: {"id":"chunk-1","choices":[{"delta":{"content":"lo"}}]}"#,
            "",
            #"data: {"id":"chunk-1","choices":[{"delta":{}}],"usage":{"prompt_tokens":3,"completion_tokens":2,"total_tokens":5}}"#,
            "",
            "data: [DONE]",
            ""
        ]
        stub.registerStreaming(path: "/v1/chat/completions", lines: frames)
        let model = OpenAIChatModel(
            config: OpenAIConfig(apiKey: "sk-test"),
            model: "gpt-4o-mini",
            httpClient: stub
        )
        let messages: [any Message] = [HumanMessage(content: "Stream please")]
        let final = try await model.stream(messages).collect()
        #expect(final.content == "Hello")
        #expect(final.usageMetadata?.inputTokens == 3)
        #expect(final.usageMetadata?.outputTokens == 2)
    }

    @Test func testEmbeddingsRoundTrip() async throws {
        let stub = StubHTTPClient()
        stub.register(path: "/v1/embeddings", body: """
        {
          "data": [
            { "index": 0, "embedding": [0.1, 0.2, 0.3] },
            { "index": 1, "embedding": [0.4, 0.5, 0.6] }
          ]
        }
        """)
        let embeddings = OpenAIEmbeddings(
            config: OpenAIConfig(apiKey: "sk-test"),
            model: "text-embedding-3-small",
            httpClient: stub
        )
        let vectors = try await embeddings.embedDocuments(["a", "b"])
        #expect(vectors.count == 2)
        #expect(vectors[0] == [0.1, 0.2, 0.3])
    }
}
