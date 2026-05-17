import Foundation

/// Persistent buffer memory backed by a JSON file. One file per session id; safe for
/// single-process use.
public actor JsonFileChatMemory: ChatMemory {
    public let file: URL

    private struct StoredMessage: Codable, Sendable {
        let role: String
        let content: String
        let name: String?
        let id: String?
        let toolCallId: String?
    }

    private var buffer: [StoredMessage] = []

    public init(file: URL) throws {
        self.file = file
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: file),
           let stored = try? JSONDecoder().decode([StoredMessage].self, from: data) {
            buffer = stored
        }
    }

    public func addMessage(_ message: any Message) async throws {
        buffer.append(toStored(message))
        try persist()
    }

    public func messages() async throws -> [any Message] {
        buffer.compactMap(toMessage)
    }

    public func clear() async throws {
        buffer.removeAll()
        try persist()
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(buffer)
        try data.write(to: file, options: .atomic)
    }

    private func toStored(_ message: any Message) -> StoredMessage {
        StoredMessage(
            role: message.role.rawValue,
            content: message.content,
            name: message.name,
            id: message.id,
            toolCallId: (message as? ToolMessage)?.toolCallId
        )
    }

    private func toMessage(_ stored: StoredMessage) -> (any Message)? {
        switch stored.role {
        case "system": return SystemMessage(content: stored.content, name: stored.name, id: stored.id)
        case "user": return HumanMessage(content: stored.content, name: stored.name, id: stored.id)
        case "assistant": return AIMessage(content: stored.content, name: stored.name, id: stored.id)
        case "tool":
            guard let toolCallId = stored.toolCallId else { return nil }
            return ToolMessage(content: stored.content, toolCallId: toolCallId, name: stored.name, id: stored.id)
        default: return nil
        }
    }
}
