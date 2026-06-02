import Foundation
import Shikisha

let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let model = OpenAIChatModel(config: OpenAIConfig(apiKey: apiKey), model: "gpt-4o-mini")

// Memory keeps the conversation; a placeholder replays it into the prompt each turn.
let memory = BufferWindowMemory(windowSize: 10)
let prompt = ChatPromptTemplate.fromTuples([
    .system("You are a friendly assistant."),
    .placeholder("history"),
    .human("{question}")
])

func ask(_ question: String) async throws -> String {
    let history = try await memory.messages()
    let messages = try prompt.formatMessages(["history": history, "question": question])

    var assembled = AIMessageChunk()
    for try await chunk in model.stream(messages) {
        print(chunk.content, terminator: "")
        assembled += chunk
    }
    print("")

    let reply = assembled.toAIMessage()
    try await memory.addMessages([HumanMessage(content: question), reply])
    return reply.content
}

_ = try await ask("I'm planning a trip to Kyoto.")
_ = try await ask("What should I pack?")   // the model remembers Kyoto
