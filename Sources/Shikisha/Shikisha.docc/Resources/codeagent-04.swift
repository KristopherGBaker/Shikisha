import Foundation
import Shikisha

// ... readFile, listFiles, editFile defined as before ...

let tools: [any Tool] = [readFile, listFiles, editFile]
let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let model = OpenAIChatModel(
    config: OpenAIConfig(apiKey: apiKey),
    model: "gpt-4o",
    tools: tools.map { $0.toOpenAISpec() }
)

// ConsoleCallback prints each model/tool event so you can watch the agent work.
let agent = ToolCallingAgent(
    model: model,
    tools: tools,
    maxIterations: 20,
    callbacks: CallbackManager(handlers: [ConsoleCallback()])
)

// Memory turns one-shot runs into a conversation: the agent remembers earlier turns.
let memory = BufferMemory()
try await memory.addMessage(
    SystemMessage(content: "You are a coding assistant working in the current directory.")
)

print("Coding agent ready. Describe a task (or type 'quit').")
while let line = readLine(), line != "quit" {
    try await memory.addMessage(HumanMessage(content: line))
    let result = try await agent.run(try await memory.messages())
    try await memory.addMessage(result.finalMessage)   // keep the answer for follow-ups
    print("\n\(result.finalMessage.content)\n")
}
