import Foundation
import CryptoKit

/// Wrap any `Embeddings` with a content-addressed cache. Hits avoid the round-trip;
/// misses are forwarded to the wrapped provider and stored for next time.
public actor CachingEmbeddings: Embeddings {
    public nonisolated var modelName: String { wrapped.modelName }
    public nonisolated var dimensions: Int? { wrapped.dimensions }

    private let wrapped: any Embeddings
    private var memory: [String: [Float]] = [:]
    private let storage: (any EmbeddingsCacheStorage)?

    public init(_ wrapped: any Embeddings, storage: (any EmbeddingsCacheStorage)? = nil) {
        self.wrapped = wrapped
        self.storage = storage
    }

    public nonisolated func embedDocuments(_ texts: [String]) async throws -> [[Float]] {
        var results = Array<[Float]?>(repeating: nil, count: texts.count)
        var misses: [(Int, String)] = []
        for (index, text) in texts.enumerated() {
            let key = cacheKey(text: text, modelName: wrapped.modelName)
            if let cached = await lookup(key) {
                results[index] = cached
            } else {
                misses.append((index, text))
            }
        }
        guard !misses.isEmpty else {
            return results.compactMap { $0 }
        }

        let textsToEmbed = misses.map(\.1)
        let fresh = try await wrapped.embedDocuments(textsToEmbed)
        precondition(fresh.count == misses.count, "provider returned \(fresh.count) vectors for \(misses.count) texts")
        for ((originalIndex, text), vector) in zip(misses, fresh) {
            results[originalIndex] = vector
            await store(cacheKey(text: text, modelName: wrapped.modelName), vector: vector)
        }
        return results.compactMap { $0 }
    }

    private func lookup(_ key: String) async -> [Float]? {
        if let cached = memory[key] { return cached }
        if let storage, let cached = try? await storage.load(key: key) {
            memory[key] = cached
            return cached
        }
        return nil
    }

    private func store(_ key: String, vector: [Float]) async {
        memory[key] = vector
        if let storage { try? await storage.save(key: key, vector: vector) }
    }
}

public protocol EmbeddingsCacheStorage: Sendable {
    func load(key: String) async throws -> [Float]?
    func save(key: String, vector: [Float]) async throws
}

/// File-backed JSON dictionary of `key -> vector`. Safe under the assumption that
/// only one `CachingEmbeddings` actor instance writes to the file at a time — the
/// surrounding actor serializes calls; cross-process write contention is out of scope.
public actor FileEmbeddingsCacheStorage: EmbeddingsCacheStorage {
    public let file: URL

    public init(file: URL) throws {
        self.file = file
        let dir = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: file.path) {
            try "{}".data(using: .utf8)!.write(to: file)
        }
    }

    public func load(key: String) async throws -> [Float]? {
        let data = try Data(contentsOf: file)
        let dict = (try? JSONDecoder().decode([String: [Float]].self, from: data)) ?? [:]
        return dict[key]
    }

    public func save(key: String, vector: [Float]) async throws {
        let data = (try? Data(contentsOf: file)) ?? Data()
        var dict = (try? JSONDecoder().decode([String: [Float]].self, from: data)) ?? [:]
        dict[key] = vector
        let encoded = try JSONEncoder().encode(dict)
        try encoded.write(to: file, options: .atomic)
    }
}

private func cacheKey(text: String, modelName: String) -> String {
    var hasher = SHA256()
    hasher.update(data: Data(modelName.utf8))
    hasher.update(data: Data([0x00]))
    hasher.update(data: Data(text.utf8))
    let digest = hasher.finalize()
    return digest.map { String(format: "%02x", $0) }.joined()
}
