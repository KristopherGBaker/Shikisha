import Foundation
import Testing
@testable import Shikisha

@Suite("Memory")
struct MemoryTests {
    @Test func testBufferMemoryRoundTrip() async throws {
        let memory = BufferMemory()
        try await memory.addMessage(HumanMessage(content: "hi"))
        try await memory.addMessage(AIMessage(content: "hello"))
        let messages = try await memory.messages()
        #expect(messages.count == 2)
        #expect(messages[0].content == "hi")
    }

    @Test func testBufferWindowKeepsRecent() async throws {
        let memory = BufferWindowMemory(windowSize: 2)
        try await memory.addMessage(SystemMessage(content: "rules"))
        for index in 0..<5 {
            try await memory.addMessage(HumanMessage(content: "msg \(index)"))
        }
        let messages = try await memory.messages()
        // System pinned + 2 most recent
        #expect(messages.count == 3)
        #expect(messages.first is SystemMessage)
        #expect(messages.last?.content == "msg 4")
    }

    @Test func testJsonFileMemoryPersists() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("memory.json")
        let memory = try JsonFileChatMemory(file: file)
        try await memory.addMessage(HumanMessage(content: "remember me"))
        let reopened = try JsonFileChatMemory(file: file)
        let messages = try await reopened.messages()
        #expect(messages.first?.content == "remember me")
    }

    @Test func testSqliteMemoryRoundTrip() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("memory.sqlite")
        let memory = try SqliteChatMemory(file: file, sessionID: "session-a")
        try await memory.addMessage(HumanMessage(content: "one"))
        try await memory.addMessage(AIMessage(content: "two"))
        let messages = try await memory.messages()
        #expect(messages.count == 2)
        #expect(messages[0].content == "one")
        #expect(messages[1].role == .assistant)
    }
}
