import Foundation

/// Per-million-token pricing for a single model. Cache-read prices apply to Anthropic
/// prompt-caching hits; cache-write to the initial cache-creation request.
public struct ModelPricing: Sendable, Equatable {
    public let inputPerMTok: Double
    public let outputPerMTok: Double
    public let cacheReadPerMTok: Double
    public let cacheWritePerMTok: Double

    public init(
        inputPerMTok: Double,
        outputPerMTok: Double,
        cacheReadPerMTok: Double = 0,
        cacheWritePerMTok: Double = 0
    ) {
        self.inputPerMTok = inputPerMTok
        self.outputPerMTok = outputPerMTok
        self.cacheReadPerMTok = cacheReadPerMTok
        self.cacheWritePerMTok = cacheWritePerMTok
    }
}

/// Tracks USD cost across runs using a per-model pricing table. Wraps a `UsageTrackerCallback`
/// under the hood so cost and tokens always stay in sync.
public actor CostTrackerCallback: Callback {
    public struct Snapshot: Sendable, Equatable {
        public let perModelCost: [String: Double]
        public let totalCost: Double
        public let usage: UsageTrackerCallback.Snapshot

        public init(perModelCost: [String: Double], totalCost: Double, usage: UsageTrackerCallback.Snapshot) {
            self.perModelCost = perModelCost
            self.totalCost = totalCost
            self.usage = usage
        }
    }

    private let pricing: [String: ModelPricing]
    private let tracker: UsageTrackerCallback

    public init(pricing: [String: ModelPricing], tracker: UsageTrackerCallback = UsageTrackerCallback()) {
        self.pricing = pricing
        self.tracker = tracker
    }

    public func snapshot() async -> Snapshot {
        let usage = await tracker.snapshot()
        var perModelCost: [String: Double] = [:]
        var total = 0.0
        for (model, metadata) in usage.perModel {
            guard let price = pricing[model] else { continue }
            let cost = cost(metadata, pricing: price)
            perModelCost[model] = cost
            total += cost
        }
        return Snapshot(perModelCost: perModelCost, totalCost: total, usage: usage)
    }

    public func onLLMEnd(model: String, response: AIMessage) async {
        await tracker.onLLMEnd(model: model, response: response)
    }

    private nonisolated func cost(_ usage: UsageMetadata, pricing: ModelPricing) -> Double {
        let inputCost = Double(usage.inputTokens) / 1_000_000.0 * pricing.inputPerMTok
        let outputCost = Double(usage.outputTokens) / 1_000_000.0 * pricing.outputPerMTok
        let cacheReadCost = Double(usage.cacheReadInputTokens) / 1_000_000.0 * pricing.cacheReadPerMTok
        let cacheWriteCost = Double(usage.cacheCreationInputTokens) / 1_000_000.0 * pricing.cacheWritePerMTok
        return inputCost + outputCost + cacheReadCost + cacheWriteCost
    }
}
