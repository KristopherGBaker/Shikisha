import Foundation
import Shikisha

let messages: [any Message] = [
    SystemMessage(content: "You are a helpful assistant."),
    HumanMessage(content: "Say hi.")
]

let prompt = ChatPromptTemplate.fromTuples([
    .system("You are a {role}."),
    .human("{question}")
])

let rendered = try prompt.formatMessages([
    "role": "translator",
    "question": "How do you say 'hello' in Swift?"
])

for message in messages + rendered {
    print("[\(message.role.rawValue)] \(message.content)")
}
