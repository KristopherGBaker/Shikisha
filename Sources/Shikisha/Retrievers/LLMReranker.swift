import Foundation

/// Score each retrieved document 0–10 via an LLM and re-rank by score. Optional `topN` and
/// `scoreThreshold` to drop the long tail.
public struct LLMReranker: DocumentCompressor {
    public let model: any ChatModel
    public let topN: Int?
    public let scoreThreshold: Double?

    public init(model: any ChatModel, topN: Int? = nil, scoreThreshold: Double? = nil) {
        self.model = model
        self.topN = topN
        self.scoreThreshold = scoreThreshold
    }

    public func compress(documents: [Document], query: String) async throws -> [Document] {
        var scored: [(Document, Double)] = []
        for document in documents {
            let messages: [any Message] = [
                SystemMessage(content: """
                    Rate how relevant the document is to the question on a scale of 0 to 10
                    (0 = irrelevant, 10 = highly relevant). Respond with the number only.
                    """),
                HumanMessage(content: """
                    Question: \(query)

                    Document:
                    \(document.pageContent)
                    """)
            ]
            let response = try await model.invoke(messages)
            let raw = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let numeric = CharacterSet.decimalDigits.union(.init(charactersIn: "."))
            let score = Double(raw.components(separatedBy: numeric).joined()) ?? 0
            let parsed = Double(raw) ?? score
            scored.append((document, parsed))
        }
        var filtered = scored
        if let scoreThreshold {
            filtered = filtered.filter { $0.1 >= scoreThreshold }
        }
        filtered.sort { $0.1 > $1.1 }
        if let topN { filtered = Array(filtered.prefix(topN)) }
        return filtered.map(\.0)
    }
}
