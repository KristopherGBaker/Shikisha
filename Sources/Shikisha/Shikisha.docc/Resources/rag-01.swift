import Foundation
import Shikisha

// 1. Load your content. A loader reads a source into [Document]; here we use literals.
let raw = [
    Document(pageContent: "Shikisha targets macOS 14+ and iOS 17+ and uses Swift 6.3.",
             metadata: ["source": "readme"]),
    Document(pageContent: "Every Runnable composes with pipe and the |> operator.",
             metadata: ["source": "concepts"])
]

// 2. Split long documents into focused, overlapping chunks for precise retrieval.
let splitter = RecursiveCharacterTextSplitter(chunkSize: 500, chunkOverlap: 50)
let chunks = splitter.splitDocuments(raw)
print("split into \(chunks.count) chunks")
