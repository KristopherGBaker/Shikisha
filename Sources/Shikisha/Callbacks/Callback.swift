import Foundation

/// Lifecycle hooks for chat models, tools, and agents. Implement to plug logging,
/// tracing, usage tracking, or any custom side-effect into Shikisha runs.
///
/// All methods are async to leave room for I/O (writing trace lines to disk, emitting
/// to an OTel exporter, …) but default to no-ops so handlers only override what they care
/// about.
public protocol Callback: Sendable {
    func onLLMStart(model: String, messages: [any Message]) async
    func onLLMEnd(model: String, response: AIMessage) async
    func onLLMError(model: String, error: any Error) async

    func onToolStart(name: String, arguments: JSONValue) async
    func onToolEnd(name: String, result: String) async
    func onToolError(name: String, error: any Error) async

    func onAgentIteration(iteration: Int, messages: [any Message]) async
    func onAgentEnd(finalMessage: AIMessage, iterations: Int) async
}

public extension Callback {
    func onLLMStart(model _: String, messages _: [any Message]) async {}
    func onLLMEnd(model _: String, response _: AIMessage) async {}
    func onLLMError(model _: String, error _: any Error) async {}

    func onToolStart(name _: String, arguments _: JSONValue) async {}
    func onToolEnd(name _: String, result _: String) async {}
    func onToolError(name _: String, error _: any Error) async {}

    func onAgentIteration(iteration _: Int, messages _: [any Message]) async {}
    func onAgentEnd(finalMessage _: AIMessage, iterations _: Int) async {}
}
