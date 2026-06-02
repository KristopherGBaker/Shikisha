import Foundation
import Shikisha

/// An *agent* lets the model decide which of your Swift functions ("tools") to call, runs them,
/// feeds the results back, and repeats until it has a final answer. ``ToolCallingAgent`` drives
/// that loop for any tool-capable ``ChatModel``.
enum ToolAgentExample {
    struct AddArguments: Decodable {
        let a: Int
        let b: Int
    }

    static func run() async throws {
        // A strongly-typed tool: arguments are decoded into `AddArguments` for you.
        let add = TypedTool(
            name: "add",
            description: "Add two integers and return the sum.",
            inputSchema: JSONSchema.object(
                properties: [
                    "a": JSONSchema.integer(description: "First addend"),
                    "b": JSONSchema.integer(description: "Second addend")
                ],
                required: ["a", "b"]
            ),
            execute: { (args: AddArguments) in
                String(args.a + args.b)
            }
        )

        // A real model would emit these tool calls on its own. We script two turns:
        //   1) the model asks to call `add(7, 5)`
        //   2) after seeing the tool result, it answers in natural language.
        let model = FakeChatModel(responses: [
            AIMessage(content: "", toolCalls: [
                ToolCall(id: "call_1", name: "add", arguments: .object(["a": 7, "b": 5]))
            ]),
            AIMessage(content: "7 + 5 = 12.")
        ])

        let agent = ToolCallingAgent(model: model, tools: [add], maxIterations: 4)
        let result = try await agent.run([HumanMessage(content: "What is 7 plus 5?")])

        section("Final answer")
        print(result.finalMessage.content)
        print("\n(reached in \(result.iterations) iteration(s), \(result.trace.count) messages in the trace)")

        section("Trace")
        for message in result.trace {
            let preview = message.content.isEmpty ? "<tool call>" : message.content
            print("[\(message.role.rawValue)] \(preview)")
        }
    }
}
