import Foundation

/// A streaming chunk of an assistant response. Concatenate via `+` (or `.merged(...)`) to
/// reconstruct the final `AIMessage`. Tool-call fragments accumulate by `index`.
public struct AIMessageChunk: Sendable, Hashable {
    public let content: String
    public let toolCallChunks: [ToolCallChunk]
    public let usageMetadata: UsageMetadata?
    public let responseMetadata: [String: JSONValue]
    public let id: String?

    public init(
        content: String = "",
        toolCallChunks: [ToolCallChunk] = [],
        usageMetadata: UsageMetadata? = nil,
        responseMetadata: [String: JSONValue] = [:],
        id: String? = nil
    ) {
        self.content = content
        self.toolCallChunks = toolCallChunks
        self.usageMetadata = usageMetadata
        self.responseMetadata = responseMetadata
        self.id = id
    }

    public static func + (lhs: AIMessageChunk, rhs: AIMessageChunk) -> AIMessageChunk {
        AIMessageChunk(
            content: lhs.content + rhs.content,
            toolCallChunks: mergeChunks(lhs.toolCallChunks, rhs.toolCallChunks),
            usageMetadata: combineUsage(lhs.usageMetadata, rhs.usageMetadata),
            responseMetadata: lhs.responseMetadata.merging(rhs.responseMetadata) { _, new in new },
            id: rhs.id ?? lhs.id
        )
    }

    /// Materialize the accumulated chunk as a final `AIMessage`. Best-effort: tool-call
    /// argument JSON may still be partial if the stream was truncated.
    public func toAIMessage() -> AIMessage {
        let toolCalls: [ToolCall] = toolCallChunks
            .filter { $0.name?.isEmpty == false }
            .map { chunk in
                let parsed = JSONValue.parse(chunk.argumentsBuffer) ?? .object([:])
                return ToolCall(id: chunk.id ?? "", name: chunk.name ?? "", arguments: parsed)
            }
        return AIMessage(
            content: content,
            toolCalls: toolCalls,
            usageMetadata: usageMetadata,
            responseMetadata: responseMetadata,
            id: id
        )
    }
}

/// One streaming fragment of a tool call. The `argumentsBuffer` accumulates the JSON-string
/// arguments as the model streams them; downstream code parses once the call is complete.
public struct ToolCallChunk: Sendable, Hashable {
    public let index: Int
    public let id: String?
    public let name: String?
    public let argumentsBuffer: String

    public init(index: Int, id: String? = nil, name: String? = nil, argumentsBuffer: String = "") {
        self.index = index
        self.id = id
        self.name = name
        self.argumentsBuffer = argumentsBuffer
    }
}

private func mergeChunks(_ lhs: [ToolCallChunk], _ rhs: [ToolCallChunk]) -> [ToolCallChunk] {
    var indexed = Dictionary(uniqueKeysWithValues: lhs.map { ($0.index, $0) })
    for chunk in rhs {
        if let existing = indexed[chunk.index] {
            indexed[chunk.index] = ToolCallChunk(
                index: chunk.index,
                id: chunk.id ?? existing.id,
                name: chunk.name ?? existing.name,
                argumentsBuffer: existing.argumentsBuffer + chunk.argumentsBuffer
            )
        } else {
            indexed[chunk.index] = chunk
        }
    }
    return indexed.values.sorted { $0.index < $1.index }
}

private func combineUsage(_ lhs: UsageMetadata?, _ rhs: UsageMetadata?) -> UsageMetadata? {
    switch (lhs, rhs) {
    case (nil, nil): return nil
    case (let left?, nil): return left
    case (nil, let right?): return right
    case (let left?, let right?): return left + right
    }
}

public extension AsyncSequence where Element == AIMessageChunk, Self: Sendable {
    /// Drain a chunk stream into a single accumulated `AIMessage`. Streaming consumers
    /// usually want this — it's the moral equivalent of `await model.invoke(...)` when
    /// you don't need partial output.
    func collect() async throws -> AIMessage {
        var accumulator = AIMessageChunk()
        for try await chunk in self {
            accumulator = accumulator + chunk
        }
        return accumulator.toAIMessage()
    }
}
