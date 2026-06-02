# Memory

Keep conversations going across stateless model calls.

## Overview

A chat model remembers nothing between calls — each `invoke` sees only the messages you pass.
*Memory* is where you store the running conversation and decide how much of it to replay each
turn. ``ChatMemory`` is the protocol: `addMessage(s)`, `messages()`, and `clear()`.

The challenge is the context window: histories grow, but you can't send unlimited tokens. The
different memory types are different answers to "what do we keep?"

### Choosing a memory

| Type | Keeps | Use when |
| --- | --- | --- |
| ``BufferMemory`` | everything | short sessions; you want the full history |
| ``BufferWindowMemory`` | the last *N* messages | bound size cheaply by message count |
| ``TokenBufferMemory`` | as many recent messages as fit a token budget | bound size precisely by tokens |
| ``ConversationSummaryMemory`` | a running summary of the conversation | long sessions where gist matters more than detail |
| ``ConversationSummaryBufferMemory`` | recent messages verbatim + a summary of older ones | best of both: detail recently, gist before |

For persistence across launches, ``JsonFileChatMemory`` and ``SqliteChatMemory`` save to disk.

### Basic use

```swift
let memory = BufferWindowMemory(windowSize: 10)

try await memory.addMessage(SystemMessage(content: "You are a travel assistant."))
try await memory.addMessages([
    HumanMessage(content: "I'm going to Kyoto."),
    AIMessage(content: "When are you visiting?")
])

let history = try await memory.messages()
```

### Wiring memory into a chain

Replay history through a `.placeholder` in your prompt (see <doc:Prompts>):

```swift
let prompt = ChatPromptTemplate.fromTuples([
    .system("You are a helpful assistant."),
    .placeholder("history"),
    .human("{question}")
])

func ask(_ question: String) async throws -> String {
    let history = try await memory.messages()
    let messages = try prompt.formatMessages(["history": history, "question": question])
    let reply = try await model.invoke(messages)
    try await memory.addMessages([HumanMessage(content: question), reply])
    return reply.content
}
```

### Summarizing long histories

Summary memories call a model to compress older turns. Construct them with the model to use:

```swift
let memory = ConversationSummaryBufferMemory(model: model, maxTokens: 1500)
// recent turns stay verbatim; once the budget is exceeded, older turns fold into a summary
```

### Persisting across launches

```swift
let memory = try SqliteChatMemory(file: dbURL, sessionID: "user-42")
// or: try JsonFileChatMemory(file: jsonURL)
```

### One-shot trimming

When you just need to fit an existing message list into a budget (without a stateful store),
use ``trimMessages(_:maxTokens:counter:strategy:pinSystemMessages:)``:

```swift
let fitted = trimMessages(allMessages, maxTokens: 2000, strategy: .last)
```

It keeps the most recent (`.last`) or earliest (`.first`) messages and, by default, pins system
messages so instructions are never dropped. Token counts come from a ``TokenCounter`` —
``ApproximateTokenCounter`` by default.

## Topics

### Protocol

- ``ChatMemory``

### In-memory

- ``BufferMemory``
- ``BufferWindowMemory``
- ``TokenBufferMemory``
- ``ConversationSummaryMemory``
- ``ConversationSummaryBufferMemory``

### Persistent

- ``JsonFileChatMemory``
- ``SqliteChatMemory``

### Token budgeting

- ``trimMessages(_:maxTokens:counter:strategy:pinSystemMessages:)``
- ``TokenCounter``
- ``ApproximateTokenCounter``

## See Also

- <doc:Prompts>
- <doc:ChatModels>
