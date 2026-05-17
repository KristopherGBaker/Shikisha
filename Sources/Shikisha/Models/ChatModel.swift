import Foundation

/// The contract every chat-model provider conforms to. Inputs are message arrays; outputs
/// are `AIMessage`s. Streaming consumers can request an `AsyncThrowingStream<AIMessageChunk>`.
///
/// Concrete types only need to implement `invoke(_:)` from `Runnable`; `stream` gets a
/// default implementation that buffers the unary response. Providers that natively stream
/// (OpenAI SSE, Anthropic SSE, Ollama NDJSON, Google SSE) override it.
public protocol ChatModel: Runnable where Input == [any Message], Output == AIMessage {
    /// Human-readable identifier (e.g. `"gpt-4o-mini"`, `"claude-sonnet-4-6"`).
    var modelName: String { get }

    /// Send a request and stream incremental chunks.
    func stream(_ messages: [any Message]) -> AsyncThrowingStream<AIMessageChunk, Error>
}

public extension ChatModel {
    func stream(_ messages: [any Message]) -> AsyncThrowingStream<AIMessageChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let final = try await invoke(messages)
                    continuation.yield(AIMessageChunk(
                        content: final.content,
                        toolCallChunks: final.toolCalls.enumerated().map { index, call in
                            ToolCallChunk(
                                index: index,
                                id: call.id,
                                name: call.name,
                                argumentsBuffer: call.arguments.serialized()
                            )
                        },
                        usageMetadata: final.usageMetadata,
                        responseMetadata: final.responseMetadata,
                        id: final.id
                    ))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
