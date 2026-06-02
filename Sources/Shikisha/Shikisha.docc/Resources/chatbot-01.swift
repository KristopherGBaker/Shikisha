import Foundation
import Shikisha

// Read your API key from the environment — never hard-code secrets.
let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let model = OpenAIChatModel(config: OpenAIConfig(apiKey: apiKey), model: "gpt-4o-mini")

// A chat model maps a list of messages to a single reply.
let reply = try await model.invoke([
    SystemMessage(content: "You are a friendly assistant."),
    HumanMessage(content: "Say hello in Japanese.")
])
print(reply.content)
