import Foundation

/// Text-format ReAct agent for models without native tool calling. Drives the model with
/// `Thought:` / `Action:` / `Action Input:` / `Observation:` prompts, parsing each turn.
public struct ReActAgent: Sendable {
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

    public func run(question: String) async throws -> AgentResult {
        let toolDescriptions = executor.tools.values
            .map { "- \($0.name): \($0.description)" }
            .joined(separator: "\n")
        let toolNames = executor.tools.values.map(\.name).joined(separator: ", ")
        let system = SystemMessage(content: """
            Answer the user's question using the following tools:
            \(toolDescriptions)

            Use this exact format:
            Question: the input question
            Thought: think about what to do
            Action: one of [\(toolNames)]
            Action Input: arguments JSON for the action
            Observation: the result of the action
            ... (repeat Thought/Action/Action Input/Observation as needed)
            Thought: I now know the final answer
            Final Answer: the final answer to the user
            """)
        var trace: [any Message] = [system, HumanMessage(content: "Question: \(question)")]
        var iteration = 0
        while iteration < maxIterations {
            iteration += 1
            await callbacks.onAgentIteration(iteration: iteration, messages: trace)
            let response = try await model.invoke(trace)
            let text = response.content
            if let finalAnswer = extractFinalAnswer(text) {
                let final = AIMessage(content: finalAnswer)
                trace.append(final)
                await callbacks.onAgentEnd(finalMessage: final, iterations: iteration)
                return AgentResult(finalMessage: final, iterations: iteration, trace: trace)
            }
            guard let parsed = parseAction(text) else {
                let final = AIMessage(content: text)
                trace.append(final)
                await callbacks.onAgentEnd(finalMessage: final, iterations: iteration)
                return AgentResult(finalMessage: final, iterations: iteration, trace: trace)
            }
            let arguments = JSONValue.parse(parsed.input) ?? .object([:])
            let call = ToolCall(id: "react-\(iteration)", name: parsed.action, arguments: arguments)
            let toolMessage = await executor.run(call, callbacks: callbacks)
            trace.append(AIMessage(content: text))
            trace.append(HumanMessage(content: "Observation: \(toolMessage.content)"))
        }
        let stopped = AIMessage(content: "Agent stopped after \(maxIterations) iterations.")
        await callbacks.onAgentEnd(finalMessage: stopped, iterations: iteration)
        return AgentResult(finalMessage: stopped, iterations: iteration, trace: trace)
    }
}

private func extractFinalAnswer(_ text: String) -> String? {
    guard let range = text.range(of: "Final Answer:") else { return nil }
    return text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
}

private func parseAction(_ text: String) -> (action: String, input: String)? {
    guard let actionRange = text.range(of: "Action:") else { return nil }
    let afterAction = text[actionRange.upperBound...]
    guard let inputRange = afterAction.range(of: "Action Input:") else { return nil }
    let action = afterAction[..<inputRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
    let afterInput = afterAction[inputRange.upperBound...]
    let input: String
    if let observationRange = afterInput.range(of: "Observation:") {
        input = String(afterInput[..<observationRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
        input = String(afterInput).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return (action, input)
}
