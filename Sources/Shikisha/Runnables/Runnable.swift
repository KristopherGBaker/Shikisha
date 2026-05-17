import Foundation

/// The core composition primitive — anything that turns an `Input` into an `Output`
/// asynchronously. Chat models, prompts, parsers, retrievers, and chains all conform.
///
/// LCEL-style composition is provided via `pipe` and the `|>` operator.
public protocol Runnable<Input, Output>: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable

    func invoke(_ input: Input) async throws -> Output
}

public extension Runnable {
    /// Compose `self` with another runnable: `(a.pipe(b)).invoke(x) == b.invoke(a.invoke(x))`.
    func pipe<R: Runnable>(_ next: R) -> some Runnable<Input, R.Output> where R.Input == Output {
        PipeRunnable(first: self, second: next)
    }

    /// Compose with a plain async closure — handy when you don't need a named runnable.
    func map<NewOutput: Sendable>(
        _ transform: @Sendable @escaping (Output) async throws -> NewOutput
    ) -> some Runnable<Input, NewOutput> {
        pipe(RunnableLambda(transform))
    }

    /// Run on each element of a sequence input, in order. Mirrors LangChain's `.batch`.
    func batch(_ inputs: [Input]) async throws -> [Output] {
        var results: [Output] = []
        results.reserveCapacity(inputs.count)
        for input in inputs {
            try results.append(await invoke(input))
        }
        return results
    }

    /// Same as `batch` but launches each call concurrently.
    func batchParallel(_ inputs: [Input], maxConcurrent: Int = 8) async throws -> [Output] {
        precondition(maxConcurrent > 0, "maxConcurrent must be > 0")
        return try await withThrowingTaskGroup(of: (Int, Output).self) { group in
            var results: [Output?] = [Output?](repeating: nil, count: inputs.count)
            var iterator = inputs.enumerated().makeIterator()
            var inFlight = 0
            while let (index, input) = iterator.next() {
                while inFlight >= maxConcurrent {
                    if let (resultIndex, value) = try await group.next() {
                        results[resultIndex] = value
                        inFlight -= 1
                    }
                }
                group.addTask {
                    let value = try await invoke(input)
                    return (index, value)
                }
                inFlight += 1
            }
            for try await (index, value) in group {
                results[index] = value
            }
            return results.compactMap { $0 }
        }
    }
}

/// `a |> b` reads left-to-right as a pipeline; equivalent to `a.pipe(b)`.
infix operator |>: AdditionPrecedence

public func |> <First: Runnable, Second: Runnable>(
    lhs: First,
    rhs: Second
) -> some Runnable<First.Input, Second.Output> where First.Output == Second.Input {
    lhs.pipe(rhs)
}

struct PipeRunnable<First: Runnable, Second: Runnable>: Runnable
where First.Output == Second.Input {
    let first: First
    let second: Second

    func invoke(_ input: First.Input) async throws -> Second.Output {
        try await second.invoke(first.invoke(input))
    }
}
