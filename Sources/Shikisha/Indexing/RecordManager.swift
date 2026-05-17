import Foundation

/// Tracks which document hashes have been indexed into a vector store, so re-runs of
/// `index(...)` can skip unchanged documents, update changed ones, and (with `.full` cleanup)
/// drop documents no longer present in the source.
public protocol RecordManager: Sendable {
    /// Look up the stored hash for a given source key, scoped to a namespace.
    func hash(forKey key: String, namespace: String) async throws -> String?

    /// Record (or overwrite) the hash for a key.
    func setHash(_ hash: String, forKey key: String, namespace: String) async throws

    /// All keys currently tracked in a namespace.
    func keys(in namespace: String) async throws -> [String]

    /// Drop the record for a key (after the corresponding vector-store entry is deleted).
    func delete(key: String, namespace: String) async throws
}

public actor InMemoryRecordManager: RecordManager {
    private var records: [String: [String: String]] = [:]  // namespace -> key -> hash

    public init() {}

    public func hash(forKey key: String, namespace: String) async throws -> String? {
        records[namespace]?[key]
    }

    public func setHash(_ hash: String, forKey key: String, namespace: String) async throws {
        records[namespace, default: [:]][key] = hash
    }

    public func keys(in namespace: String) async throws -> [String] {
        Array((records[namespace] ?? [:]).keys)
    }

    public func delete(key: String, namespace: String) async throws {
        records[namespace]?.removeValue(forKey: key)
    }
}
