import Foundation

/// Records every lifecycle event in memory. Drives Shikisha's own unit tests and
/// helps integrators write assertions about model behavior.
public actor RecordingCallback: Callback {
    public enum Event: Sendable, Equatable {
        case llmStart(model: String, messageCount: Int)
        case llmEnd(model: String, content: String)
        case llmError(model: String, message: String)
        case toolStart(name: String)
        case toolEnd(name: String, result: String)
        case toolError(name: String, message: String)
        case agentIteration(iteration: Int, messageCount: Int)
        case agentEnd(content: String, iterations: Int)
    }

    private var _events: [Event] = []

    public init() {}

    public var events: [Event] { _events }

    public func clear() { _events.removeAll() }

    public func onLLMStart(model: String, messages: [any Message]) async {
        _events.append(.llmStart(model: model, messageCount: messages.count))
    }

    public func onLLMEnd(model: String, response: AIMessage) async {
        _events.append(.llmEnd(model: model, content: response.content))
    }

    public func onLLMError(model: String, error: any Error) async {
        _events.append(.llmError(model: model, message: String(describing: error)))
    }

    public func onToolStart(name: String, arguments _: JSONValue) async {
        _events.append(.toolStart(name: name))
    }

    public func onToolEnd(name: String, result: String) async {
        _events.append(.toolEnd(name: name, result: result))
    }

    public func onToolError(name: String, error: any Error) async {
        _events.append(.toolError(name: name, message: String(describing: error)))
    }

    public func onAgentIteration(iteration: Int, messages: [any Message]) async {
        _events.append(.agentIteration(iteration: iteration, messageCount: messages.count))
    }

    public func onAgentEnd(finalMessage: AIMessage, iterations: Int) async {
        _events.append(.agentEnd(content: finalMessage.content, iterations: iterations))
    }
}
