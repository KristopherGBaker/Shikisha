# Graphs: Stateful Workflows

Model loops, branches, and retries that a straight chain can't express.

## Overview

A `pipe` chain runs once, front to back. Many real workflows don't: they loop until a condition
holds, branch on intermediate results, or revisit earlier steps (plan → act → reflect; "retry
until the output validates"; multi-agent hand-offs). ``StateGraph`` models these as named
**nodes** that transform a shared **state**, connected by **edges** — including *conditional*
edges that choose the next node at runtime.

`StateGraph` is an `actor`, so its state transitions are concurrency-safe.

### Anatomy

- A **node** is `(State) async throws -> State` — it reads the state and returns the next state.
- An **edge** always goes from one node to another.
- A **conditional edge** is a router `(State) -> String` that returns the *name* of the next node.
- One node is the **entry**; one or more are marked **finish** (terminal).

### A loop

This graph increments a counter until it reaches a threshold, then finishes:

```swift
struct Counter: Sendable { var value: Int }

let graph = StateGraph<Counter>()

await graph.addNode("increment") { state in
    var next = state
    next.value += 1
    return next
}
await graph.addNode("done") { $0 }

// Loop back to "increment" until value reaches 3, then go to "done".
await graph.addConditionalEdge(from: "increment") { state in
    state.value < 3 ? "increment" : "done"
}

await graph.setEntry("increment")
await graph.addFinish("done")

let result = try await graph.run(initial: Counter(value: 0))   // result.value == 3
```

`run(initial:maxSteps:)` executes from the entry node until it reaches a finish node or hits
`maxSteps` (a safety cap against infinite loops).

### When to reach for a graph

- **Retry/validate loops** — a node generates output, a conditional edge routes back if it fails
  validation. Pair with structured output (<doc:StructuredOutput>).
- **Branching pipelines** — different node paths for different input types.
- **Agentic workflows** — plan/act/reflect cycles, or routing between specialized sub-agents,
  where you want explicit control over the loop rather than the built-in
  ``ToolCallingAgent`` loop.

Keep your `State` a `Sendable` value type and put everything a step needs (history, scratch
data, counters) inside it.

### Static graph analysis

``TransitionGraph`` is a lightweight, generic directed graph (nodes + transitions) with
`neighbors(of:)` and `hasPath(from:to:)` — useful for validating reachability or modeling a
state machine independent of execution.

## Topics

### Execution

- ``StateGraph``

### Analysis

- ``TransitionGraph``

## See Also

- <doc:AgentsAndTools>
- <doc:CoreConcepts>
