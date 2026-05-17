import Foundation
import Testing
@testable import Shikisha

@Suite("Messages")
struct MessageTests {
    @Test func testRoleMapping() {
        #expect(SystemMessage(content: "x").role == .system)
        #expect(HumanMessage(content: "x").role == .user)
        #expect(AIMessage(content: "x").role == .assistant)
        #expect(ToolMessage(content: "x", toolCallId: "1").role == .tool)
    }

    @Test func testHumanMessageAttachments() {
        let message = HumanMessage(
            content: "describe",
            attachments: [.imageBase64(data: "AAA", mediaType: "image/png")]
        )
        #expect(message.attachments.count == 1)
        if case .imageBase64(let data, let mediaType, _) = message.attachments[0] {
            #expect(data == "AAA")
            #expect(mediaType == "image/png")
        } else {
            Issue.record("expected base64 attachment")
        }
    }

    @Test func testUsageAddition() {
        let lhs = UsageMetadata(inputTokens: 10, outputTokens: 5)
        let rhs = UsageMetadata(inputTokens: 3, outputTokens: 7, cacheReadInputTokens: 2)
        let sum = lhs + rhs
        #expect(sum.inputTokens == 13)
        #expect(sum.outputTokens == 12)
        #expect(sum.totalTokens == 25)
        #expect(sum.cacheReadInputTokens == 2)
    }

    @Test func testTrimMessagesPinsSystem() {
        let messages: [any Message] = [
            SystemMessage(content: "rules"),
            HumanMessage(content: "old"),
            AIMessage(content: "older"),
            HumanMessage(content: "recent")
        ]
        let trimmed = trimMessages(messages, maxTokens: 5)
        #expect(trimmed.first is SystemMessage)
        #expect(trimmed.count <= 2)
    }

    @Test func testChunkMerge() {
        let first = AIMessageChunk(content: "Hel", toolCallChunks: [
            ToolCallChunk(index: 0, id: "1", name: "tool", argumentsBuffer: "{\"a\":")
        ])
        let second = AIMessageChunk(content: "lo", toolCallChunks: [
            ToolCallChunk(index: 0, argumentsBuffer: "1}")
        ])
        let merged = first + second
        #expect(merged.content == "Hello")
        #expect(merged.toolCallChunks.first?.argumentsBuffer == "{\"a\":1}")
    }
}
