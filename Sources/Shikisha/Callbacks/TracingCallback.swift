import Foundation

/// Emit one JSON line per lifecycle event. The default sink prints to stdout, but you
/// can wire any `@Sendable (String) async -> Void` — file, HTTP exporter, OTel, LangSmith.
public struct TracingCallback: Callback {
    public typealias Sink = @Sendable (String) async -> Void

    public let sink: Sink
    public let runID: String

    public init(runID: String = UUID().uuidString, sink: @escaping Sink = { line in print(line) }) {
        self.runID = runID
        self.sink = sink
    }

    public func onLLMStart(model: String, messages: [any Message]) async {
        await emit([
            "event": "llm.start",
            "model": .string(model),
            "messages": .int(Int64(messages.count))
        ])
    }

    public func onLLMEnd(model: String, response: AIMessage) async {
        var fields: [String: JSONValue] = [
            "event": "llm.end",
            "model": .string(model),
            "tools": .int(Int64(response.toolCalls.count))
        ]
        if let usage = response.usageMetadata {
            fields["tokens_in"] = .int(Int64(usage.inputTokens))
            fields["tokens_out"] = .int(Int64(usage.outputTokens))
            if usage.cacheReadInputTokens > 0 {
                fields["cache_read"] = .int(Int64(usage.cacheReadInputTokens))
            }
            if usage.cacheCreationInputTokens > 0 {
                fields["cache_write"] = .int(Int64(usage.cacheCreationInputTokens))
            }
        }
        await emit(fields)
    }

    public func onLLMError(model: String, error: any Error) async {
        await emit([
            "event": "llm.error",
            "model": .string(model),
            "error": .string(String(describing: error))
        ])
    }

    public func onToolStart(name: String, arguments _: JSONValue) async {
        await emit([
            "event": "tool.start",
            "tool": .string(name)
        ])
    }

    public func onToolEnd(name: String, result: String) async {
        await emit([
            "event": "tool.end",
            "tool": .string(name),
            "bytes": .int(Int64(result.utf8.count))
        ])
    }

    public func onToolError(name: String, error: any Error) async {
        await emit([
            "event": "tool.error",
            "tool": .string(name),
            "error": .string(String(describing: error))
        ])
    }

    public func onAgentIteration(iteration: Int, messages: [any Message]) async {
        await emit([
            "event": "agent.iteration",
            "iteration": .int(Int64(iteration)),
            "messages": .int(Int64(messages.count))
        ])
    }

    public func onAgentEnd(finalMessage: AIMessage, iterations: Int) async {
        await emit([
            "event": "agent.end",
            "iterations": .int(Int64(iterations))
        ])
    }

    private func emit(_ fields: [String: JSONValue]) async {
        var enriched = fields
        enriched["run_id"] = .string(runID)
        enriched["ts"] = .string(ISO8601DateFormatter().string(from: Date()))
        let value = JSONValue.object(enriched)
        await sink(value.serialized())
    }
}
