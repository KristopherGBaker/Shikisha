import Foundation

/// Summarize a long document set by first summarizing each document (map), then summarizing
/// the summaries hierarchically (reduce). Use when the full corpus exceeds the model's context.
public struct MapReduceSummarizer: Sendable {
    public let model: any ChatModel
    public let mapPrompt: String
    public let reducePrompt: String
    public let maxIntermediateChars: Int

    public init(
        model: any ChatModel,
        mapPrompt: String = "Summarize the following passage in 3-5 sentences:\n\n{text}",
        reducePrompt: String = "Combine the following summaries into a single coherent summary:\n\n{text}",
        maxIntermediateChars: Int = 8000
    ) {
        self.model = model
        self.mapPrompt = mapPrompt
        self.reducePrompt = reducePrompt
        self.maxIntermediateChars = maxIntermediateChars
    }

    public func summarize(_ documents: [Document]) async throws -> String {
        guard !documents.isEmpty else { return "" }
        var summaries = try await mapStep(documents)
        while summaries.joined(separator: "\n\n").count > maxIntermediateChars, summaries.count > 1 {
            summaries = try await reduceStep(summaries)
        }
        return try await collapse(summaries)
    }

    private func mapStep(_ documents: [Document]) async throws -> [String] {
        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, document) in documents.enumerated() {
                group.addTask {
                    let prompt = try PromptTemplate.fromTemplate(mapPrompt)
                        .format(["text": document.pageContent])
                    let response = try await model.invoke([HumanMessage(content: prompt)])
                    return (index, response.content)
                }
            }
            var collected = Array(repeating: "", count: documents.count)
            for try await (index, value) in group {
                collected[index] = value
            }
            return collected
        }
    }

    private func reduceStep(_ summaries: [String]) async throws -> [String] {
        var grouped: [String] = []
        var current = ""
        for summary in summaries {
            if current.count + summary.count + 2 > maxIntermediateChars, !current.isEmpty {
                grouped.append(current)
                current = ""
            }
            if !current.isEmpty { current.append("\n\n") }
            current.append(summary)
        }
        if !current.isEmpty { grouped.append(current) }

        return try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, batch) in grouped.enumerated() {
                group.addTask {
                    let prompt = try PromptTemplate.fromTemplate(reducePrompt)
                        .format(["text": batch])
                    let response = try await model.invoke([HumanMessage(content: prompt)])
                    return (index, response.content)
                }
            }
            var collected = Array(repeating: "", count: grouped.count)
            for try await (index, value) in group {
                collected[index] = value
            }
            return collected
        }
    }

    private func collapse(_ summaries: [String]) async throws -> String {
        let joined = summaries.joined(separator: "\n\n")
        if summaries.count <= 1 { return joined }
        let prompt = try PromptTemplate.fromTemplate(reducePrompt).format(["text": joined])
        let response = try await model.invoke([HumanMessage(content: prompt)])
        return response.content
    }
}
