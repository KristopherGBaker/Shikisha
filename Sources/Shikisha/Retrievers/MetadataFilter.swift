import Foundation

/// A portable metadata filter tree. Used by both `VectorStore`s and `Retriever`s to apply
/// post-search predicates on document metadata. Translates trivially to most backend filter
/// dialects (Pinecone, Weaviate, …) but the in-memory evaluator covers any backend.
public indirect enum MetadataFilter: Sendable, Hashable {
    case equal(field: String, value: JSONValue)
    case notEqual(field: String, value: JSONValue)
    case greaterThan(field: String, value: JSONValue)
    case greaterThanOrEqual(field: String, value: JSONValue)
    case lessThan(field: String, value: JSONValue)
    case lessThanOrEqual(field: String, value: JSONValue)
    case `in`(field: String, values: [JSONValue])
    case and([MetadataFilter])
    case or([MetadataFilter])
    case not(MetadataFilter)

    /// Evaluate against a single document's metadata map.
    public func matches(_ metadata: [String: JSONValue]) -> Bool {
        switch self {
        case .equal(let field, let value): return metadata[field] == value
        case .notEqual(let field, let value): return metadata[field] != value
        case .greaterThan(let field, let value): return compare(metadata[field], value) == .greater
        case .greaterThanOrEqual(let field, let value):
            let result = compare(metadata[field], value)
            return result == .greater || result == .equal
        case .lessThan(let field, let value): return compare(metadata[field], value) == .less
        case .lessThanOrEqual(let field, let value):
            let result = compare(metadata[field], value)
            return result == .less || result == .equal
        case .in(let field, let values): return metadata[field].map { values.contains($0) } ?? false
        case .and(let filters): return filters.allSatisfy { $0.matches(metadata) }
        case .or(let filters): return filters.contains { $0.matches(metadata) }
        case .not(let filter): return !filter.matches(metadata)
        }
    }

    private enum ComparisonResult { case less, equal, greater, incomparable }

    private func compare(_ lhs: JSONValue?, _ rhs: JSONValue) -> ComparisonResult {
        guard let lhs else { return .incomparable }
        if let left = lhs.doubleValue, let right = rhs.doubleValue {
            if left < right { return .less }
            if left > right { return .greater }
            return .equal
        }
        if let left = lhs.stringValue, let right = rhs.stringValue {
            if left < right { return .less }
            if left > right { return .greater }
            return .equal
        }
        return .incomparable
    }
}
