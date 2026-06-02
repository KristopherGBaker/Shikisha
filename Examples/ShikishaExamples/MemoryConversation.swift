import Foundation
import Shikisha

/// Models are stateless — they only know what's in the messages you send. *Memory* keeps the
/// running conversation so each new turn includes the relevant history. This example uses a
/// sliding-window buffer and shows how to trim history to a token budget.
enum MemoryConversationExample {
    static func run() async throws {
        // Keep only the last few messages so the context never grows without bound. Other options:
        // `BufferMemory` (everything), `TokenBufferMemory` (by token budget),
        // `ConversationSummaryMemory` (summarize older turns), and disk-backed variants
        // (`JsonFileChatMemory`, `SqliteChatMemory`).
        let memory = BufferWindowMemory(windowSize: 4)

        try await memory.addMessage(SystemMessage(content: "You are a travel assistant."))
        try await memory.addMessages([
            HumanMessage(content: "I'm going to Kyoto."),
            AIMessage(content: "Great choice! When are you visiting?"),
            HumanMessage(content: "In November."),
            AIMessage(content: "Autumn leaves in Kyoto are stunning in November.")
        ])

        section("Windowed history (last 4 messages)")
        let history = try await memory.messages()
        for message in history {
            print("[\(message.role.rawValue)] \(message.content)")
        }

        // `trimMessages` is a one-shot helper for fitting any message list into a token budget,
        // keeping the most recent turns and (by default) pinning system messages.
        section("Trimmed to a token budget")
        let trimmed = trimMessages(history, maxTokens: 40, strategy: .last)
        for message in trimmed {
            print("[\(message.role.rawValue)] \(message.content)")
        }
    }
}
