import Foundation

/// Run a set of named runnables in parallel over the same input, gathering results
/// into a `[String: Any]` map. Mirrors LangChain's `RunnableParallel` / `RunnableMap`.
///
/// `Output` is `[String: Any]` because each branch can return a different concrete
/// type; downstream consumers cast back as needed. The branches themselves remain
/// type-checked through `AnyRunnable`.
public struct RunnableMap<Input: Sendable>: Runnable {
    private let branches: [(String, AnyRunnable<Input, any Sendable>)]

    public init(_ branches: [String: AnyRunnable<Input, any Sendable>]) {
        // Stable iteration order so streaming consumers see a consistent shape.
        self.branches = branches.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    public func invoke(_ input: Input) async throws -> [String: any Sendable] {
        try await withThrowingTaskGroup(of: (String, any Sendable).self) { group in
            for (key, runnable) in branches {
                group.addTask {
                    let value = try await runnable.invoke(input)
                    return (key, value)
                }
            }
            var collected: [String: any Sendable] = [:]
            for try await (key, value) in group {
                collected[key] = value
            }
            return collected
        }
    }
}

/// Type-erased runnable. Use sparingly — only when heterogeneity matters, e.g.
/// `RunnableMap` collecting branches of different concrete types.
public struct AnyRunnable<Input: Sendable, Output: Sendable>: Runnable {
    private let body: @Sendable (Input) async throws -> Output

    public init<R: Runnable>(_ runnable: R) where R.Input == Input, R.Output == Output {
        self.body = runnable.invoke
    }

    public init(_ body: @Sendable @escaping (Input) async throws -> Output) {
        self.body = body
    }

    public func invoke(_ input: Input) async throws -> Output {
        try await body(input)
    }
}
