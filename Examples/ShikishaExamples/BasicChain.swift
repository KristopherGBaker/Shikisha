import Foundation
import Shikisha

/// The "hello world" of Shikisha: a prompt template, a chat model, and an output parser
/// composed into a single ``Runnable`` with `pipe`. Invoking the chain renders the prompt,
/// sends it to the model, and converts the reply into a plain `String`.
enum BasicChainExample {
    static func run() async throws {
        // A `ChatPromptTemplate` turns a dictionary of variables into chat messages.
        let prompt = ChatPromptTemplate.fromTuples([
            .system("You are a helpful assistant who answers in one short sentence."),
            .human("Explain {topic} to a Swift developer.")
        ])

        // Offline stand-in for a real provider. Swap in `OpenAIChatModel`, `AnthropicChatModel`,
        // `GoogleChatModel`, or `OllamaChatModel` to talk to a live model.
        let model = FakeChatModel(
            responses: [
                AIMessage(content: "An embedding maps text to a vector so similar text sits nearby.")
            ],
            default: AIMessage(content: "(a one-sentence explanation from the model)")
        )

        // `prompt |> model |> parser` is the same as `prompt.pipe(model).pipe(parser)`.
        let chain = prompt
            .pipe(model)
            .pipe(StringOutputParser())

        let answer = try await chain.invoke(["topic": "embeddings"])
        section("Answer")
        print(answer)

        // `batch` runs the same chain over many inputs; `batchParallel` does so concurrently.
        section("Batch")
        let topics = ["vectors", "retrieval", "agents"]
        let answers = try await chain.batch(topics.map { ["topic": $0] })
        for (topic, answer) in zip(topics, answers) {
            print("\(topic): \(answer)")
        }
    }
}
