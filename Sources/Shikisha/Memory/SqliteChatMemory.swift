import Foundation
import SQLite3

/// Persistent `ChatMemory` backed by SQLite. Per-session isolation via `sessionID`.
public actor SqliteChatMemory: ChatMemory {
    public let file: URL
    public let sessionID: String

    private nonisolated(unsafe) var db: OpaquePointer?

    public init(file: URL, sessionID: String) throws {
        self.file = file
        self.sessionID = sessionID
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        var handle: OpaquePointer?
        if sqlite3_open(file.path, &handle) != SQLITE_OK {
            throw HTTPError.transport(message: "sqlite open failed")
        }
        self.db = handle
        try Self.exec(handle!, sql: """
            CREATE TABLE IF NOT EXISTS shikisha_memory (
                session_id TEXT NOT NULL,
                ordinal INTEGER NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                name TEXT,
                message_id TEXT,
                tool_call_id TEXT,
                PRIMARY KEY (session_id, ordinal)
            );
        """)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    public func addMessage(_ message: any Message) async throws {
        guard let db else { throw HTTPError.transport(message: "sqlite not open") }
        let nextOrdinal = try nextOrdinal()
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, """
            INSERT INTO shikisha_memory (session_id, ordinal, role, content, name, message_id, tool_call_id)
            VALUES (?, ?, ?, ?, ?, ?, ?);
        """, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionID, -1, SQLiteUtils.transient)
        sqlite3_bind_int64(stmt, 2, Int64(nextOrdinal))
        sqlite3_bind_text(stmt, 3, message.role.rawValue, -1, SQLiteUtils.transient)
        sqlite3_bind_text(stmt, 4, message.content, -1, SQLiteUtils.transient)
        if let name = message.name {
            sqlite3_bind_text(stmt, 5, name, -1, SQLiteUtils.transient)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        if let id = message.id {
            sqlite3_bind_text(stmt, 6, id, -1, SQLiteUtils.transient)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        if let toolMessage = message as? ToolMessage {
            sqlite3_bind_text(stmt, 7, toolMessage.toolCallId, -1, SQLiteUtils.transient)
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HTTPError.transport(message: "sqlite insert failed")
        }
    }

    public func messages() async throws -> [any Message] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, """
            SELECT role, content, name, message_id, tool_call_id
            FROM shikisha_memory
            WHERE session_id = ?
            ORDER BY ordinal ASC;
        """, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionID, -1, SQLiteUtils.transient)
        var result: [any Message] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let roleC = sqlite3_column_text(stmt, 0),
                  let contentC = sqlite3_column_text(stmt, 1) else { continue }
            let role = String(cString: roleC)
            let content = String(cString: contentC)
            let name = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let messageID = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let toolCallID = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            if let message = SqliteChatMemory.materialize(
                role: role,
                content: content,
                name: name,
                id: messageID,
                toolCallID: toolCallID
            ) {
                result.append(message)
            }
        }
        return result
    }

    public func clear() async throws {
        guard let db else { return }
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "DELETE FROM shikisha_memory WHERE session_id = ?;", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionID, -1, SQLiteUtils.transient)
        sqlite3_step(stmt)
    }

    private func nextOrdinal() throws -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        let sql = "SELECT COALESCE(MAX(ordinal), -1) + 1 FROM shikisha_memory WHERE session_id = ?;"
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionID, -1, SQLiteUtils.transient)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    private static func materialize(
        role: String,
        content: String,
        name: String?,
        id: String?,
        toolCallID: String?
    ) -> (any Message)? {
        switch role {
        case "system": return SystemMessage(content: content, name: name, id: id)
        case "user": return HumanMessage(content: content, name: name, id: id)
        case "assistant": return AIMessage(content: content, name: name, id: id)
        case "tool":
            guard let toolCallID else { return nil }
            return ToolMessage(content: content, toolCallId: toolCallID, name: name, id: id)
        default: return nil
        }
    }

    private static func exec(_ db: OpaquePointer, sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(error)
            throw HTTPError.transport(message: "sqlite exec failed: \(message)")
        }
    }
}

enum SQLiteUtils {
    static let transient: sqlite3_destructor_type = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
