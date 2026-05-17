import Foundation
import CryptoKit

public enum IndexCleanupMode: Sendable {
    case none
    /// Drop records (and their vector-store entries) whose source key wasn't seen in this run.
    case full
}

public struct IndexResult: Sendable, Equatable {
    public let added: Int
    public let updated: Int
    public let skipped: Int
    public let deleted: Int

    public init(added: Int, updated: Int, skipped: Int, deleted: Int) {
        self.added = added
        self.updated = updated
        self.skipped = skipped
        self.deleted = deleted
    }
}

/// Incrementally index a list of documents into a vector store. Unchanged documents (by source
/// key + content hash) are skipped; changed ones are deleted + re-inserted; missing ones are
/// optionally garbage-collected with `cleanup: .full`.
///
/// `sourceKey` extracts a stable key from a `Document` — typically a file path or URL. Falls
/// back to the document's `id`.
public func index(
    documents: [Document],
    vectorStore: any VectorStore,
    recordManager: any RecordManager,
    namespace: String = "default",
    cleanup: IndexCleanupMode = .none,
    sourceKey: @Sendable (Document) -> String = { $0.metadata["source"]?.stringValue ?? $0.id ?? UUID().uuidString }
) async throws -> IndexResult {
    var added = 0
    var updated = 0
    var skipped = 0
    var seenKeys = Set<String>()

    var toAdd: [Document] = []

    for document in documents {
        let key = sourceKey(document)
        seenKeys.insert(key)
        let hash = contentHash(document.pageContent)
        let existing = try await recordManager.hash(forKey: key, namespace: namespace)
        if existing == hash {
            skipped += 1
            continue
        }
        if existing != nil {
            _ = try await vectorStore.deleteDocuments(ids: [key])
            updated += 1
        } else {
            added += 1
        }
        try await recordManager.setHash(hash, forKey: key, namespace: namespace)
        var withID = document
        if document.id == nil {
            withID = Document(pageContent: document.pageContent, metadata: document.metadata, id: key)
        }
        toAdd.append(withID)
    }

    if !toAdd.isEmpty {
        _ = try await vectorStore.addDocuments(toAdd)
    }

    var deleted = 0
    if cleanup == .full {
        let existingKeys = try await recordManager.keys(in: namespace)
        let stale = existingKeys.filter { !seenKeys.contains($0) }
        if !stale.isEmpty {
            deleted = try await vectorStore.deleteDocuments(ids: stale)
            for key in stale {
                try await recordManager.delete(key: key, namespace: namespace)
            }
        }
    }

    return IndexResult(added: added, updated: updated, skipped: skipped, deleted: deleted)
}

func contentHash(_ text: String) -> String {
    var hasher = SHA256()
    hasher.update(data: Data(text.utf8))
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}
