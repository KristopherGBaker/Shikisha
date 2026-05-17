import Foundation

public enum TrimStrategy: Sendable {
    /// Keep the most recent messages that fit in the budget.
    case last
    /// Keep the oldest messages that fit in the budget.
    case first
}

/// Trim a list of messages to fit a token budget. Optionally pin the leading
/// `SystemMessage` (or any message matched by `pin`) so it always survives.
///
/// Mirrors LangChain's `trim_messages` helper — used by `TokenBufferMemory` and
/// agent loops to prevent context-window overflows.
public func trimMessages(
    _ messages: [any Message],
    maxTokens: Int,
    counter: any TokenCounter = ApproximateTokenCounter(),
    strategy: TrimStrategy = .last,
    pinSystemMessages: Bool = true
) -> [any Message] {
    guard maxTokens > 0 else { return [] }

    let pinned: [any Message]
    let rest: [any Message]
    if pinSystemMessages {
        pinned = messages.filter { $0 is SystemMessage }
        rest = messages.filter { !($0 is SystemMessage) }
    } else {
        pinned = []
        rest = messages
    }

    let pinnedCost = counter.countTokens(in: pinned)
    var remaining = maxTokens - pinnedCost
    guard remaining > 0 else { return pinned }

    let ordered = strategy == .last ? Array(rest.reversed()) : rest
    var kept: [any Message] = []
    for message in ordered {
        let cost = counter.countTokens(message.content) + 4
        if cost > remaining { break }
        kept.append(message)
        remaining -= cost
    }
    let restored = strategy == .last ? Array(kept.reversed()) : kept

    return pinned + restored
}
