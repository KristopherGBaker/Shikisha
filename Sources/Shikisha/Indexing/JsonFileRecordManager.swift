import Foundation

/// JSON-file backing for `RecordManager`. One file holds all namespaces. Safe for single-process.
public actor JsonFileRecordManager: RecordManager {
    public let file: URL
    private var records: [String: [String: String]] = [:]

    public init(file: URL) throws {
        self.file = file
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: file),
           let stored = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            records = stored
        }
    }

    public func hash(forKey key: String, namespace: String) async throws -> String? {
        records[namespace]?[key]
    }

    public func setHash(_ hash: String, forKey key: String, namespace: String) async throws {
        records[namespace, default: [:]][key] = hash
        try persist()
    }

    public func keys(in namespace: String) async throws -> [String] {
        Array((records[namespace] ?? [:]).keys)
    }

    public func delete(key: String, namespace: String) async throws {
        records[namespace]?.removeValue(forKey: key)
        try persist()
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(records)
        try data.write(to: file, options: .atomic)
    }
}
