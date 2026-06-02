import Foundation
import Shikisha

/// Streaming lets you render a model's reply incrementally instead of waiting for the whole
/// response. Every ``ChatModel`` exposes `stream(_:)`, which returns an
/// `AsyncThrowingStream` of ``AIMessageChunk`` values you can accumulate.
enum StreamingChatExample {
    static func run() async throws {
        let messages: [any Message] = [
            SystemMessage(content: "You are a concise assistant."),
            HumanMessage(content: "Give me three Swift concurrency tips.")
        ]

        // With a real provider each chunk arrives as the model generates it. `FakeChatModel`
        // uses the default streaming implementation, which emits the buffered reply as chunks —
        // enough to demonstrate the API shape.
        let model = FakeChatModel(responses: [
            AIMessage(content: "1. Prefer structured concurrency. 2. Make types Sendable. 3. Avoid blocking calls.")
        ])

        section("Streaming output")
        var assembled = AIMessageChunk()
        for try await chunk in model.stream(messages) {
            // Print each delta as it arrives, then keep a running total via `+`.
            print(chunk.content, terminator: "")
            assembled += chunk
        }
        print("\n")

        // `collect()` (on the stream) or `toAIMessage()` (on the assembled chunk) gives you the
        // final, complete message — including any tool calls and usage metadata.
        let final = assembled.toAIMessage()
        section("Final message")
        print(final.content)
    }
}
