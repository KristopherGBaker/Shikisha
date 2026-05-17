import Foundation

/// Refine summarization: start with a summary of the first document, then iteratively refine it
/// by showing the model the running summary plus the next document. Preserves document order
/// better than `MapReduceSummarizer` at the cost of being sequential.
public struct RefineSummarizer: Sendable {
    public let model: any ChatModel
    public let initialPrompt: String
    public let refinePrompt: String

    public init(
        model: any ChatModel,
        initialPrompt: String = "Summarize the following passage in 3-5 sentences:\n\n{text}",
        refinePrompt: String = """
            We have an existing summary:
            {existing}

            Incorporate the new context below into the summary. Return only the refined summary.

            New context:
            {text}
            """
    ) {
        self.model = model
        self.initialPrompt = initialPrompt
        self.refinePrompt = refinePrompt
    }

    public func summarize(_ documents: [Document]) async throws -> String {
        guard let first = documents.first else { return "" }
        var current = try await invokeWith(prompt: initialPrompt, variables: ["text": first.pageContent])
        for document in documents.dropFirst() {
            current = try await invokeWith(prompt: refinePrompt, variables: [
                "existing": current,
                "text": document.pageContent
            ])
        }
        return current
    }

    private func invokeWith(prompt: String, variables: [String: any Sendable]) async throws -> String {
        let formatted = try PromptTemplate.fromTemplate(prompt).format(variables)
        let response = try await model.invoke([HumanMessage(content: formatted)])
        return response.content
    }
}
