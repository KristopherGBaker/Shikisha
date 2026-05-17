import Foundation
import SQLite3

/// SQLite-backed vector store. Vectors are stored as `BLOB`s; similarity is computed in Swift
/// (no `sqlite-vec` extension dependency). Good for corpora up to ~100K documents on a Mac;
/// larger workloads should use a dedicated vector database.
public actor SqliteVectorStore: VectorStore {
    public nonisolated let embeddings: any Embeddings
    public let file: URL

    // `nonisolated(unsafe)` so `deinit` can close the handle without hopping back onto the actor;
    // SQLite handles are owned by this actor for their entire lifetime, so external access is moot.
    private nonisolated(unsafe) var db: OpaquePointer?

    public init(file: URL, embeddings: any Embeddings) throws {
        self.embeddings = embeddings
        self.file = file
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let result = sqlite3_open(file.path, &db)
        guard result == SQLITE_OK, let handle = db else {
            throw HTTPError.transport(message: "sqlite open failed: \(result)")
        }
        try Self.exec(handle, sql: """
            CREATE TABLE IF NOT EXISTS shikisha_vectors (
                id TEXT PRIMARY KEY,
                page_content TEXT NOT NULL,
                metadata TEXT NOT NULL,
                vector BLOB NOT NULL
            );
        """)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    public func addDocuments(_ documents: [Document]) async throws -> [String] {
        guard !documents.isEmpty else { return [] }
        let vectors = try await embeddings.embedDocuments(documents.map(\.pageContent))
        guard let db else { throw HTTPError.transport(message: "sqlite not opened") }
        var ids: [String] = []
        try Self.exec(db, sql: "BEGIN;")
        do {
            for (document, vector) in zip(documents, vectors) {
                let id = document.id ?? UUID().uuidString
                let metadataData = try JSONEncoder().encode(document.metadata)
                let metadataString = String(data: metadataData, encoding: .utf8) ?? "{}"
                try insert(db: db, id: id, content: document.pageContent, metadata: metadataString, vector: vector)
                ids.append(id)
            }
            try Self.exec(db, sql: "COMMIT;")
        } catch {
            try? Self.exec(db, sql: "ROLLBACK;")
            throw error
        }
        return ids
    }

    public func deleteDocuments(ids: [String]) async throws -> Int {
        guard let db, !ids.isEmpty else { return 0 }
        var removed = 0
        for id in ids {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, "DELETE FROM shikisha_vectors WHERE id = ?;", -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_DONE {
                removed += Int(sqlite3_changes(db))
            }
        }
        return removed
    }

    public func similaritySearch(query: String, k: Int, filter: MetadataFilter?) async throws -> [VectorSearchResult] {
        let queryVector = try await embeddings.embedQuery(query)
        guard let db else { throw HTTPError.transport(message: "sqlite not opened") }
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT id, page_content, metadata, vector FROM shikisha_vectors;", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        var results: [VectorSearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idC = sqlite3_column_text(stmt, 0),
                  let contentC = sqlite3_column_text(stmt, 1),
                  let metaC = sqlite3_column_text(stmt, 2),
                  let blob = sqlite3_column_blob(stmt, 3) else { continue }
            let blobBytes = sqlite3_column_bytes(stmt, 3)
            let id = String(cString: idC)
            let content = String(cString: contentC)
            let metaString = String(cString: metaC)
            let metadata = (try? JSONDecoder().decode([String: JSONValue].self, from: Data(metaString.utf8))) ?? [:]
            if let filter, !filter.matches(metadata) { continue }
            let vector = decodeVector(pointer: blob, byteCount: Int(blobBytes))
            let document = Document(pageContent: content, metadata: metadata, id: id)
            results.append(VectorSearchResult(document: document, score: cosineSimilarity(queryVector, vector)))
        }
        results.sort { $0.score > $1.score }
        return Array(results.prefix(k))
    }

    private func insert(db: OpaquePointer, id: String, content: String, metadata: String, vector: [Float]) throws {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, """
            INSERT INTO shikisha_vectors (id, page_content, metadata, vector)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                page_content = excluded.page_content,
                metadata = excluded.metadata,
                vector = excluded.vector;
        """, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, content, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, metadata, -1, SQLITE_TRANSIENT)
        let data = encodeVector(vector)
        try data.withUnsafeBytes { rawBuffer in
            sqlite3_bind_blob(stmt, 4, rawBuffer.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw HTTPError.transport(message: "sqlite insert failed")
            }
        }
    }

    private static func exec(_ db: OpaquePointer, sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "unknown sqlite error"
            sqlite3_free(error)
            throw HTTPError.transport(message: "sqlite exec failed: \(message)")
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func encodeVector(_ vector: [Float]) -> Data {
    var data = Data(capacity: vector.count * MemoryLayout<Float>.size)
    for value in vector {
        var bits = value.bitPattern.littleEndian
        withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
    }
    return data
}

private func decodeVector(pointer: UnsafeRawPointer, byteCount: Int) -> [Float] {
    let count = byteCount / MemoryLayout<UInt32>.size
    var vector: [Float] = []
    vector.reserveCapacity(count)
    let buffer = pointer.assumingMemoryBound(to: UInt32.self)
    for index in 0..<count {
        let bits = UInt32(littleEndian: buffer[index])
        vector.append(Float(bitPattern: bits))
    }
    return vector
}
