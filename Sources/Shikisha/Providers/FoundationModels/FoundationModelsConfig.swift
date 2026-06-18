import Foundation

/// Settings for ``FoundationModelsChatModel``. On-device only — no API key, no base URL,
/// no network. Mirrors the small `Sendable` config types the other providers expose.
///
/// This type is intentionally *not* gated behind `#if canImport(FoundationModels)` so the
/// pure message→prompt and cumulative→delta helpers it pairs with remain unit-testable on
/// any toolchain. The model type that consumes it (``FoundationModelsChatModel``) is gated.
public struct FoundationModelsConfig: Sendable {
    /// Overrides the session instructions. When `nil`, the instructions are derived from any
    /// `SystemMessage`s in the conversation (see `foundationModelsInstructions(from:)`).
    public let instructions: String?

    /// Sampling temperature passed through to `GenerationOptions`. `nil` leaves the default.
    public let temperature: Double?

    /// Caps the generated response length via `GenerationOptions`. `nil` leaves the default.
    public let maximumResponseTokens: Int?

    public init(
        instructions: String? = nil,
        temperature: Double? = nil,
        maximumResponseTokens: Int? = nil
    ) {
        self.instructions = instructions
        self.temperature = temperature
        self.maximumResponseTokens = maximumResponseTokens
    }
}

/// Errors surfaced by ``FoundationModelsChatModel``. Mirrors how the HTTP providers signal
/// failure through their thrown error types, except here the only failure mode that isn't a
/// generation error is the on-device model being unavailable.
public enum FoundationModelsError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The system language model is not available (no eligible device, Apple Intelligence
    /// disabled, model still downloading, etc.). `reason` is the framework's description.
    case unavailable(reason: String)

    public var description: String {
        switch self {
        case .unavailable(let reason):
            return "Foundation Models unavailable: \(reason)"
        }
    }
}

// MARK: - Pure, SDK-independent helpers (unit-testable without the FoundationModels SDK)

/// A toolchain-independent mirror of `SystemLanguageModel.Availability`. The model type
/// translates the framework value into this so the availability→error decision is a pure
/// function that tests can exercise even where the SDK (or an eligible device) is absent.
enum FMAvailabilityState: Equatable, Sendable {
    case available
    case unavailable(reason: String)
}

/// Maps an availability state to the error the stream should finish with (or `nil` when the
/// model is ready). Pure — no FoundationModels dependency.
func foundationModelsAvailabilityError(for state: FMAvailabilityState) -> FoundationModelsError? {
    switch state {
    case .available:
        return nil
    case .unavailable(let reason):
        return .unavailable(reason: reason)
    }
}

/// Derives the `LanguageModelSession` instructions from a conversation: every `SystemMessage`
/// joined in order. Returns `nil` when there are none (so the session uses its default).
func foundationModelsInstructions(from messages: [any Message]) -> String? {
    let systems = messages
        .compactMap { $0 as? SystemMessage }
        .map(\.content)
        .filter { !$0.isEmpty }
    return systems.isEmpty ? nil : systems.joined(separator: "\n\n")
}

/// Builds the single prompt string handed to FoundationModels from the (non-system) turns.
///
/// FoundationModels' `LanguageModelSession` is prompt-oriented rather than message-array
/// oriented, so this is a deliberately simple, documented first cut:
/// - The latest `HumanMessage` is the prompt proper.
/// - Any prior turns are rendered above it as a labelled transcript for context.
/// - If there is no human turn, every non-system turn is concatenated as a fallback.
///
/// Tool-calling is out of scope for v1: `ToolMessage`s are rendered as plain transcript
/// lines and no tool definitions are sent. (Future work: bridge Shikisha `Tool`s to
/// FoundationModels' `@Generable` / tool-calling support.)
func foundationModelsPrompt(from messages: [any Message]) -> String {
    let conversation = messages.filter { !($0 is SystemMessage) }

    guard let lastHumanIndex = conversation.lastIndex(where: { $0 is HumanMessage }) else {
        return conversation.map(\.content).joined(separator: "\n")
    }

    let prior = conversation[..<lastHumanIndex]
    let latest = conversation[lastHumanIndex]

    guard !prior.isEmpty else {
        return latest.content
    }

    var lines = prior.map(foundationModelsTranscriptLine)
    lines.append(latest.content)
    return lines.joined(separator: "\n")
}

private func foundationModelsTranscriptLine(_ message: any Message) -> String {
    switch message.role {
    case .assistant: return "Assistant: \(message.content)"
    case .tool: return "Tool: \(message.content)"
    case .user: return "User: \(message.content)"
    case .system: return message.content
    }
}

/// Converts FoundationModels' **cumulative** response snapshots into the **incremental**
/// deltas Shikisha's streaming contract requires.
///
/// `LanguageModelSession.streamResponse(to:)` yields the whole response-so-far on every
/// element, whereas `ChatModel.stream` callers accumulate chunks with `+`. Yielding the
/// cumulative text directly would produce O(n²) duplicated output. This tracker remembers
/// the previous snapshot and returns only the newly appended suffix, so concatenating every
/// returned delta reconstructs the final snapshot exactly once.
///
/// FoundationModels content snapshots are append-only; if a snapshot is ever not prefixed by
/// the previous one (e.g. a rewrite), the tracker falls back to emitting the whole snapshot.
struct CumulativeToDelta {
    private var previous = ""

    /// Returns the suffix of `snapshot` not already emitted, and records `snapshot` as the
    /// new baseline.
    mutating func delta(for snapshot: String) -> String {
        let prior = previous
        previous = snapshot
        if snapshot.hasPrefix(prior) {
            return String(snapshot.dropFirst(prior.count))
        }
        return snapshot
    }
}
