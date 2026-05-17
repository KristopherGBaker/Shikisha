# Shikisha

A pure-Swift port of [LangChain](https://github.com/langchain-ai/langchain), targeting macOS and iOS via Swift Package Manager. Born out of [kmpchain](https://github.com/KristopherGBaker/kmpchain) (Kotlin Multiplatform), Shikisha rebuilds the same surface in idiomatic Swift 6.3 with structured concurrency, `Sendable` types, `AsyncSequence` streaming, and `Codable` wire shapes — no Kotlin/Native runtime, no XCFramework, no `KotlinDouble` boxing.

> Status: **0.1.0 — active development.**

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

## Build

```bash
make build   # swift build
make test    # swift test
make lint    # swiftlint
make xcode   # regenerate Shikisha.xcodeproj
```

## License

MIT (matches LangChain).
