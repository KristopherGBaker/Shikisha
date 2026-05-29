import Foundation

/// A token-bucket rate limiter wrapped around any `ChatModel`. Limits both
/// requests-per-window and (optionally) tokens-per-window using a sliding-window
/// approach.
public actor RateLimitedChatModel<Wrapped: ChatModel>: ChatModel {
    public nonisolated var modelName: String { wrapped.modelName }

    private let wrapped: Wrapped
    private let maxRequestsPerWindow: Int
    private let maxTokensPerWindow: Int?
    private let window: Duration
    private let counter: any TokenCounter
    private let clock: any Clock<Duration>

    private var requestTimestamps: [Date] = []
    private var tokenSpends: [(Date, Int)] = []

    public init(
        _ wrapped: Wrapped,
        maxRequestsPerWindow: Int,
        maxTokensPerWindow: Int? = nil,
        window: Duration = .seconds(60),
        counter: any TokenCounter = ApproximateTokenCounter(),
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        precondition(maxRequestsPerWindow > 0, "maxRequestsPerWindow must be > 0")
        self.wrapped = wrapped
        self.maxRequestsPerWindow = maxRequestsPerWindow
        self.maxTokensPerWindow = maxTokensPerWindow
        self.window = window
        self.counter = counter
        self.clock = clock
    }

    public nonisolated func invoke(_ messages: [any Message]) async throws -> AIMessage {
        let inputTokens = counter.countTokens(in: messages)
        try await awaitBudget(inputTokens: inputTokens)
        return try await wrapped.invoke(messages)
    }

    private func awaitBudget(inputTokens: Int) async throws {
        while true {
            let now = Date()
            pruneOlderThan(now)
            let requestsOver = requestTimestamps.count >= maxRequestsPerWindow
            let tokensOver = if let max = maxTokensPerWindow {
                tokenSpends.reduce(0) { $0 + $1.1 } + inputTokens > max
            } else {
                false
            }
            if !requestsOver && !tokensOver {
                requestTimestamps.append(now)
                if maxTokensPerWindow != nil {
                    tokenSpends.append((now, inputTokens))
                }
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func pruneOlderThan(_ now: Date) {
        let windowSeconds = secondsIn(window)
        let cutoff = now.addingTimeInterval(-windowSeconds)
        requestTimestamps.removeAll { $0 < cutoff }
        tokenSpends.removeAll { $0.0 < cutoff }
    }
}

private func secondsIn(_ duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) + Double(components.attoseconds) / 1.0e18
}
