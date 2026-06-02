# Resilience: Retries, Fallbacks, Rate Limits, and Caching

Make LLM calls survive flaky networks, rate limits, and outages — and cost less.

## Overview

Provider APIs fail intermittently, enforce rate limits, and charge per call. Shikisha gives you
composable wrappers to handle all of it. Because they wrap any ``Runnable`` (or any
``ChatModel``), you bolt them on without changing your chain's logic.

### Retry with backoff

`withRetry(...)` re-runs a runnable on failure with exponential backoff and jitter:

```swift
let robust = chain.withRetry(maxAttempts: 4, initialDelay: .milliseconds(250))
let answer = try await robust.invoke(input)
```

Tune `multiplier`, `maxDelay`, and `jitter`; use the ``WithRetry`` initializer directly to pass
a `shouldRetry` predicate so you only retry transient errors (timeouts, 429/5xx) and fail fast
on others.

### Fallbacks

`withFallbacks(_:)` tries alternatives in order if the primary fails — for example, fall back to
a cheaper or different provider during an outage. The candidates are type-erased
``AnyRunnable``s sharing the primary's input/output:

```swift
let resilient = primaryModel.withFallbacks([
    AnyRunnable(backupModel),
    AnyRunnable(localModel)
])
```

Combine the two: retry each model a few times, and only then fall back.

### Rate limiting

``RateLimitedChatModel`` wraps a model with a token-bucket limiter over a sliding window —
capping requests per window and, optionally, tokens per window. Callers simply `await`; the
wrapper paces them:

```swift
let limited = RateLimitedChatModel(
    model,
    maxRequestsPerWindow: 60,
    maxTokensPerWindow: 90_000,
    window: .seconds(60)
)
```

Use it to stay under a provider's published limits when fanning out with `batchParallel` or many
concurrent users.

### Caching responses

``CachingChatModel`` memoizes replies by a content hash of (messages + model name), so identical
requests don't hit the API twice. Great for deterministic prompts, tests, and development:

```swift
let cached = CachingChatModel(model)                          // in-memory only
let persisted = CachingChatModel(
    model,
    storage: try FileChatCacheStorage(directory: cacheDir)    // survives restarts
)
```

Implement ``ChatCacheStorage`` to back the cache with your own KV store.

### Layering

The wrappers stack. A production model might be:

```swift
let production = RateLimitedChatModel(
    CachingChatModel(model),
    maxRequestsPerWindow: 60
).withFallbacks([AnyRunnable(backupModel)])
```

Reading inside-out: cache hits avoid calls; misses are rate-limited; if the primary still fails,
fall back. Pair with <doc:Observability> to watch retries and spend.

## Topics

### Runnable wrappers

- ``WithRetry``
- ``WithFallbacks``
- ``AnyRunnable``

### Model wrappers

- ``RateLimitedChatModel``
- ``CachingChatModel``
- ``ChatCacheStorage``
- ``FileChatCacheStorage``

## See Also

- <doc:CoreConcepts>
- <doc:ChatModels>
- <doc:Observability>
