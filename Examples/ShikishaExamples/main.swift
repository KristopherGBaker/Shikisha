import Foundation

// A small command-line harness that runs each Shikisha example by name. Every example is
// written to run offline (using `FakeChatModel` and local embeddings) so you can explore the
// API without an API key. Where a real provider would be used, the code is shown in comments.
//
// Usage:
//   swift run ShikishaExamples <name>
//   swift run ShikishaExamples            # lists the available examples

let examples: [(name: String, summary: String, run: () async throws -> Void)] = [
    ("basicChain", "Compose a prompt, model, and parser into one runnable.", BasicChainExample.run),
    ("streamingChat", "Consume a model response token-by-token as an AsyncSequence.", StreamingChatExample.run),
    ("structuredOutput", "Decode a model response into a typed Swift value.", StructuredOutputExample.run),
    ("toolAgent", "Let a model call Swift functions in a tool-use loop.", ToolAgentExample.run),
    ("ragPipeline", "Retrieve relevant documents and answer a question (RAG).", RagPipelineExample.run),
    ("memoryConversation", "Persist and trim chat history across turns.", MemoryConversationExample.run),
    ("stateGraph", "Build a cyclic, stateful workflow with StateGraph.", StateGraphFlowExample.run)
]

let printUsage = {
    print("Shikisha examples — run one with: swift run ShikishaExamples <name>\n")
    let width = examples.map(\.name.count).max() ?? 0
    for example in examples {
        let padded = example.name.padding(toLength: width, withPad: " ", startingAt: 0)
        print("  \(padded)  \(example.summary)")
    }
}

let requested = CommandLine.arguments.dropFirst().first

guard let requested else {
    printUsage()
    exit(0)
}

guard let example = examples.first(where: { $0.name.caseInsensitiveCompare(requested) == .orderedSame }) else {
    print("Unknown example: \(requested)\n")
    printUsage()
    exit(1)
}

do {
    print("▶︎ \(example.name) — \(example.summary)\n")
    try await example.run()
} catch {
    print("Example failed: \(error)")
    exit(1)
}
