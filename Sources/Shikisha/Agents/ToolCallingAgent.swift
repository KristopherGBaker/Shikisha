import Foundation

/// The result of an agent run.
public struct AgentResult: Sendable {
    public let finalMessage: AIMessage
    public let iterations: Int
    public let trace: [any Message]

    public init(finalMessage: AIMessage, iterations: Int, trace: [any Message]) {
        self.finalMessage = finalMessage
        self.iterations = iterations
        self.trace = trace
    }
}

/// A simple tool-calling agent. Each iteration:
/// 1. Send the running message list to the model.
/// 2. If the response has no tool calls, return.
/// 3. Otherwise, run every requested tool and append the results, then loop.
///
/// Bounded by `maxIterations` to prevent infinite loops on misbehaving models.
public struct ToolCallingAgent: Sendable {
    public let model: any ChatModel
    public let executor: ToolExecutor
    public let maxIterations: Int
    public let callbacks: CallbackManager

    public init(
        model: any ChatModel,
        tools: [any Tool],
        maxIterations: Int = 8,
        callbacks: CallbackManager = .empty
    ) {
        self.model = model
        self.executor = ToolExecutor(tools: tools)
        self.maxIterations = maxIterations
        self.callbacks = callbacks
    }

    public func run(_ messages: [any Message]) async throws -> AgentResult {
        var trace = messages
        var iteration = 0
        while iteration < maxIterations {
            iteration += 1
            await callbacks.onAgentIteration(iteration: iteration, messages: trace)
            let response = try await model.invoke(trace)
            trace.append(response)
            if response.toolCalls.isEmpty {
                await callbacks.onAgentEnd(finalMessage: response, iterations: iteration)
                return AgentResult(finalMessage: response, iterations: iteration, trace: trace)
            }
            for call in response.toolCalls {
                let toolMessage = await executor.run(call, callbacks: callbacks)
                trace.append(toolMessage)
            }
        }
        let final = AIMessage(content: "Agent stopped after \(maxIterations) iterations without a final answer.")
        trace.append(final)
        await callbacks.onAgentEnd(finalMessage: final, iterations: iteration)
        return AgentResult(finalMessage: final, iterations: iteration, trace: trace)
    }
}
