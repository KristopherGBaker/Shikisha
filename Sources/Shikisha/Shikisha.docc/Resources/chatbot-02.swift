import Foundation
import Shikisha

let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let model = OpenAIChatModel(config: OpenAIConfig(apiKey: apiKey), model: "gpt-4o-mini")

// Stream the reply so the UI can render it as it arrives.
let messages: [any Message] = [
    SystemMessage(content: "You are a friendly assistant."),
    HumanMessage(content: "Give me three tips for learning Swift.")
]

var assembled = AIMessageChunk()
for try await chunk in model.stream(messages) {
    print(chunk.content, terminator: "")   // print each delta
    assembled += chunk                      // accumulate the full message
}
print("\n--- done ---")
let full = assembled.toAIMessage()
