import Foundation

/// Wrap a plain async closure as a `Runnable`. The most common way to drop into
/// LCEL chains without writing a struct.
public struct RunnableLambda<Input: Sendable, Output: Sendable>: Runnable {
    private let body: @Sendable (Input) async throws -> Output

    public init(_ body: @Sendable @escaping (Input) async throws -> Output) {
        self.body = body
    }

    public func invoke(_ input: Input) async throws -> Output {
        try await body(input)
    }
}

/// Build a `Runnable<Input, Output>` from a sync closure. Convenience for the common case.
public func runnable<Input: Sendable, Output: Sendable>(
    _ body: @Sendable @escaping (Input) throws -> Output
) -> RunnableLambda<Input, Output> {
    RunnableLambda { input in try body(input) }
}

/// Build a `Runnable<Input, Output>` from an async closure.
public func asyncRunnable<Input: Sendable, Output: Sendable>(
    _ body: @Sendable @escaping (Input) async throws -> Output
) -> RunnableLambda<Input, Output> {
    RunnableLambda(body)
}
