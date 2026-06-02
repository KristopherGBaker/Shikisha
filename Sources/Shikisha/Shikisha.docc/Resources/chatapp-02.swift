import Foundation
import Shikisha

/// The chat engine: a `@MainActor`, `@Observable` view model that owns the agent and the
/// conversation. Keep ALL Shikisha wiring here so the SwiftUI views stay trivial.
@MainActor
@Observable
final class AgentChat {
    private(set) var items: [ChatItem] = []
    var input: String = ""
    private(set) var isRunning = false
    private(set) var statusNote: String?

    private let agent: ToolCallingAgent
    private var history: [any Message]   // replayed each turn — this is the agent's memory

    init() {
        // A writable sandbox in the app's Documents directory, seeded with a starter file.
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = documents.appendingPathComponent("AgentSandbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        // AgentTools.fileTools is the read_file / list_files / edit_file set from the
        // "Build a Coding Agent" tutorial, scoped to `root`.
        let tools = AgentTools.fileTools(root: root)

        let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        let model: any ChatModel
        if key.isEmpty {
            statusNote = "No OPENAI_API_KEY set — demo mode. Set the key to enable the live agent."
            model = FakeChatModel(default: AIMessage(content: "I'm a demo. Set OPENAI_API_KEY to enable the agent."))
        } else {
            // A tool-capable model must be built WITH the tool specs so it can emit tool calls.
            model = OpenAIChatModel(
                config: OpenAIConfig(apiKey: key),
                model: "gpt-4o",
                tools: tools.map { $0.toOpenAISpec() }
            )
        }

        self.agent = ToolCallingAgent(model: model, tools: tools, maxIterations: 20)
        self.history = [SystemMessage(content: "You are a coding assistant working in the app's sandbox.")]
    }

    func send() async {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isRunning else { return }

        input = ""
        items.append(ChatItem(kind: .user, text: prompt))
        history.append(HumanMessage(content: prompt))
        isRunning = true
        defer { isRunning = false }

        do {
            let priorCount = history.count
            let result = try await agent.run(history)
            // Surface the tools the agent used this turn so its actions are visible.
            for message in result.trace.dropFirst(priorCount) {
                guard let ai = message as? AIMessage else { continue }
                for call in ai.toolCalls {
                    items.append(ChatItem(kind: .tool, text: "\(call.name)(\(call.arguments.serialized()))"))
                }
            }
            items.append(ChatItem(kind: .assistant, text: result.finalMessage.content))
            history.append(result.finalMessage)
        } catch {
            items.append(ChatItem(kind: .assistant, text: "Error: \(error.localizedDescription)"))
        }
    }
}
