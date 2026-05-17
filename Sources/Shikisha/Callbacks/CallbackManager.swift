import Foundation

/// Aggregates a list of `Callback` handlers and broadcasts each lifecycle event
/// to all of them. Errors raised by individual handlers are swallowed — a misbehaving
/// callback shouldn't take down the run.
public struct CallbackManager: Sendable {
    public static let empty = CallbackManager(handlers: [])

    public let handlers: [any Callback]

    public init(handlers: [any Callback]) {
        self.handlers = handlers
    }

    public var isEmpty: Bool { handlers.isEmpty }

    public func onLLMStart(model: String, messages: [any Message]) async {
        guard !handlers.isEmpty else { return }
        for handler in handlers { await handler.onLLMStart(model: model, messages: messages) }
    }

    public func onLLMEnd(model: String, response: AIMessage) async {
        guard !handlers.isEmpty else { return }
        for handler in handlers { await handler.onLLMEnd(model: model, response: response) }
    }

    public func onLLMError(model: String, error: any Error) async {
        guard !handlers.isEmpty else { return }
        for handler in handlers { await handler.onLLMError(model: model, error: error) }
    }

    public func onToolStart(name: String, arguments: JSONValue) async {
        guard !handlers.isEmpty else { return }
        for handler in handlers { await handler.onToolStart(name: name, arguments: arguments) }
    }

    public func onToolEnd(name: String, result: String) async {
        guard !handlers.isEmpty else { return }
        for handler in handlers { await handler.onToolEnd(name: name, result: result) }
    }

    public func onToolError(name: String, error: any Error) async {
        guard !handlers.isEmpty else { return }
        for handler in handlers { await handler.onToolError(name: name, error: error) }
    }

    public func onAgentIteration(iteration: Int, messages: [any Message]) async {
        guard !handlers.isEmpty else { return }
        for handler in handlers { await handler.onAgentIteration(iteration: iteration, messages: messages) }
    }

    public func onAgentEnd(finalMessage: AIMessage, iterations: Int) async {
        guard !handlers.isEmpty else { return }
        for handler in handlers { await handler.onAgentEnd(finalMessage: finalMessage, iterations: iterations) }
    }

    /// Merge two managers, preserving order.
    public func appending(_ other: CallbackManager) -> CallbackManager {
        CallbackManager(handlers: handlers + other.handlers)
    }

    public func appending(_ handler: any Callback) -> CallbackManager {
        CallbackManager(handlers: handlers + [handler])
    }
}
