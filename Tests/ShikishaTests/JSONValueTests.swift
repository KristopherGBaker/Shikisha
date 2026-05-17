import Foundation
import Testing
@testable import Shikisha

@Suite("JSONValue")
struct JSONValueTests {
    @Test func testRoundTrip() throws {
        let value: JSONValue = [
            "name": "Shikisha",
            "version": 1,
            "ratio": 0.5,
            "ready": true,
            "tags": ["swift", "llm"],
            "metadata": ["author": "kris"]
        ]
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        #expect(decoded == value)
    }

    @Test func testParseAndAccess() {
        let value = JSONValue.parse(#"{"items":[{"x":1},{"x":2}]}"#)
        #expect(value?["items"]?[0]?["x"]?.intValue == 1)
        #expect(value?["items"]?[1]?["x"]?.intValue == 2)
        #expect(value?["missing"] == nil)
    }
}
