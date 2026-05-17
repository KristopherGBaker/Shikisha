import Foundation
import Testing
@testable import Shikisha

private struct StableEmbeddings: Embeddings {
    let modelName = "stable"
    let dimensions: Int? = 8

    func embedDocuments(_ texts: [String]) async throws -> [[Float]] {
        texts.map { text -> [Float] in
            var vector = [Float](repeating: 0, count: 8)
            for (index, scalar) in text.unicodeScalars.enumerated() {
                vector[index % 8] += Float(scalar.value % 7)
            }
            return vector
        }
    }
}

@Suite("Indexing")
struct IndexingTests {
    @Test func testSkipsUnchangedDocumentsOnSecondRun() async throws {
        let store = InMemoryVectorStore(embeddings: StableEmbeddings())
        let manager = InMemoryRecordManager()
        let documents = [
            Document(pageContent: "doc-a", metadata: ["source": .string("a.md")]),
            Document(pageContent: "doc-b", metadata: ["source": .string("b.md")])
        ]
        let first = try await index(documents: documents, vectorStore: store, recordManager: manager)
        #expect(first.added == 2)
        #expect(first.updated == 0)
        let second = try await index(documents: documents, vectorStore: store, recordManager: manager)
        #expect(second.skipped == 2)
        #expect(second.added == 0)
    }

    @Test func testDetectsUpdates() async throws {
        let store = InMemoryVectorStore(embeddings: StableEmbeddings())
        let manager = InMemoryRecordManager()
        let original = Document(pageContent: "v1", metadata: ["source": .string("doc.md")])
        let updated = Document(pageContent: "v2", metadata: ["source": .string("doc.md")])
        _ = try await index(documents: [original], vectorStore: store, recordManager: manager)
        let result = try await index(documents: [updated], vectorStore: store, recordManager: manager)
        #expect(result.updated == 1)
    }

    @Test func testFullCleanupRemovesMissing() async throws {
        let store = InMemoryVectorStore(embeddings: StableEmbeddings())
        let manager = InMemoryRecordManager()
        let documents = [
            Document(pageContent: "first", metadata: ["source": .string("1")]),
            Document(pageContent: "second", metadata: ["source": .string("2")])
        ]
        _ = try await index(documents: documents, vectorStore: store, recordManager: manager)
        let result = try await index(
            documents: [Document(pageContent: "first", metadata: ["source": .string("1")])],
            vectorStore: store,
            recordManager: manager,
            cleanup: .full
        )
        #expect(result.deleted == 1)
    }
}
