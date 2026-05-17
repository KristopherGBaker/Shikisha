import Foundation
import Testing
@testable import Shikisha

@Suite("Runnable")
struct RunnableTests {
    @Test func testPipe() async throws {
        let toString = RunnableLambda<Int, String> { "\($0)" }
        let exclaim = RunnableLambda<String, String> { "\($0)!" }
        let chain = toString.pipe(exclaim)
        #expect(try await chain.invoke(5) == "5!")
    }

    @Test func testOperatorPipe() async throws {
        let doubleIt = RunnableLambda<Int, Int> { $0 * 2 }
        let toString = RunnableLambda<Int, String> { "\($0)" }
        let chain = doubleIt |> toString
        #expect(try await chain.invoke(3) == "6")
    }

    @Test func testBatch() async throws {
        let plusOne = RunnableLambda<Int, Int> { $0 + 1 }
        #expect(try await plusOne.batch([1, 2, 3]) == [2, 3, 4])
    }

    @Test func testBatchParallel() async throws {
        let plusOne = RunnableLambda<Int, Int> { $0 + 1 }
        let results = try await plusOne.batchParallel([1, 2, 3, 4], maxConcurrent: 2)
        #expect(results == [2, 3, 4, 5])
    }

    @Test func testRetrySucceedsAfterTransient() async throws {
        let attempts = TestCounter()
        let flaky = RunnableLambda<String, String> { input in
            let attempt = await attempts.increment()
            if attempt < 2 { throw HTTPError.transport(message: "boom") }
            return input.uppercased()
        }.withRetry(maxAttempts: 3, initialDelay: .milliseconds(1))
        let result = try await flaky.invoke("hi")
        #expect(result == "HI")
        #expect(await attempts.value == 2)
    }

    @Test func testFallbacksUseSecondOnFailure() async throws {
        let failing = RunnableLambda<String, String> { _ in throw HTTPError.transport(message: "no") }
        let backup = AnyRunnable(RunnableLambda<String, String> { "fallback:\($0)" })
        let composed = failing.withFallbacks([backup])
        #expect(try await composed.invoke("x") == "fallback:x")
    }
}

private actor TestCounter {
    private(set) var value: Int = 0
    func increment() -> Int { value += 1; return value }
}
