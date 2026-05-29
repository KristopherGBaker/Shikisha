import Foundation

/// `if/elseif/else` for runnables. The first predicate that matches the input wins;
/// the matching branch's runnable handles the value. If no predicate matches, the
/// default branch runs.
public struct RunnableBranch<Input: Sendable, Output: Sendable>: Runnable {
    public typealias Predicate = @Sendable (Input) async throws -> Bool

    private let branches: [(predicate: Predicate, runnable: AnyRunnable<Input, Output>)]
    private let `default`: AnyRunnable<Input, Output>

    public init(
        branches: [(predicate: Predicate, runnable: AnyRunnable<Input, Output>)],
        default defaultBranch: AnyRunnable<Input, Output>
    ) {
        self.branches = branches
        self.`default` = defaultBranch
    }

    public func invoke(_ input: Input) async throws -> Output {
        for (predicate, runnable) in branches where try await predicate(input) {
            return try await runnable.invoke(input)
        }
        return try await `default`.invoke(input)
    }
}

/// Builder for `RunnableBranch`, providing a `runnableBranch { case(...) { ... } default(...) }`
/// syntax in a Swift-idiomatic way.
@resultBuilder
public enum BranchBuilder {
    public static func buildBlock<Input: Sendable, Output: Sendable>(
        _ components: BranchComponent<Input, Output>...
    ) -> [BranchComponent<Input, Output>] {
        components
    }
}

public struct BranchComponent<Input: Sendable, Output: Sendable>: Sendable {
    let predicate: @Sendable (Input) async throws -> Bool
    let runnable: AnyRunnable<Input, Output>
}

public func branchCase<Input: Sendable, Output: Sendable, R: Runnable>(
    when predicate: @Sendable @escaping (Input) async throws -> Bool,
    run runnable: R
) -> BranchComponent<Input, Output> where R.Input == Input, R.Output == Output {
    BranchComponent(predicate: predicate, runnable: AnyRunnable(runnable))
}

public extension RunnableBranch {
    init<R: Runnable>(
        @BranchBuilder _ build: () -> [BranchComponent<Input, Output>],
        default defaultRunnable: R
    ) where R.Input == Input, R.Output == Output {
        let components = build()
        self.init(
            branches: components.map { ($0.predicate, $0.runnable) },
            default: AnyRunnable(defaultRunnable)
        )
    }
}
