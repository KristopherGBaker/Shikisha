import Foundation
import Shikisha

/// Retrieval-Augmented Generation (RAG) grounds a model's answer in your own data: split the
/// data into chunks, embed and store them, retrieve the chunks most relevant to a question, and
/// pass them to the model as context. This example wires up the whole pipeline in memory.
enum RagPipelineExample {
    static func run() async throws {
        // 1. Your knowledge base. In practice you'd load these with a `DocumentLoader` and chop
        //    them up with a `TextSplitter`.
        let documents = [
            Document(pageContent: "Shikisha is a pure-Swift port of LangChain for macOS and iOS.",
                     metadata: ["topic": "overview"]),
            Document(pageContent: "A Runnable turns an Input into an Output and composes with pipe.",
                     metadata: ["topic": "runnables"]),
            Document(pageContent: "Vector stores hold embeddings so you can search by meaning.",
                     metadata: ["topic": "vectors"])
        ]

        // 2. Embed and store. Swap `LocalHashEmbeddings` for `OpenAIEmbeddings` etc. in production.
        let store = InMemoryVectorStore(embeddings: LocalHashEmbeddings())
        _ = try await store.addDocuments(documents)

        // 3. A retriever is just a `Runnable<String, [Document]>`.
        let retriever = store.asRetriever(topK: 2)

        section("Retrieved documents")
        let hits = try await retriever.retrieve("What is a vector store?")
        for hit in hits {
            print("• \(hit.pageContent)")
        }

        // 4. RagChain stitches retriever + prompt + model into one `Runnable<String, String>`.
        //    `defaultRagChain` provides a sensible "answer from context" prompt.
        let model = FakeChatModel(responses: [
            AIMessage(content: "A vector store holds embeddings so you can search your data by meaning.")
        ])
        let chain = defaultRagChain(retriever: retriever, model: model)

        section("Answer")
        let answer = try await chain.invoke("What is a vector store?")
        print(answer)
    }
}
