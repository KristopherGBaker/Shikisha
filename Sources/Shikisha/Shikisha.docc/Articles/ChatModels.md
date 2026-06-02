# Chat Models

Talk to OpenAI, Anthropic, Google Gemini, or a local Ollama model through one protocol.

## Overview

A chat model takes a list of messages and returns one reply. In Shikisha that's the
``ChatModel`` protocol — `Runnable<[any Message], AIMessage>` plus a `stream(_:)` method. Each
provider ships as a struct you configure with an API key and a model name; because they all
conform to ``ChatModel``, your chains don't care which one you use.

**When to use which:**

- ``OpenAIChatModel`` / ``AnthropicChatModel`` / ``GoogleChatModel`` — hosted, most capable;
  need an API key.
- ``OllamaChatModel`` — runs models locally; great for offline dev, privacy, and zero cost.
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
- ``FakeChatModel``

### Wrappers

- ``RateLimitedChatModel``
- ``CachingChatModel``

## See Also

- <doc:Prompts>
- <doc:OutputParsers>
- <doc:StructuredOutput>
- <doc:AgentsAndTools>
