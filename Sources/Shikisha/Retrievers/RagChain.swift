import Foundation

/// Compose a retriever, prompt, and chat model into a single Runnable.
/// `prompt` must reference two variables: `{context}` (joined documents) and `{question}` (query).
public struct RagChain: Runnable {
    public typealias Input = String
    public typealias Output = String

    public let retriever: any Retriever
    public let prompt: ChatPromptTemplate
    public let model: any ChatModel
    public let documentSeparator: String

    public init(
        retriever: any Retriever,
        prompt: ChatPromptTemplate,
        model: any ChatModel,
        documentSeparator: String = "\n\n---\n\n"
    ) {
        self.retriever = retriever
        self.prompt = prompt
        self.model = model
        self.documentSeparator = documentSeparator
    }

    public func invoke(_ input: String) async throws -> String {
        let documents = try await retriever.retrieve(input)
        let context = documents.map(\.pageContent).joined(separator: documentSeparator)
        let messages = try prompt.formatMessages([
            "context": context,
            "question": input
        ])
        let response = try await model.invoke(messages)
        return response.content
    }
}

/// Convenience: build a vanilla "Answer the question using the context" RAG chain.
public func defaultRagChain(retriever: any Retriever, model: any ChatModel) -> RagChain {
    let prompt = ChatPromptTemplate.fromTuples([
        .system("""
            Answer the user question using only the following context. If the context doesn't
            contain the answer, say you don't know.

            Context:
            {context}
            """),
        .human("{question}")
    ])
    return RagChain(retriever: retriever, prompt: prompt, model: model)
}
