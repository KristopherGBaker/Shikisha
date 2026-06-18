import Foundation
import Testing
@testable import Shikisha

/// Tests for the gated Foundation Models backend. They exercise the SDK-independent helpers
/// (cumulative→delta conversion, message→prompt mapping, availability handling) so they run
/// in CI without an eligible device or the on-device model actually being available.
@Suite("Foundation Models provider")
struct FoundationModelsProviderTests {
    // MARK: - Cumulative → delta streaming contract

    @Test func testCumulativeSnapshotsBecomeDeltas() {
        // FoundationModels yields the whole response-so-far on each element.
        let snapshots = ["Hel", "Hello", "Hello, ", "Hello, world"]
        var tracker = CumulativeToDelta()
        let deltas = snapshots.map { tracker.delta(for: $0) }

        #expect(deltas == ["Hel", "lo", ", ", "world"])
    }

    @Test func testConcatenatedDeltasReconstructFullResponseExactlyOnce() {
        let snapshots = ["The", "The quick", "The quick brown", "The quick brown fox"]
        var tracker = CumulativeToDelta()
        let deltas = snapshots.map { tracker.delta(for: $0) }

        // The core gotcha: accumulating chunks must equal the final snapshot, not a
        // quadratic duplication of it.
        #expect(deltas.joined() == snapshots.last)
    }

    @Test func testRepeatedSnapshotEmitsEmptyDelta() {
        var tracker = CumulativeToDelta()
        #expect(tracker.delta(for: "Hello") == "Hello")
        // A duplicate snapshot (no new content) yields nothing to append.
        #expect(tracker.delta(for: "Hello") == "")
        #expect(tracker.delta(for: "Hello!") == "!")
    }

    @Test func testNonPrefixSnapshotFallsBackToWholeSnapshot() {
        var tracker = CumulativeToDelta()
        _ = tracker.delta(for: "Hello")
        // Defensive: if a snapshot isn't a prefix-extension (a rewrite), emit it whole.
        #expect(tracker.delta(for: "Goodbye") == "Goodbye")
    }

    // MARK: - Message → prompt / instructions mapping

    @Test func testInstructionsCollectSystemMessages() {
        let messages: [any Message] = [
            SystemMessage(content: "You are concise."),
            SystemMessage(content: "Answer in English."),
            HumanMessage(content: "Hi")
        ]
        #expect(foundationModelsInstructions(from: messages) == "You are concise.\n\nAnswer in English.")
    }

    @Test func testInstructionsNilWhenNoSystemMessage() {
        let messages: [any Message] = [HumanMessage(content: "Hi")]
        #expect(foundationModelsInstructions(from: messages) == nil)
    }

    @Test func testPromptIsLatestHumanTurnWhenNoPriorContext() {
        let messages: [any Message] = [
            SystemMessage(content: "ignored for prompt"),
            HumanMessage(content: "What is Swift?")
        ]
        #expect(foundationModelsPrompt(from: messages) == "What is Swift?")
    }

    @Test func testPromptRendersPriorTurnsAsTranscript() {
        let messages: [any Message] = [
            SystemMessage(content: "be helpful"),
            HumanMessage(content: "Hello"),
            AIMessage(content: "Hi there!"),
            HumanMessage(content: "How are you?")
        ]
        let expected = """
        User: Hello
        Assistant: Hi there!
        How are you?
        """
        #expect(foundationModelsPrompt(from: messages) == expected)
    }

    @Test func testPromptFallsBackToConcatenationWithoutHumanTurn() {
        let messages: [any Message] = [
            SystemMessage(content: "ignored"),
            AIMessage(content: "previous answer")
        ]
        #expect(foundationModelsPrompt(from: messages) == "previous answer")
    }

    // MARK: - Availability handling

    @Test func testAvailableStateProducesNoError() {
        #expect(foundationModelsAvailabilityError(for: .available) == nil)
    }

    @Test func testUnavailableStateProducesError() {
        let error = foundationModelsAvailabilityError(for: .unavailable(reason: "model downloading"))
        #expect(error == .unavailable(reason: "model downloading"))
        #expect(error?.description.contains("model downloading") == true)
    }
}
