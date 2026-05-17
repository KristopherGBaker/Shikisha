import Foundation
import Testing
@testable import Shikisha

@Suite("Ollama provider")
struct OllamaProviderTests {
    @Test func testInvokeDecodesMessage() async throws {
        let stub = StubHTTPClient()
        stub.register(path: "/api/chat", body: """
        {
          "model": "llama3",
          "message": { "role": "assistant", "content": "Hello" },
          "done": true,
          "prompt_eval_count": 5,
          "eval_count": 3
        }
        """)
        let model = OllamaChatModel(
            config: OllamaConfig(),
            model: "llama3",
            httpClient: stub
        )
        let response = try await model.invoke([HumanMessage(content: "Hi")])
        #expect(response.content == "Hello")
        #expect(response.usageMetadata?.inputTokens == 5)
        #expect(response.usageMetadata?.outputTokens == 3)
    }

    @Test func testStreamingNDJSON() async throws {
        let stub = StubHTTPClient()
        stub.registerStreaming(path: "/api/chat", lines: [
            #"{"message":{"role":"assistant","content":"He"},"done":false}"#,
            #"{"message":{"role":"assistant","content":"llo"},"done":false}"#,
            #"{"message":{"role":"assistant","content":""},"done":true,"prompt_eval_count":2,"eval_count":2}"#
        ])
        let model = OllamaChatModel(
            config: OllamaConfig(),
            model: "llama3",
            httpClient: stub
        )
        let final = try await model.stream([HumanMessage(content: "hi")]).collect()
        #expect(final.content == "Hello")
        #expect(final.usageMetadata?.inputTokens == 2)
    }

    @Test func testEmbeddingsRoundTrip() async throws {
        let stub = StubHTTPClient()
        stub.register(path: "/api/embed", body: """
        { "model": "nomic-embed-text", "embeddings": [[0.1, 0.2], [0.3, 0.4]] }
        """)
        let embeddings = OllamaEmbeddings(
            config: OllamaConfig(),
            model: "nomic-embed-text",
            httpClient: stub
        )
        let vectors = try await embeddings.embedDocuments(["a", "b"])
        #expect(vectors == [[0.1, 0.2], [0.3, 0.4]])
    }
}
