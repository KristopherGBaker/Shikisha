# Observability: Callbacks, Usage, and Cost

See what your chains do, and what they cost.

## Overview

LLM pipelines are easy to get working and hard to *see into* — which model ran, what it
returned, how many tokens it burned, which tools fired. Shikisha's ``Callback`` protocol gives
you lifecycle hooks for models, tools, and agents. Bundle handlers in a ``CallbackManager`` and
pass it to a model or agent.

The protocol's methods (`onLLMStart/End/Error`, `onToolStart/End/Error`, `onAgentIteration`,
`onAgentEnd`) all have default no-op implementations, so a custom handler only overrides what it
cares about.

### Logging to the console

```swift
let model = OpenAIChatModel(
    config: cfg,
    model: "gpt-4o-mini",
    callbacks: CallbackManager(handlers: [ConsoleCallback()])
)
```

``ConsoleCallback`` prints each model/tool event as it happens — the fastest way to watch a run.

### Structured tracing

``TracingCallback`` emits one JSON line per event to a sink you provide — pipe it to a file, a
logging backend, or your own viewer:

```swift
let tracer = TracingCallback { line in await myLogStore.append(line) }
let manager = CallbackManager(handlers: [tracer])
```

### Capturing events in tests

``RecordingCallback`` (an actor) stores every event so tests can assert on them:

```swift
let recorder = RecordingCallback()
let agent = ToolCallingAgent(model: model, tools: tools,
                             callbacks: CallbackManager(handlers: [recorder]))
_ = try await agent.run(messages)
#expect(await recorder.events.contains { /* a tool fired */ })
```

### Tracking token usage

``UsageTrackerCallback`` accumulates ``UsageMetadata`` per model and in total:

```swift
let usage = UsageTrackerCallback()
let model = OpenAIChatModel(config: cfg, model: "gpt-4o-mini",
                            callbacks: CallbackManager(handlers: [usage]))
// ... run chains ...
let snapshot = await usage.snapshot()
print(snapshot.total.totalTokens, snapshot.perModel)
```

### Tracking cost

``CostTrackerCallback`` multiplies usage by per-model pricing to estimate spend. Give it a
price table (USD per million tokens):

```swift
let cost = CostTrackerCallback(pricing: [
    "gpt-4o-mini": ModelPricing(inputPerMTok: 0.15, outputPerMTok: 0.60)
])
let model = OpenAIChatModel(config: cfg, model: "gpt-4o-mini",
                            callbacks: CallbackManager(handlers: [cost]))
// ...
let snapshot = await cost.snapshot()
print("$\(snapshot.totalCost)", snapshot.perModelCost)
```

``ModelPricing`` also takes cache read/write rates for providers that bill prompt caching
separately.

### Combining handlers

A `CallbackManager` holds many handlers; compose them and reuse across calls:

```swift
let manager = CallbackManager(handlers: [ConsoleCallback(), usage, cost])
    .appending(tracer)
```

## Topics

### Protocol

- ``Callback``
- ``CallbackManager``

### Handlers

- ``ConsoleCallback``
- ``TracingCallback``
- ``RecordingCallback``
- ``UsageTrackerCallback``
- ``CostTrackerCallback``
- ``ModelPricing``

## See Also

- <doc:ChatModels>
- <doc:AgentsAndTools>
