import Foundation
import Testing
@testable import Shikisha

@Suite("Retrievers")
struct RetrieverTests {
    @Test func testBM25Retrieval() async throws {
        let retriever = BM25Retriever()
        await retriever.addDocuments([
            Document(pageContent: "the quick brown fox"),
            Document(pageContent: "lazy dogs sleep all day"),
            Document(pageContent: "foxes hunt at night")
        ])
        let results = try await retriever.retrieve("fox")
        #expect(results.first?.pageContent.contains("fox") == true)
    }

    @Test func testMetadataFilterTreeAnd() {
        let filter = MetadataFilter.and([
            .equal(field: "lang", value: .string("ja")),
            .greaterThanOrEqual(field: "level", value: .int(3))
        ])
        #expect(filter.matches(["lang": .string("ja"), "level": .int(5)]))
        #expect(!filter.matches(["lang": .string("ja"), "level": .int(2)]))
        #expect(!filter.matches(["lang": .string("en"), "level": .int(5)]))
    }

    @Test func testMetadataFilterIn() {
        let filter = MetadataFilter.in(field: "tag", values: [.string("a"), .string("b")])
        #expect(filter.matches(["tag": .string("a")]))
        #expect(!filter.matches(["tag": .string("c")]))
    }
}
