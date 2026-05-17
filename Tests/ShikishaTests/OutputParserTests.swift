import Foundation
import Testing
@testable import Shikisha

@Suite("OutputParsers")
struct OutputParserTests {
    @Test func testStringParser() async throws {
        let result = try await StringOutputParser().invoke(AIMessage(content: "hello"))
        #expect(result == "hello")
    }

    @Test func testJSONParserStripsCodeFence() async throws {
        let response = AIMessage(content: """
            ```json
            {"answer": 42}
            ```
            """)
        let value = try await JSONOutputParser().invoke(response)
        #expect(value["answer"]?.intValue == 42)
    }

    @Test func testCommaListParser() async throws {
        let response = AIMessage(content: "apples, oranges, , bananas")
        let items = try await CommaSeparatedListOutputParser().invoke(response)
        #expect(items == ["apples", "oranges", "bananas"])
    }

    @Test func testNumberedListParser() async throws {
        let response = AIMessage(content: """
            1. first
            2) second
            3.  third
            """)
        let items = try await NumberedListOutputParser().invoke(response)
        #expect(items == ["first", "second", "third"])
    }

    @Test func testStructuredOutputDecode() async throws {
        struct Score: Decodable, Equatable { let total: Int }
        let response = AIMessage(content: #"{"total":7}"#)
        let parsed: Score = try await StructuredOutputParser().invoke(response)
        #expect(parsed.total == 7)
    }

    @Test func testCsvParserHandlesQuotedFields() async throws {
        let response = AIMessage(content: #"""
        name,note
        alice,"hello, world"
        bob,"line
        break"
        """#)
        let rows = try await CsvOutputParser().invoke(response)
        #expect(rows.count == 3)
        #expect(rows[1] == ["alice", "hello, world"])
        #expect(rows[2] == ["bob", "line\nbreak"])
    }

    @Test func testPartialJSONClosesBrackets() {
        let partial = #"{"items":[1,2"#
        let value = PartialJSON.parse(partial)
        #expect(value?["items"]?[0]?.intValue == 1)
        #expect(value?["items"]?[1]?.intValue == 2)
    }
}
