import Foundation

/// Role of a chat message. Mirrors OpenAI's wire roles and is what every provider adapter
/// translates into and out of.
public enum MessageRole: String, Codable, Sendable, CaseIterable {
    case system
    case user      // == human
    case assistant // == ai
    case tool
}

/// A chat message. The four concrete types (`SystemMessage`, `HumanMessage`, `AIMessage`,
/// `ToolMessage`) all conform; provider adapters work against the protocol so callers can
/// mix them freely in `[any Message]`.
public protocol Message: Sendable {
    var role: MessageRole { get }
    var content: String { get }
    var name: String? { get }
    var id: String? { get }
}

/// A system (instructions) message.
public struct SystemMessage: Message, Sendable, Hashable {
    public let content: String
    public let name: String?
    public let id: String?

    public var role: MessageRole { .system }

    public init(content: String, name: String? = nil, id: String? = nil) {
        self.content = content
        self.name = name
        self.id = id
    }
}

/// A human / user message. Carries optional multimodal attachments (images today;
/// providers that don't support a given attachment type ignore it on encode).
public struct HumanMessage: Message, Sendable, Hashable {
    public let content: String
    public let name: String?
    public let id: String?
    public let attachments: [MessageAttachment]

    public var role: MessageRole { .user }

    public init(
        content: String,
        name: String? = nil,
        id: String? = nil,
        attachments: [MessageAttachment] = []
    ) {
        self.content = content
        self.name = name
        self.id = id
        self.attachments = attachments
    }
}

/// An AI / assistant response. May carry tool-call requests, usage tokens, and
/// arbitrary provider response metadata (id, finish reason, raw chunks, …).
public struct AIMessage: Message, Sendable, Hashable {
    public let content: String
    public let toolCalls: [ToolCall]
    public let usageMetadata: UsageMetadata?
    public let responseMetadata: [String: JSONValue]
    public let name: String?
    public let id: String?

    public var role: MessageRole { .assistant }

    public init(
        content: String,
        toolCalls: [ToolCall] = [],
        usageMetadata: UsageMetadata? = nil,
        responseMetadata: [String: JSONValue] = [:],
        name: String? = nil,
        id: String? = nil
    ) {
        self.content = content
        self.toolCalls = toolCalls
        self.usageMetadata = usageMetadata
        self.responseMetadata = responseMetadata
        self.name = name
        self.id = id
    }
}

/// A tool-result message — the response to a previous `ToolCall` requested by the model.
public struct ToolMessage: Message, Sendable, Hashable {
    public let content: String
    public let toolCallId: String
    public let name: String?
    public let id: String?
    public let isError: Bool

    public var role: MessageRole { .tool }

    public init(
        content: String,
        toolCallId: String,
        name: String? = nil,
        id: String? = nil,
        isError: Bool = false
    ) {
        self.content = content
        self.toolCallId = toolCallId
        self.name = name
        self.id = id
        self.isError = isError
    }
}

/// A request from the assistant to invoke a tool by name with structured arguments.
public struct ToolCall: Sendable, Hashable, Codable {
    public let id: String
    public let name: String
    public let arguments: JSONValue

    public init(id: String, name: String, arguments: JSONValue) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// Token usage as reported by the provider. `cacheReadInputTokens` / `cacheCreationInputTokens`
/// are Anthropic prompt-caching counters; other providers leave them at zero.
public struct UsageMetadata: Sendable, Hashable, Codable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    public let cacheReadInputTokens: Int
    public let cacheCreationInputTokens: Int

    public init(
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int? = nil,
        cacheReadInputTokens: Int = 0,
        cacheCreationInputTokens: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens ?? (inputTokens + outputTokens)
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
    }

    public static func + (lhs: UsageMetadata, rhs: UsageMetadata) -> UsageMetadata {
        UsageMetadata(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            totalTokens: lhs.totalTokens + rhs.totalTokens,
            cacheReadInputTokens: lhs.cacheReadInputTokens + rhs.cacheReadInputTokens,
            cacheCreationInputTokens: lhs.cacheCreationInputTokens + rhs.cacheCreationInputTokens
        )
    }
}
