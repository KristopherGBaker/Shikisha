import Foundation

/// Single-call Q&A: stuff every retrieved document into a single prompt with the question.
/// Cheap when context fits the window; falls over when it doesn't (use `MapReduceSummarizer`
/// or `RefineSummarizer` for longer inputs).
public struct StuffDocumentChain: Runnable {
    public typealias Input = (documents: [Document], question: String)
    public typealias Output = String

    public let model: any ChatModel
    public let promptTemplate: String
    public let documentSeparator: String

    public init(
        model: any ChatModel,
        promptTemplate: String = """
            Use the following pieces of context to answer the user's question. If you don't know
            the answer, say so.

            Context:
            {context}

            Question: {question}
            """,
        documentSeparator: String = "\n\n---\n\n"
    ) {
        self.model = model
        self.promptTemplate = promptTemplate
        self.documentSeparator = documentSeparator
    }

    public func invoke(_ input: Input) async throws -> String {
        let context = input.documents.map(\.pageContent).joined(separator: documentSeparator)
        let prompt = try PromptTemplate.fromTemplate(promptTemplate)
            .format(["context": context, "question": input.question])
        let response = try await model.invoke([HumanMessage(content: prompt)])
        return response.content
    }
}
