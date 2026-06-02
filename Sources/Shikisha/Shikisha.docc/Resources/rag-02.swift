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

// 3. Embed and store. The store uses the embeddings model to vectorize each chunk.
let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let embeddings = OpenAIEmbeddings(
    config: OpenAIConfig(apiKey: apiKey),
    model: "text-embedding-3-small"
)
let store = InMemoryVectorStore(embeddings: embeddings)
_ = try await store.addDocuments(chunks)

// A quick sanity check: search by meaning.
let hits = try await store.similaritySearch(query: "Which platforms are supported?", topK: 2)
for hit in hits { print(hit.score, hit.document.pageContent) }
