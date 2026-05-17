import Foundation

/// Ask an LLM to extract only the spans of each document that are relevant to the query.
/// Discards documents the model deems irrelevant entirely.
public struct LLMChainExtractor: DocumentCompressor {
    public let model: any ChatModel

    public init(model: any ChatModel) { self.model = model }

    public func compress(documents: [Document], query: String) async throws -> [Document] {
        var compressed: [Document] = []
        for document in documents {
            let messages: [any Message] = [
                SystemMessage(content: """
                    Extract the parts of the document that are relevant to the question.
                    Return only the extracted text — no commentary. If nothing is relevant,
                    return the single token: NONE
                    """),
                HumanMessage(content: """
                    Question: \(query)

                    Document:
                    \(document.pageContent)
                    """)
            ]
            let response = try await model.invoke(messages)
            let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "NONE" { continue }
            compressed.append(Document(pageContent: trimmed, metadata: document.metadata, id: document.id))
        }
        return compressed
    }
}

/// Ask an LLM for a yes/no relevance verdict on each document; keep the yeses.
public struct LLMListFilter: DocumentCompressor {
    public let model: any ChatModel

    public init(model: any ChatModel) { self.model = model }

    public func compress(documents: [Document], query: String) async throws -> [Document] {
        var keepers: [Document] = []
        for document in documents {
            let messages: [any Message] = [
                SystemMessage(content: "Reply with exactly YES or NO. Is the document relevant to the question?"),
                HumanMessage(content: """
                    Question: \(query)

                    Document:
                    \(document.pageContent)
                    """)
            ]
            let response = try await model.invoke(messages)
            let verdict = response.content.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if verdict.hasPrefix("YES") {
                keepers.append(document)
            }
        }
        return keepers
    }
}
