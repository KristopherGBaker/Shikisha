import Foundation

/// Retry a runnable on failure with exponential backoff (plus jitter). The closure
/// is invoked up to `maxAttempts` times; the last error is rethrown if all attempts fail.
public struct WithRetry<Wrapped: Runnable>: Runnable {
    public typealias Input = Wrapped.Input
    public typealias Output = Wrapped.Output

    private let wrapped: Wrapped
    private let maxAttempts: Int
    private let initialDelay: Duration
    private let multiplier: Double
    private let maxDelay: Duration
    private let jitter: Double
    private let shouldRetry: @Sendable (any Error) -> Bool

    public init(
        _ wrapped: Wrapped,
        maxAttempts: Int = 3,
        initialDelay: Duration = .milliseconds(250),
        multiplier: Double = 2.0,
        maxDelay: Duration = .seconds(10),
        jitter: Double = 0.1,
        shouldRetry: @Sendable @escaping (any Error) -> Bool = { _ in true }
    ) {
        precondition(maxAttempts > 0, "maxAttempts must be > 0")
        self.wrapped = wrapped
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.multiplier = multiplier
        self.maxDelay = maxDelay
        self.jitter = jitter
        self.shouldRetry = shouldRetry
    }

    public func invoke(_ input: Input) async throws -> Output {
        var attempt = 0
        var delay = initialDelay
        var lastError: any Error = CancellationError()

        while attempt < maxAttempts {
            attempt += 1
            do {
                return try await wrapped.invoke(input)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                guard attempt < maxAttempts, shouldRetry(error) else { throw error }
                let sleepFor = jitterApplied(delay, jitter: jitter)
                try? await Task.sleep(for: sleepFor)
                delay = nextDelay(delay)
            }
        }
        throw lastError
    }

    private func nextDelay(_ current: Duration) -> Duration {
        let scaled = current * multiplier
        return min(scaled, maxDelay)
    }
}

/// Try `primary`; on failure, try each fallback in order. The first success wins;
/// the final error from the last fallback is rethrown if all fail.
public struct WithFallbacks<Wrapped: Runnable>: Runnable {
    public typealias Input = Wrapped.Input
    public typealias Output = Wrapped.Output

    private let primary: Wrapped
    private let fallbacks: [AnyRunnable<Input, Output>]
    private let shouldFallback: @Sendable (any Error) -> Bool

    public init(
        _ primary: Wrapped,
        fallbacks: [AnyRunnable<Input, Output>],
        shouldFallback: @Sendable @escaping (any Error) -> Bool = { _ in true }
    ) {
        self.primary = primary
        self.fallbacks = fallbacks
        self.shouldFallback = shouldFallback
    }

    public func invoke(_ input: Input) async throws -> Output {
        do {
            return try await primary.invoke(input)
        } catch is CancellationError {
            throw CancellationError()
        } catch let primaryError {
            guard shouldFallback(primaryError) else { throw primaryError }
            var lastError = primaryError
            for fallback in fallbacks {
                do {
                    return try await fallback.invoke(input)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    lastError = error
                    guard shouldFallback(error) else { throw error }
                }
            }
            throw lastError
        }
    }
}

public extension Runnable {
    /// Wrap this runnable with retry semantics.
    func withRetry(
        maxAttempts: Int = 3,
        initialDelay: Duration = .milliseconds(250),
        multiplier: Double = 2.0,
        maxDelay: Duration = .seconds(10),
        jitter: Double = 0.1
    ) -> WithRetry<Self> {
        WithRetry(
            self,
            maxAttempts: maxAttempts,
            initialDelay: initialDelay,
            multiplier: multiplier,
            maxDelay: maxDelay,
            jitter: jitter
        )
    }

    /// Wrap this runnable with a list of fallback runnables (same input/output type).
    func withFallbacks(_ fallbacks: [AnyRunnable<Input, Output>]) -> WithFallbacks<Self> {
        WithFallbacks(self, fallbacks: fallbacks)
    }
}

private func jitterApplied(_ base: Duration, jitter: Double) -> Duration {
    guard jitter > 0 else { return base }
    let baseSeconds = duration(base, asSecondsTimes: 1)
    let delta = baseSeconds * jitter * Double.random(in: -1...1)
    let final = max(0.0, baseSeconds + delta)
    return .nanoseconds(Int64(final * 1_000_000_000))
}

private func duration(_ duration: Duration, asSecondsTimes _: Int) -> Double {
    let components = duration.components
    return Double(components.seconds) + Double(components.attoseconds) / 1.0e18
}
