import Foundation

/// Conversation memory abstraction. Implementations decide how to trim, summarize, or
/// persist history.
public protocol ChatMemory: Sendable {
    /// Append a single message to the running history.
    func addMessage(_ message: any Message) async throws

    /// Append a batch of messages (e.g. one user + one assistant turn).
    func addMessages(_ messages: [any Message]) async throws

    /// The current message list, ordered chronologically.
    func messages() async throws -> [any Message]

    /// Wipe the entire history.
    func clear() async throws
}

public extension ChatMemory {
    func addMessages(_ messages: [any Message]) async throws {
        for message in messages { try await addMessage(message) }
    }
}
