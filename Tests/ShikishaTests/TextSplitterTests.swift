import Foundation
import Testing
@testable import Shikisha

@Suite("TextSplitters")
struct TextSplitterTests {
    @Test func testRecursiveSplitterProducesSizedChunks() {
        let text = String(repeating: "The quick brown fox. ", count: 50)
        let splitter = RecursiveCharacterTextSplitter(chunkSize: 80, chunkOverlap: 20)
        let chunks = splitter.splitText(text)
        for chunk in chunks {
            #expect(chunk.count <= 100)
        }
        #expect(chunks.count > 1)
    }

    @Test func testMarkdownHeaderSplitterCarriesPath() {
        let text = """
            # Title

            Intro.

            ## Section A

            Body A.

            ## Section B

            Body B.
            """
        let splitter = MarkdownHeaderTextSplitter()
        let documents = splitter.splitText(text)
        #expect(documents.count == 3)
        #expect(documents[0].metadata["h1"]?.stringValue == "Title")
        #expect(documents[1].metadata["h1"]?.stringValue == "Title")
        #expect(documents[1].metadata["h2"]?.stringValue == "Section A")
        #expect(documents[2].metadata["h2"]?.stringValue == "Section B")
    }
}
