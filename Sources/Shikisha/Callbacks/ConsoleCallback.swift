import Foundation

/// Print lifecycle events to standard output. Useful for development; replace with
/// `TracingCallback` for structured production logs.
public struct ConsoleCallback: Callback {
    public let prefix: String

    public init(prefix: String = "[shikisha]") {
        self.prefix = prefix
    }

    public func onLLMStart(model: String, messages: [any Message]) async {
        print("\(prefix) llm.start model=\(model) messages=\(messages.count)")
    }

    public func onLLMEnd(model: String, response: AIMessage) async {
        let usage = response.usageMetadata
        let usageDescription = usage.map { "in=\($0.inputTokens) out=\($0.outputTokens)" } ?? "-"
        print("\(prefix) llm.end   model=\(model) tools=\(response.toolCalls.count) tokens=\(usageDescription)")
    }

    public func onLLMError(model: String, error: any Error) async {
        print("\(prefix) llm.error model=\(model) error=\(error)")
    }

    public func onToolStart(name: String, arguments: JSONValue) async {
        print("\(prefix) tool.start name=\(name)")
    }

    public func onToolEnd(name: String, result: String) async {
        print("\(prefix) tool.end   name=\(name) bytes=\(result.utf8.count)")
    }

    public func onToolError(name: String, error: any Error) async {
        print("\(prefix) tool.error name=\(name) error=\(error)")
    }

    public func onAgentIteration(iteration: Int, messages: [any Message]) async {
        print("\(prefix) agent.iter #\(iteration) messages=\(messages.count)")
    }

    public func onAgentEnd(finalMessage: AIMessage, iterations: Int) async {
        print("\(prefix) agent.end  iterations=\(iterations) chars=\(finalMessage.content.count)")
    }
}
