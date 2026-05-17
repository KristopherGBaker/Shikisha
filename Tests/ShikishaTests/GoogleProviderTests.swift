import Foundation
import Testing
@testable import Shikisha

@Suite("Google Gemini provider")
struct GoogleProviderTests {
    @Test func testInvokeDecodesContent() async throws {
        let stub = StubHTTPClient()
        stub.register(path: "/v1beta/models/gemini-test:generateContent", body: """
        {
          "candidates": [{
            "content": { "role": "model", "parts": [{ "text": "Hello from Gemini" }] }
          }],
          "usageMetadata": {
            "promptTokenCount": 3,
            "candidatesTokenCount": 4,
            "totalTokenCount": 7
          }
        }
        """)
        let model = GoogleChatModel(
            config: GoogleConfig(apiKey: "abc"),
            model: "gemini-test",
            httpClient: stub
        )
        let response = try await model.invoke([HumanMessage(content: "Hi")])
        #expect(response.content == "Hello from Gemini")
        #expect(response.usageMetadata?.totalTokens == 7)
        let sent = stub.requests[0]
        let body = JSONValue.parse(String(data: sent.body ?? Data(), encoding: .utf8) ?? "")
        // System absent -> systemInstruction encoded as null/omitted
        #expect(body?["contents"]?[0]?["role"]?.stringValue == "user")
    }

    @Test func testEmbeddings() async throws {
        let stub = StubHTTPClient()
        stub.register(path: "/v1beta/models/text-embedding-004:batchEmbedContents", body: """
        {
          "embeddings": [
            { "values": [0.1, 0.2, 0.3] },
            { "values": [0.4, 0.5, 0.6] }
          ]
        }
        """)
        let embeddings = GoogleEmbeddings(
            config: GoogleConfig(apiKey: "abc"),
            model: "text-embedding-004",
            httpClient: stub
        )
        let vectors = try await embeddings.embedDocuments(["a", "b"])
        #expect(vectors == [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]])
    }
}
