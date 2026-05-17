import Foundation

/// Replace older history with an LLM-generated summary as the buffer grows. The summary lives
/// as a `SystemMessage` at the start of the message list; recent turns stay verbatim until
/// they're rolled in.
public actor ConversationSummaryMemory: ChatMemory {
    public let model: any ChatModel
    private var summary: String = ""
    private var pending: [any Message] = []

    public init(model: any ChatModel) {
        self.model = model
    }

    public func addMessage(_ message: any Message) async throws {
        pending.append(message)
    }

    public func messages() async throws -> [any Message] {
        var result: [any Message] = []
        if !summary.isEmpty {
            result.append(SystemMessage(content: "Summary so far:\n\(summary)"))
        }
        result.append(contentsOf: pending)
        return result
    }

    public func clear() async throws {
        summary = ""
        pending.removeAll()
    }

    /// Fold every pending message into the running summary. The pending list is cleared.
    public func summarize() async throws {
        guard !pending.isEmpty else { return }
        let history = pending
            .map { "\($0.role.rawValue.capitalized): \($0.content)" }
            .joined(separator: "\n")
        let messages: [any Message] = [
            SystemMessage(content: "Summarize the conversation below into a terse running summary."),
            HumanMessage(content: """
                Existing summary: \(summary.isEmpty ? "(none)" : summary)

                New turns:
                \(history)
                """)
        ]
        let response = try await model.invoke(messages)
        summary = response.content
        pending.removeAll()
    }
}

/// Token-aware variant: summarize whenever pending tokens exceed `maxTokens`.
public actor ConversationSummaryBufferMemory: ChatMemory {
    public let model: any ChatModel
    public let maxTokens: Int
    public let counter: any TokenCounter

    private var summary: String = ""
    private var pending: [any Message] = []

    public init(model: any ChatModel, maxTokens: Int, counter: any TokenCounter = ApproximateTokenCounter()) {
        self.model = model
        self.maxTokens = maxTokens
        self.counter = counter
    }

    public func addMessage(_ message: any Message) async throws {
        pending.append(message)
        if counter.countTokens(in: pending) > maxTokens {
            try await summarize()
        }
    }

    public func messages() async throws -> [any Message] {
        var result: [any Message] = []
        if !summary.isEmpty {
            result.append(SystemMessage(content: "Summary so far:\n\(summary)"))
        }
        result.append(contentsOf: pending)
        return result
    }

    public func clear() async throws {
        summary = ""
        pending.removeAll()
    }

    public func summarize() async throws {
        guard !pending.isEmpty else { return }
        let half = pending.count / 2
        let toSummarize = pending.prefix(half)
        let history = toSummarize
            .map { "\($0.role.rawValue.capitalized): \($0.content)" }
            .joined(separator: "\n")
        let messages: [any Message] = [
            SystemMessage(content: "Summarize the conversation below into a terse running summary."),
            HumanMessage(content: """
                Existing summary: \(summary.isEmpty ? "(none)" : summary)

                New turns:
                \(history)
                """)
        ]
        let response = try await model.invoke(messages)
        summary = response.content
        pending.removeFirst(half)
    }
}
