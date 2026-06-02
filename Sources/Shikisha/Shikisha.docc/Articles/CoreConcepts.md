# Core Concepts: Runnables and Composition

One protocol underlies the whole library. Learn it once and everything composes.

## Overview

Almost every type in Shikisha conforms to ``Runnable`` — an async function from an `Input` to
an `Output`:

```swift
public protocol Runnable<Input, Output>: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    func invoke(_ input: Input) async throws -> Output
}
```

Prompts (`[String: any Sendable] -> [any Message]`), chat models
(`[any Message] -> AIMessage`), parsers (`AIMessage -> String`), retrievers
(`String -> [Document]`), and entire chains are all `Runnable`. Because they share one shape,
they snap together like Combine operators or `Sequence` transforms.

This is Shikisha's version of LangChain's Expression Language (LCEL).

### Composing with `pipe`

`pipe(_:)` connects two runnables when the first one's `Output` matches the second one's
`Input`. The result is itself a `Runnable`, so you can keep chaining:

```swift
let chain = prompt            // [String: any Sendable] -> [any Message]
    .pipe(model)              // [any Message]          -> AIMessage
    .pipe(StringOutputParser()) // AIMessage            -> String
// chain: some Runnable<[String: any Sendable], String>

let text = try await chain.invoke(["question": "Why is the sky blue?"])
```

The types are checked at compile time: if the shapes don't line up, it won't build.

### The `|>` operator

`|>` is sugar for `pipe`, reading left to right:

```swift
let chain = prompt |> model |> StringOutputParser()
```

Use whichever reads better to you; they're identical.

### Inserting your own logic with `map`

`map(_:)` splices a plain async closure into a chain without defining a named type — handy for
small transforms:

```swift
let shouting = model
    .pipe(StringOutputParser())
    .map { $0.uppercased() }
```

For a reusable, named step, wrap the closure in ``RunnableLambda`` instead.

### Running over many inputs

Every `Runnable` gets `batch` and `batchParallel` for free:

```swift
let questions = [["question": "What is RAG?"], ["question": "What is an embedding?"]]
let answers   = try await chain.batch(questions)              // sequential
let fast      = try await chain.batchParallel(questions, maxConcurrent: 4) // concurrent
```

### Branching, mapping, and assigning

For control flow inside a chain, Shikisha provides:

- ``RunnableBranch`` — pick a branch based on a predicate (an if/else for runnables).
- ``RunnableMap`` — run several runnables on the same input and collect a dictionary of results
  (fan-out).
- ``RunnableAssign`` — add computed keys to a dictionary flowing through the chain.

See <doc:Resilience> for `withRetry` and `withFallbacks`, which also wrap any runnable.

### Type erasure

When you need to store runnables of differing concrete types together (e.g. a list of
fallbacks), wrap them in ``AnyRunnable``:

```swift
let candidates: [AnyRunnable<[any Message], AIMessage>] = [
    AnyRunnable(primaryModel),
    AnyRunnable(backupModel)
]
```

### Why this matters

Because everything is a `Runnable`, the same composition, batching, retry, and observability
tools work on a one-line prompt-and-parse chain *and* on a full RAG-plus-agent pipeline. You
learn the contract once.

## Topics

### Composition primitives

- ``Runnable``
- ``RunnableLambda``
- ``RunnableBranch``
- ``RunnableMap``
- ``RunnableAssign``
- ``AnyRunnable``

## See Also

- <doc:LLMAppPrimer>
- <doc:GettingStarted>
- <doc:Resilience>
