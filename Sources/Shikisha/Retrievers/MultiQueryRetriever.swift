import Foundation

/// Use an LLM to paraphrase the query `n` times, run the base retriever for each, and merge
/// the results (deduped by id / content) keeping the max score across queries.
public struct MultiQueryRetriever: Retriever {
    public let base: any Retriever
    public let queryGenerator: any ChatModel
    public let count: Int
    public let k: Int

    public init(base: any Retriever, queryGenerator: any ChatModel, count: Int = 3, k: Int = 4) {
        precondition(count > 0, "count must be > 0")
        self.base = base
        self.queryGenerator = queryGenerator
        self.count = count
        self.k = k
    }

    public func retrieve(_ query: String) async throws -> [Document] {
        let queries = try await generateQueries(query)
        let allDocuments = try await withThrowingTaskGroup(of: [Document].self) { group in
            for variant in queries {
                group.addTask { try await base.retrieve(variant) }
            }
            var collected: [Document] = []
            for try await batch in group { collected.append(contentsOf: batch) }
            return collected
        }

        var seen = Set<String>()
        var deduped: [Document] = []
        for document in allDocuments {
            let key = document.id ?? document.pageContent
            if seen.insert(key).inserted {
                deduped.append(document)
            }
        }
        return Array(deduped.prefix(k))
    }

    private func generateQueries(_ query: String) async throws -> [String] {
        let prompt: [any Message] = [
            SystemMessage(content: """
                You are a query expansion helper. Generate \(count) alternative phrasings of the
                user query that surface different keywords. Output one per line, no numbering.
                Always include the original query as the first line.
                """),
            HumanMessage(content: query)
        ]
        let response = try await queryGenerator.invoke(prompt)
        let variants = response.content
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if variants.isEmpty { return [query] }
        return Array(variants.prefix(count + 1))
    }
}
