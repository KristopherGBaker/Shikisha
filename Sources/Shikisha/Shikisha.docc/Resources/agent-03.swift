import Foundation
import Shikisha

struct AddArgs: Decodable { let a: Int; let b: Int }

let add = TypedTool(
    name: "add",
    description: "Add two integers and return the sum.",
    inputSchema: JSONSchema.object(
        properties: ["a": JSONSchema.integer(), "b": JSONSchema.integer()],
        required: ["a", "b"]
    ),
    execute: { (args: AddArgs) in String(args.a + args.b) }
)

let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let model = OpenAIChatModel(config: OpenAIConfig(apiKey: apiKey), model: "gpt-4o")
let agent = ToolCallingAgent(model: model, tools: [add], maxIterations: 6)
let result = try await agent.run([HumanMessage(content: "What is 137 plus 248?")])

// AgentResult exposes the final answer, how many loops it took, and the full transcript.
print("answer:     \(result.finalMessage.content)")
print("iterations: \(result.iterations)")

print("\n--- trace ---")
for message in result.trace {
    let body = message.content.isEmpty ? "<tool call>" : message.content
    print("[\(message.role.rawValue)] \(body)")
}
