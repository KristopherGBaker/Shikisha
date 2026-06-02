import Foundation
import Shikisha

/// The chat engine: a `@MainActor`, `@Observable` view model that owns the agent and the
/// conversation. SwiftUI observes its properties and re-renders as they change.
///
/// Keeping all the Shikisha wiring here (and none in the views) makes the UI trivial and the
/// agent logic testable on its own.
@MainActor
@Observable
final class AgentChat {
    /// The transcript shown in the UI.
    private(set) var items: [ChatItem] = []
    /// Bound to the text field.
    var input: String = ""
    /// True while a turn is in flight, so the UI can show progress and disable input.
    private(set) var isRunning = false
    /// A one-line banner (e.g. "set OPENAI_API_KEY"), or nil.
    private(set) var statusNote: String?

    private let agent: ToolCallingAgent
    /// The full message history replayed to the agent each turn (this is the agent's memory).
    private var history: [any Message]

    init() {
        // A writable sandbox in the app's Documents directory, seeded with a starter file.
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = documents.appendingPathComponent("AgentSandbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let seed = root.appendingPathComponent("README.md")
        if !FileManager.default.fileExists(atPath: seed.path) {
            try? "# Sandbox\n\nAsk the agent to read, list, or edit files here.\n"
                .write(to: seed, atomically: true, encoding: .utf8)
        }

        let tools = AgentTools.fileTools(root: root)

        // Use a live model when a key is present; otherwise fall back to a demo model so the app
        // still launches and explains how to enable the real agent.
        let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        let model: any ChatModel
        if key.isEmpty {
            statusNote = "No OPENAI_API_KEY set — running in demo mode. Set the key to enable the live agent."
            model = FakeChatModel(default: AIMessage(
                content: "I'm a demo response. Set OPENAI_API_KEY in the scheme's environment to enable the real agent."
            ))
        } else {
            // A tool-capable model must be built WITH the tool specs so it can emit tool calls.
            model = OpenAIChatModel(
                config: OpenAIConfig(apiKey: key),
                model: "gpt-4o",
                tools: tools.map { $0.toOpenAISpec() }
            )
        }

        self.agent = ToolCallingAgent(model: model, tools: tools, maxIterations: 20)
        self.history = [
            SystemMessage(content: "You are a coding assistant working inside the app's sandbox folder.")
        ]
    }

    /// Run one turn: append the user's message, drive the agent, then surface the tool calls it
    /// made and its final answer.
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

            // Show each tool the agent invoked this turn, so its actions are visible.
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
