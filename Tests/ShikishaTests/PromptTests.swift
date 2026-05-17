import Foundation
import Testing
@testable import Shikisha

@Suite("Prompts")
struct PromptTests {
    @Test func testPromptTemplateExpandsVariables() throws {
        let template = PromptTemplate.fromTemplate("Hello, {name}!")
        #expect(template.inputVariables == ["name"])
        #expect(try template.format(["name": "world"]) == "Hello, world!")
    }

    @Test func testMissingVariableThrows() {
        let template = PromptTemplate.fromTemplate("Hello, {name}!")
        #expect(throws: MissingPromptVariableError.self) {
            try template.format([:])
        }
    }

    @Test func testChatPromptTemplateFromTuples() throws {
        let prompt = ChatPromptTemplate.fromTuples([
            .system("You are a {role}"),
            .human("{question}")
        ])
        let messages = try prompt.formatMessages([
            "role": "translator",
            "question": "hello?"
        ])
        #expect(messages.count == 2)
        #expect(messages[0].content == "You are a translator")
        #expect(messages[1].content == "hello?")
    }

    @Test func testMessagesPlaceholder() throws {
        let prompt = ChatPromptTemplate.fromTuples([
            .system("rules"),
            .placeholder("history"),
            .human("{q}")
        ])
        let history: [any Message] = [HumanMessage(content: "prior")]
        let messages = try prompt.formatMessages(["history": history, "q": "next"])
        #expect(messages.count == 3)
        #expect(messages[1].content == "prior")
    }
}
