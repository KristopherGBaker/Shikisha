# Shikisha

[![CI](https://github.com/KristopherGBaker/Shikisha/actions/workflows/ci.yml/badge.svg)](https://github.com/KristopherGBaker/Shikisha/actions/workflows/ci.yml)

A pure-Swift port of [LangChain](https://github.com/langchain-ai/langchain), targeting macOS and iOS via Swift Package Manager. Shikisha rebuilds the LangChain surface in idiomatic Swift 6.3 with structured concurrency, `Sendable` types, `AsyncSequence` streaming, and `Codable` wire shapes.

> Status: **0.1.0 — active development.**

## What's included

- **Runnables** — composable `pipe`-able units (`RunnableLambda`, `RunnableBranch`, parallel/sequence), the backbone every other piece plugs into.
- **Chat models** — provider adapters for OpenAI, Anthropic, Ollama, and Google Gemini, with streaming, tool calling, and a token-bucket rate limiter.
- **Prompts** — chat/string templates, few-shot, and example selectors (fixed and semantic-similarity).
- **Output parsers** — string, list, CSV, XML, regex, datetime, streaming JSON, plus self-fixing wrappers.
- **Documents** — loaders (text, Markdown, HTML, JSON, CSV, PDF) and text splitters (character, recursive).
- **Embeddings & vector stores** — in-memory, JSON-file, and SQLite-backed stores with metadata filtering.
- **Retrievers** — vector, BM25, hybrid (RRF), MMR, multi-query, parent-document, time-weighted, self-querying, and contextual compression, plus a RAG chain.
- **Memory** — in-memory and SQLite-backed chat history.
- **Agents & tools** — tool-calling agent loop with a typed tool protocol.
- **Graph** — a `StateGraph` for building cyclic, stateful workflows.
- **Indexing** — incremental document indexing with change detection.

## Install

```swift
dependencies: [
    .package(url: "https://github.com/KristopherGBaker/Shikisha.git", from: "0.1.0")
]
```

Add `"Shikisha"` to any target that needs it. macOS 14+ / iOS 17+, Swift 6.3+.

## Quick start

```swift
import Shikisha

let model = OpenAIChatModel(
    config: OpenAIConfig(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""),
    model: "gpt-4o-mini"
)

let prompt = ChatPromptTemplate.fromTuples([
    .system("Answer concisely."),
    .human("{question}")
])

let chain = prompt
    .pipe(model)
    .pipe(StringOutputParser())

let answer = try await chain.invoke(["question": "What is Swift Concurrency?"])
print(answer)
```

## Documentation

Full documentation is published to GitHub Pages:

**https://kristophergbaker.github.io/Shikisha/documentation/shikisha**

It includes:

- **Conceptual guides** — a [primer on LLM apps for Swift developers](https://kristophergbaker.github.io/Shikisha/documentation/shikisha/llmappprimer) (tokens, embeddings, RAG, agents…) and the [core `Runnable`/composition model](https://kristophergbaker.github.io/Shikisha/documentation/shikisha/coreconcepts).
- **Per-feature articles** — chat models, prompts, output parsers, structured output, documents, embeddings & vector stores, retrievers & RAG, memory, agents & tools, graphs, indexing, observability, and resilience — each with examples and when-to-use guidance.
- **Interactive tutorials** — build a streaming chatbot, a RAG app, and a tool-using agent step by step.

Built with [Swift-DocC](https://www.swift.org/documentation/docc/). Build it locally with:

```bash
make docs          # static site into ./docs
make docs-preview  # live preview server
```

## Examples

Runnable, offline examples (using `FakeChatModel` and local embeddings, so no API key is needed)
live in [`Examples/ShikishaExamples`](Examples/ShikishaExamples):

```bash
swift run ShikishaExamples              # list them
swift run ShikishaExamples basicChain
swift run ShikishaExamples ragPipeline
```

Available: `basicChain`, `streamingChat`, `structuredOutput`, `toolAgent`, `codingAgent`,
`ragPipeline`, `memoryConversation`, `stateGraph`.

## Build

```bash
make build   # swift build
make test    # swift test
make lint    # swiftlint --strict
make docs    # build the DocC site
make xcode   # regenerate Shikisha.xcodeproj (requires xcodegen)
```

Swift Package Manager is the primary workflow; the Xcode project is generated and git-ignored. `make lint` needs [SwiftLint](https://github.com/realm/SwiftLint) and `make xcode` needs [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install swiftlint xcodegen`).
