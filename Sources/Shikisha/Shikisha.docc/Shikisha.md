# ``Shikisha``

Build LLM-powered features in pure Swift — a Swift port of LangChain for macOS and iOS.

## Overview

Shikisha gives you the building blocks for working with large language models (LLMs) from
Swift: chat models, prompt templates, output parsers, document loaders, embeddings, vector
stores, retrievers, memory, tool-using agents, and stateful graphs. Everything is built on
one small protocol — ``Runnable`` — and composes with a `pipe` operator, so a whole pipeline
reads top to bottom:

```swift
import Shikisha

let model = OpenAIChatModel(
    config: OpenAIConfig(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""),
    model: "gpt-4o-mini"
)

let chain = ChatPromptTemplate.fromTuples([
    .system("Answer concisely."),
    .human("{question}")
])
.pipe(model)
.pipe(StringOutputParser())

let answer = try await chain.invoke(["question": "What is Swift Concurrency?"])
```

Shikisha is idiomatic Swift 6: `Sendable` types, structured concurrency, `AsyncSequence`
streaming, and `Codable` wire shapes throughout.

> Tip: **New to AI tooling?** Start with <doc:LLMAppPrimer> for a plain-Swift tour of the
> concepts (tokens, embeddings, RAG, agents…), then read <doc:CoreConcepts> to understand how
> the pieces fit together.

## Topics

### Essentials

- <doc:LLMAppPrimer>
- <doc:CoreConcepts>
- <doc:GettingStarted>

### Tutorials

- <doc:tutorials/Shikisha>

### Talking to models

- <doc:ChatModels>
- <doc:Prompts>
- <doc:OutputParsers>
- <doc:StructuredOutput>

### Working with your data

- <doc:Documents>
- <doc:EmbeddingsAndVectorStores>
- <doc:Retrievers>
- <doc:Indexing>

### Building applications

- <doc:Memory>
- <doc:AgentsAndTools>
- <doc:Graphs>

### Production concerns

- <doc:Observability>
- <doc:Resilience>

### Core protocols

- ``Runnable``
- ``ChatModel``
- ``Retriever``
- ``VectorStore``
- ``Embeddings``
- ``Tool``
- ``ChatMemory``
- ``Callback``

### Messages

- ``Message``
- ``SystemMessage``
- ``HumanMessage``
- ``AIMessage``
- ``ToolMessage``
- ``AIMessageChunk``
- ``ToolCall``
- ``UsageMetadata``
