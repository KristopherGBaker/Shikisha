# Chat Models

Talk to OpenAI, Anthropic, Google Gemini, a local Ollama model, or Apple's on-device
Foundation Models through one protocol.

## Overview

A chat model takes a list of messages and returns one reply. In Shikisha that's the
``ChatModel`` protocol — `Runnable<[any Message], AIMessage>` plus a `stream(_:)` method. Each
provider ships as a struct you configure with an API key and a model name; because they all
conform to ``ChatModel``, your chains don't care which one you use.

**When to use which:**

- ``OpenAIChatModel`` / ``AnthropicChatModel`` / ``GoogleChatModel`` — hosted, most capable;
  need an API key.
- ``OllamaChatModel`` — runs models locally; great for offline dev, privacy, and zero cost.
- ``FoundationModelsChatModel`` — Apple's on-device model; fully private, no API key, no
  network. Gated to macOS 26 / iOS 26 (see *On-device with Foundation Models* below).
- ``FakeChatModel`` — canned replies for tests and offline demos.

### Creating a model

In the snippets below, `env("KEY")` is shorthand for
`ProcessInfo.processInfo.environment["KEY"] ?? ""` — read keys from the environment, never
hard-code them.

```swift
let openAI = OpenAIChatModel(
    config: OpenAIConfig(apiKey: env("OPENAI_API_KEY")),
    model: "gpt-4o-mini",
    temperature: 0.2
)

let claude = AnthropicChatModel(
    config: AnthropicConfig(apiKey: env("ANTHROPIC_API_KEY")),
    model: "claude-sonnet-4-6",
    maxTokens: 1024
)

let gemini = GoogleChatModel(
    config: GoogleConfig(apiKey: env("GOOGLE_API_KEY")),
    model: "gemini-2.0-flash"
)

let local = OllamaChatModel(model: "llama3.1")   // defaults to http://localhost:11434
```

`OpenAIConfig`, `AnthropicConfig`, and `GoogleConfig` let you override `baseURL` and add custom
headers — useful for proxies or Azure/OpenAI-compatible gateways.

### On-device with Foundation Models

``FoundationModelsChatModel`` runs Apple's on-device model privately — no API key, no base
URL, no network. It conforms to ``ChatModel`` like every other provider, so it drops into the
same chains, prompts, and streaming consumers; swapping ``OpenAIChatModel`` for it needs no
other code changes.

Apple's FoundationModels framework is macOS 26 / iOS 26 only. To keep Shikisha's package
floor at macOS 14 / iOS 17 and its zero-dependency story intact, the type is compiled only
where the SDK is present (`#if canImport(FoundationModels)`) and is annotated
`@available(macOS 26, iOS 26, *)`. Older toolchains exclude it entirely; macOS 14 / iOS 17
consumers are unaffected because the type simply isn't there. It adds no external dependency
— FoundationModels is a weak-linked system framework, so the backend stays in the default
`Shikisha` product.

```swift
if #available(macOS 26, iOS 26, *) {
    let onDevice = FoundationModelsChatModel(
        config: FoundationModelsConfig(temperature: 0.7)
    )

    for try await chunk in onDevice.stream([
        SystemMessage(content: "Answer concisely."),
        HumanMessage(content: "Name three Japanese castles.")
    ]) {
        print(chunk.content, terminator: "")
    }
}
```

``SystemMessage``s become the `LanguageModelSession` instructions; the latest human turn
(plus any prior turns as transcript context) becomes the prompt. When the on-device model
isn't available — `SystemLanguageModel.default.availability` is not `.available` — the call
finishes with a ``FoundationModelsError/unavailable(reason:)`` error, mirroring how the HTTP
providers surface failure. Tool-calling is out of scope for v1.

### Invoking

```swift
let reply = try await claude.invoke([
    SystemMessage(content: "You are a terse assistant."),
    HumanMessage(content: "Name three Japanese castles.")
])
print(reply.content)
print(reply.usageMetadata?.totalTokens ?? 0)   // token accounting, when the provider reports it
```

Because a model is a `Runnable`, pipe a prompt into it and a parser out of it — see
<doc:CoreConcepts>.

### Streaming

`stream(_:)` returns an `AsyncThrowingStream` of ``AIMessageChunk`` deltas. Print them as they
arrive, and reassemble the full message with `+` or the `collect()` helper:

```swift
var assembled = AIMessageChunk()
for try await chunk in gemini.stream(messages) {
    print(chunk.content, terminator: "")
    assembled += chunk
}
let full: AIMessage = assembled.toAIMessage()
```

### Multimodal input (images)

``HumanMessage`` accepts attachments, so you can send images to vision-capable models:

```swift
let message = HumanMessage(
    content: "What's in this image?",
    attachments: [.imageURL(url: "https://example.com/cat.jpg")]
)
// or from local data:
let inline = HumanMessage(
    content: "Describe this.",
    attachments: [.imageData(pngData, mediaType: "image/png", detail: .high)]
)
```

### Tool calling

To let a model request that your functions run, pass tool specs at construction. The spec shape
differs per provider, and the easiest path is to define a ``Tool`` and convert it:

```swift
let weather = SimpleTool(
    name: "get_weather",
    description: "Look up the current weather for a city.",
    inputSchema: JSONSchema.object(
        properties: ["city": JSONSchema.string()],
        required: ["city"]
    ),
    execute: { args in "Sunny in \(args["city"]?.stringValue ?? "?")" }
)

// Per-provider specs:
let openAIWithTools = OpenAIChatModel(config: cfg, model: "gpt-4o", tools: [weather.toOpenAISpec()])
let claudeWithTools = AnthropicChatModel(config: cfg, model: "claude-sonnet-4-6",
                                         tools: [weather.toAnthropicSpec()])
let geminiWithTools = GoogleChatModel(config: cfg, model: "gemini-2.0-flash",
                                      tools: [weather.toGoogleSpec()])
```

The reply's ``AIMessage/toolCalls`` array tells you which tools the model wants to run. In
practice you let an agent drive that loop for you — see <doc:AgentsAndTools>.

### Resilience and caching

Any model can be wrapped: ``RateLimitedChatModel`` for token-bucket rate limiting,
``CachingChatModel`` to memoize identical requests, and `withRetry` / `withFallbacks` from
<doc:Resilience>.

## Topics

### Protocol

- ``ChatModel``

### Providers

- ``OpenAIChatModel``
- ``OpenAIConfig``
- ``AnthropicChatModel``
- ``AnthropicConfig``
- ``GoogleChatModel``
- ``GoogleConfig``
- ``OllamaChatModel``
- ``OllamaConfig``
- ``FoundationModelsChatModel``
- ``FoundationModelsConfig``
- ``FoundationModelsError``
- ``FakeChatModel``

### Wrappers

- ``RateLimitedChatModel``
- ``CachingChatModel``

## See Also

- <doc:Prompts>
- <doc:OutputParsers>
- <doc:StructuredOutput>
- <doc:AgentsAndTools>
