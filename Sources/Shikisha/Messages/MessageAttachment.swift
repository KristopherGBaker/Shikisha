import Foundation

/// A non-text attachment on a `HumanMessage`. Providers that support the type
/// translate it into their wire shape; others silently ignore it.
public enum MessageAttachment: Sendable, Hashable {
    /// An image referenced by URL.
    case imageURL(url: String, detail: ImageDetail? = nil)

    /// An image inlined as base64-encoded bytes.
    case imageBase64(data: String, mediaType: String, detail: ImageDetail? = nil)
}

public enum ImageDetail: String, Codable, Sendable, CaseIterable {
    case auto
    case low
    case high
}

public extension MessageAttachment {
    /// Convenience: wrap raw `Data` into a base64 attachment.
    static func imageData(_ data: Data, mediaType: String, detail: ImageDetail? = nil) -> MessageAttachment {
        .imageBase64(data: data.base64EncodedString(), mediaType: mediaType, detail: detail)
    }
}
