import Foundation

/// Accumulates token usage across runs. Thread-safe via actor isolation.
public actor UsageTrackerCallback: Callback {
    public struct Snapshot: Sendable, Equatable {
        public let perModel: [String: UsageMetadata]
        public let total: UsageMetadata

        public init(perModel: [String: UsageMetadata], total: UsageMetadata) {
            self.perModel = perModel
            self.total = total
        }
    }

    private var perModel: [String: UsageMetadata] = [:]

    public init() {}

    public func snapshot() -> Snapshot {
        var total = UsageMetadata(inputTokens: 0, outputTokens: 0)
        for usage in perModel.values { total = total + usage }
        return Snapshot(perModel: perModel, total: total)
    }

    public func reset() { perModel.removeAll() }

    public func onLLMEnd(model: String, response: AIMessage) async {
        guard let usage = response.usageMetadata else { return }
        perModel[model, default: UsageMetadata(inputTokens: 0, outputTokens: 0)] =
            perModel[model, default: UsageMetadata(inputTokens: 0, outputTokens: 0)] + usage
    }
}
