# Getting Started

Install Shikisha, configure a model, and run your first chain.

## Overview

This guide takes you from an empty package to a working prompt-model-parser chain in a few
minutes. If the terminology is unfamiliar, read <doc:LLMAppPrimer> first.

### Add the package

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/KristopherGBaker/Shikisha.git", from: "0.1.0")
]
```

Then add `"Shikisha"` to any target that needs it. Shikisha requires macOS 14+ / iOS 17+ and
Swift 6.3+.

### Provide an API key

Hosted providers (OpenAI, Anthropic, Google) need an API key. Read it from the environment
rather than hard-coding it:

```swift
import Shikisha

let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let model = OpenAIChatModel(config: OpenAIConfig(apiKey: apiKey), model: "gpt-4o-mini")
```

> Tip: No API key handy? Use ``OllamaChatModel`` to run a local model, or ``FakeChatModel`` to
> return canned replies in tests and demos — every example in the repo runs offline this way.

### Your first chain

Compose a prompt, the model, and a parser, then invoke it:

```swift
let chain = ChatPromptTemplate.fromTuples([
    .system("You are a helpful assistant. Answer in one sentence."),
    .human("{question}")
])
.pipe(model)
.pipe(StringOutputParser())

let answer = try await chain.invoke(["question": "What is Swift Concurrency?"])
print(answer)
```

What happened:

1. The prompt template filled `{question}` and produced `[any Message]`.
2. The model turned those messages into an ``AIMessage``.
3. ``StringOutputParser`` extracted the reply text as a `String`.

See <doc:CoreConcepts> for how `pipe` and `|>` work.

### Stream the response

To render the reply as it arrives:

```swift
for try await chunk in model.stream([HumanMessage(content: "Write a haiku about Swift.")]) {
    print(chunk.content, terminator: "")
}
```

### Run the bundled examples

The repository includes runnable, offline examples:

```bash
swift run ShikishaExamples            # list them
swift run ShikishaExamples basicChain
swift run ShikishaExamples ragPipeline
```

Each maps to a topic in this documentation: `basicChain`, `streamingChat`, `structuredOutput`,
`toolAgent`, `ragPipeline`, `memoryConversation`, and `stateGraph`.

### Where to go next

- <doc:tutorials/Shikisha> — guided, step-by-step builds (chatbot, RAG, agent).
- <doc:ChatModels> — provider options, tool calling, and streaming in depth.
- <doc:Retrievers> — chat with your own data using RAG.
- <doc:AgentsAndTools> — let the model call your Swift functions.
