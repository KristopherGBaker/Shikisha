import Foundation
import Testing
@testable import Shikisha

@Suite("Agents")
struct AgentTests {
    @Test func testToolCallingAgentLoopsUntilNoToolCalls() async throws {
        let echoTool = SimpleTool(
            name: "echo",
            description: "Echo input",
            inputSchema: JSONSchema.object(properties: ["text": JSONSchema.string()], required: ["text"])
        ) { args in
            args["text"]?.stringValue ?? ""
        }

        let firstResponse = AIMessage(
            content: "",
            toolCalls: [
                ToolCall(id: "call-1", name: "echo", arguments: .object(["text": .string("hi")]))
            ]
        )
        let finalResponse = AIMessage(content: "Echoed: hi")
        let model = FakeChatModel(modelName: "fake", responses: [firstResponse, finalResponse])

        let agent = ToolCallingAgent(model: model, tools: [echoTool], maxIterations: 4)
        let result = try await agent.run([HumanMessage(content: "say hi")])
        #expect(result.iterations == 2)
        #expect(result.finalMessage.content == "Echoed: hi")
    }

    @Test func testRecordingCallbackCapturesLifecycle() async throws {
        let callback = RecordingCallback()
        let model = FakeChatModel(
            modelName: "fake",
            responses: [AIMessage(content: "done")]
        )
        let manager = CallbackManager(handlers: [callback])
        // Manually drive the lifecycle since FakeChatModel doesn't dispatch callbacks.
        await manager.onLLMStart(model: model.modelName, messages: [HumanMessage(content: "hi")])
        let result = try await model.invoke([HumanMessage(content: "hi")])
        await manager.onLLMEnd(model: model.modelName, response: result)
        let events = await callback.events
        #expect(events.count == 2)
        if case .llmStart(_, let count) = events[0] { #expect(count == 1) } else { Issue.record("expected llmStart") }
        if case .llmEnd(_, let content) = events[1] {
            #expect(content == "done")
        } else {
            Issue.record("expected llmEnd")
        }
    }
}
