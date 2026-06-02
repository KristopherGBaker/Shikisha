import Foundation
import Shikisha

let raw = [
    Document(pageContent: "Shikisha targets macOS 14+ and iOS 17+ and uses Swift 6.3.",
             metadata: ["source": "readme"]),
    Document(pageContent: "Every Runnable composes with pipe and the |> operator.",
             metadata: ["source": "concepts"])
]
let chunks = RecursiveCharacterTextSplitter(chunkSize: 500, chunkOverlap: 50)
    .splitDocuments(raw)

let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let embeddings = OpenAIEmbeddings(config: OpenAIConfig(apiKey: apiKey),
                                  model: "text-embedding-3-small")
let store = InMemoryVectorStore(embeddings: embeddings)
_ = try await store.addDocuments(chunks)

// 4. Turn the store into a retriever and answer questions grounded in your data.
let retriever = store.asRetriever(topK: 3)
let model = OpenAIChatModel(config: OpenAIConfig(apiKey: apiKey), model: "gpt-4o-mini")
let chain = defaultRagChain(retriever: retriever, model: model)

let answer = try await chain.invoke("Which platforms does Shikisha support?")
print(answer)
