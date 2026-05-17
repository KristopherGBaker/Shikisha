import Foundation
import Testing
@testable import Shikisha

@Suite("Networking")
struct NetworkingTests {
    @Test func testSSEParsesMultipleFrames() async throws {
        let raw = """
        data: hello

        data: world

        event: ping
        data: 42

        """
        let bytes = makeStream(from: raw)
        var events: [SSEEvent] = []
        for try await event in parseSSE(bytes) {
            events.append(event)
        }
        #expect(events.count == 3)
        #expect(events[0].data == "hello")
        #expect(events[1].data == "world")
        #expect(events[2].event == "ping")
        #expect(events[2].data == "42")
    }

    @Test func testSSEHandlesDoneSentinel() async throws {
        let raw = """
        data: {"x":1}

        data: [DONE]

        """
        let bytes = makeStream(from: raw)
        var collected: [String] = []
        for try await event in parseSSE(bytes) {
            collected.append(event.data)
        }
        #expect(collected == [#"{"x":1}"#, "[DONE]"])
    }

    @Test func testNDJSONSplitsLines() async throws {
        let raw = """
        {"a":1}
        {"b":2}
        """
        let bytes = makeStream(from: raw)
        var collected: [String] = []
        for try await frame in parseNDJSON(bytes) {
            collected.append(String(data: frame, encoding: .utf8) ?? "")
        }
        #expect(collected == [#"{"a":1}"#, #"{"b":2}"#])
    }
}

private func makeStream(from text: String) -> AsyncThrowingStream<Data, Error> {
    AsyncThrowingStream { continuation in
        continuation.yield(Data(text.utf8))
        continuation.finish()
    }
}
