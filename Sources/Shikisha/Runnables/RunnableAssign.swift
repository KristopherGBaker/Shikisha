import Foundation

/// LCEL-style "assign": take an input dictionary, run each runnable over it,
/// and merge each result into the dictionary under its key. The result is a
/// new dictionary with the original keys plus the computed ones.
///
/// Typical use:
///
/// ```swift
/// let chain = RunnableAssign([
///     "context": AnyRunnable(retriever),
///     "rewritten": AnyRunnable(rewritePrompt.pipe(model).pipe(StringOutputParser()))
/// ])
///     .pipe(answerPrompt)
///     .pipe(model)
///     .pipe(StringOutputParser())
/// ```
public struct RunnableAssign: Runnable {
    public typealias Input = [String: any Sendable]
    public typealias Output = [String: any Sendable]

    private let computed: [(String, AnyRunnable<Input, any Sendable>)]

    public init(_ computed: [String: AnyRunnable<Input, any Sendable>]) {
        self.computed = computed.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    public func invoke(_ input: Input) async throws -> Output {
        try await withThrowingTaskGroup(of: (String, any Sendable).self) { group in
            for (key, runnable) in computed {
                group.addTask {
                    let value = try await runnable.invoke(input)
                    return (key, value)
                }
            }
            var merged = input
            for try await (key, value) in group {
                merged[key] = value
            }
            return merged
        }
    }
}
