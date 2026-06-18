# Shikisha

[![CI](https://github.com/KristopherGBaker/Shikisha/actions/workflows/ci.yml/badge.svg)](https://github.com/KristopherGBaker/Shikisha/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/docs-krisbaker.com-FB8C0D?logo=swift&logoColor=white)](https://krisbaker.com/Shikisha/documentation/shikisha/)

A pure-Swift port of [LangChain](https://github.com/langchain-ai/langchain), targeting macOS and iOS via Swift Package Manager. Shikisha rebuilds the LangChain surface in idiomatic Swift 6.2 with structured concurrency, `Sendable` types, `AsyncSequence` streaming, and `Codable` wire shapes.

> Status: **0.1.0 — active development.**

> **Note (June 2026):** If you only target current Apple platforms, Apple's [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels) may be the better starting point. As of WWDC26 it covers sessions, typed structured output (`@Generable`), tool calling, and image input, and its public `LanguageModel` protocol can back a session with the on-device model, Private Cloud Compute, or third-party models. Shikisha still earns its place for older OS versions (macOS 14+ / iOS 17+), provider adapters that work today (OpenAI, Anthropic, Gemini, Ollama), the fuller retrieval stack (vector stores, BM25, hybrid retrievers, incremental indexing), `StateGraph` workflows, and offline testing with `FakeChatModel`.

## What's included

- **Runnables** — composable `pipe`-able units (`RunnableLambda`, `RunnableBranch`, parallel/sequence), the backbone every other piece plugs into.
- **Chat models** — provider adapters for OpenAI, Anthropic, Ollama, and Google Gemini, with streaming, tool calling, and a token-bucket rate limiter. Plus an optional on-device [Apple Foundation Models](#on-device-with-apple-foundation-models) backend, gated so it never raises the package floor.
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

Add `"Shikisha"` to any target that needs it. macOS 14+ / iOS 17+, Swift 6.2+.

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

## On-device with Apple Foundation Models

`FoundationModelsChatModel` runs Apple's on-device model privately — no API key, no network —
behind the same `ChatModel` protocol as every other provider:

```swift
if #available(macOS 26, iOS 26, *) {
    let model = FoundationModelsChatModel(config: FoundationModelsConfig(temperature: 0.7))

    for try await chunk in model.stream([HumanMessage(content: "Name three Japanese castles.")]) {
        print(chunk.content, terminator: "")
    }
}
```

It's gated to macOS 26 / iOS 26 (`#if canImport(FoundationModels)` plus `@available`), so it
never raises the package floor and adds no dependency — macOS 14+ / iOS 17+ consumers are
unaffected. See the [Chat Models guide](https://krisbaker.com/Shikisha/documentation/shikisha/chatmodels)
for details.

## Documentation

Full documentation is published to GitHub Pages:

**https://krisbaker.com/Shikisha/documentation/shikisha**

It includes:

- **Conceptual guides** — a [primer on LLM apps for Swift developers](https://krisbaker.com/Shikisha/documentation/shikisha/llmappprimer) (tokens, embeddings, RAG, agents…) and the [core `Runnable`/composition model](https://krisbaker.com/Shikisha/documentation/shikisha/coreconcepts).
- **Per-feature articles** — chat models, prompts, output parsers, structured output, documents, embeddings & vector stores, retrievers & RAG, memory, agents & tools, graphs, indexing, observability, and resilience — each with examples and when-to-use guidance.
- **Interactive tutorials** — build a streaming chatbot, a RAG app, a tool-using agent, a file-editing coding agent, and a universal (macOS/iOS) SwiftUI app around it, step by step.

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

A universal (macOS/iOS) SwiftUI sample app that puts a chat interface on the coding agent lives
in [`Examples/ChatApp`](Examples/ChatApp). Generate the Xcode project and open it:

```bash
make xcode   # requires xcodegen
open Shikisha.xcodeproj
```

Select the **ShikishaChat** scheme, then pick **My Mac** or an **iOS Simulator** from the
destination menu and run. (`ShikishaChat` is one universal target; the shared scheme is
generated by `make xcode`.) Set `OPENAI_API_KEY` in the scheme's environment to use a live
model — otherwise the app runs in demo mode.

## Build

```bash
make build   # swift build
make test    # swift test
make lint    # swiftlint --strict
make docs    # build the DocC site
make xcode   # regenerate Shikisha.xcodeproj (requires xcodegen)
```

Swift Package Manager is the primary workflow; the Xcode project is generated and git-ignored. `make lint` needs [SwiftLint](https://github.com/realm/SwiftLint) and `make xcode` needs [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install swiftlint xcodegen`).
