import Foundation
import Testing
@testable import Shikisha

private struct HashEmbeddings: Embeddings {
    let modelName = "hash-embeddings"
    let dimensions: Int? = 16

    func embedDocuments(_ texts: [String]) async throws -> [[Float]] {
        texts.map { text -> [Float] in
            var vector = [Float](repeating: 0, count: 16)
            for (index, character) in text.unicodeScalars.enumerated() {
                vector[index % 16] += Float(character.value % 10) / 10
            }
            return vector
        }
    }
}

@Suite("VectorStore")
struct VectorStoreTests {
    @Test func testInMemoryAddAndSearch() async throws {
        let store = InMemoryVectorStore(embeddings: HashEmbeddings())
        let documents = [
            Document(pageContent: "apple pie", metadata: ["topic": "food"]),
            Document(pageContent: "linear algebra", metadata: ["topic": "math"])
        ]
        let ids = try await store.addDocuments(documents)
        #expect(ids.count == 2)
        let results = try await store.similaritySearch(query: "apple pie", topK: 1)
        #expect(results.count == 1)
        #expect(results.first?.document.pageContent == "apple pie")
    }

    @Test func testInMemoryMetadataFilter() async throws {
        let store = InMemoryVectorStore(embeddings: HashEmbeddings())
        _ = try await store.addDocuments([
            Document(pageContent: "cat", metadata: ["topic": "animal"]),
            Document(pageContent: "dog", metadata: ["topic": "animal"]),
            Document(pageContent: "table", metadata: ["topic": "furniture"])
        ])
        let filter = MetadataFilter.equal(field: "topic", value: .string("animal"))
        let results = try await store.similaritySearch(query: "cat", topK: 5, filter: filter)
        #expect(results.allSatisfy { $0.document.metadata["topic"]?.stringValue == "animal" })
    }

    @Test func testJsonFilePersistsAcrossInstances() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("vectors.json")
        let store = try JsonFileVectorStore(file: file, embeddings: HashEmbeddings())
        _ = try await store.addDocuments([Document(pageContent: "persistent")])

        let reopened = try JsonFileVectorStore(file: file, embeddings: HashEmbeddings())
        let results = try await reopened.similaritySearch(query: "persistent", topK: 1)
        #expect(results.first?.document.pageContent == "persistent")
    }

    @Test func testSqliteRoundTrip() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("store.sqlite")
        let store = try SqliteVectorStore(file: file, embeddings: HashEmbeddings())
        _ = try await store.addDocuments([
            Document(pageContent: "hello world"),
            Document(pageContent: "goodbye world")
        ])
        let results = try await store.similaritySearch(query: "hello world", topK: 1)
        #expect(results.first?.document.pageContent == "hello world")
    }
}
