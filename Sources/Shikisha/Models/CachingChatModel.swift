import Foundation
import CryptoKit

/// Cache deserialized responses by a content-addressed key derived from messages + model name.
/// Wraps any `ChatModel` so the underlying provider is unchanged.
public actor CachingChatModel<Wrapped: ChatModel>: ChatModel {
    public nonisolated var modelName: String { wrapped.modelName }

    private let wrapped: Wrapped
    private var memory: [String: AIMessage] = [:]
    private let storage: (any ChatCacheStorage)?

    public init(_ wrapped: Wrapped, storage: (any ChatCacheStorage)? = nil) {
        self.wrapped = wrapped
        self.storage = storage
    }

    public nonisolated func invoke(_ messages: [any Message]) async throws -> AIMessage {
        let key = cacheKey(messages: messages, modelName: wrapped.modelName)
        if let cached = await lookup(key) { return cached }
        let response = try await wrapped.invoke(messages)
        await store(key, response: response)
        return response
    }

    private func lookup(_ key: String) async -> AIMessage? {
        if let cached = memory[key] { return cached }
        if let storage, let cached = try? await storage.load(key: key) {
            memory[key] = cached
            return cached
        }
        return nil
    }

    private func store(_ key: String, response: AIMessage) async {
        memory[key] = response
        if let storage { try? await storage.save(key: key, response: response) }
    }
}

/// Persistent backing for `CachingChatModel`. Implement once, plug into JSON-on-disk
/// or any KV store. Tests use the in-memory fallback (no storage).
public protocol ChatCacheStorage: Sendable {
    func load(key: String) async throws -> AIMessage?
    func save(key: String, response: AIMessage) async throws
}

/// Simple file-backed JSON cache. One file per cache key; safe for single-process use.
public struct FileChatCacheStorage: ChatCacheStorage {
    public let directory: URL

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func load(key: String) async throws -> AIMessage? {
        let url = directory.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(StoredAIMessage.self, from: data).toAIMessage()
    }

    public func save(key: String, response: AIMessage) async throws {
        let url = directory.appendingPathComponent("\(key).json")
        let encoded = try JSONEncoder().encode(StoredAIMessage(from: response))
        try encoded.write(to: url, options: .atomic)
    }
}

private struct StoredAIMessage: Codable {
    let content: String
    let toolCalls: [ToolCall]
    let usage: UsageMetadata?
    let responseMetadata: [String: JSONValue]
    let id: String?
    let name: String?

    init(from message: AIMessage) {
        self.content = message.content
        self.toolCalls = message.toolCalls
        self.usage = message.usageMetadata
        self.responseMetadata = message.responseMetadata
        self.id = message.id
        self.name = message.name
    }

    func toAIMessage() -> AIMessage {
        AIMessage(
            content: content,
            toolCalls: toolCalls,
            usageMetadata: usage,
            responseMetadata: responseMetadata,
            name: name,
            id: id
        )
    }
}

private func cacheKey(messages: [any Message], modelName: String) -> String {
    var hasher = SHA256()
    hasher.update(data: Data(modelName.utf8))
    for message in messages {
        hasher.update(data: Data(message.role.rawValue.utf8))
        hasher.update(data: Data([0x00]))
        hasher.update(data: Data(message.content.utf8))
        hasher.update(data: Data([0x01]))
    }
    let digest = hasher.finalize()
    return digest.map { String(format: "%02x", $0) }.joined()
}
