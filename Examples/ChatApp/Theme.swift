import SwiftUI

/// "Ink & Ember" — a warm, dark terminal-journal palette. Defined explicitly (rather than via
/// system semantic colors) so the app looks identical and intentional on macOS and iOS
/// regardless of the user's light/dark setting.
enum Theme {
    static let base = Color(red: 0.063, green: 0.055, blue: 0.047)
    static let raised = Color(red: 0.105, green: 0.094, blue: 0.082)

    static let ink = Color(red: 0.945, green: 0.915, blue: 0.855)
    static let inkSoft = Color(red: 0.945, green: 0.915, blue: 0.855).opacity(0.62)
    static let inkFaint = Color(red: 0.945, green: 0.915, blue: 0.855).opacity(0.30)

    static let ember = Color(red: 0.957, green: 0.580, blue: 0.204)
    static let emberDeep = Color(red: 0.851, green: 0.357, blue: 0.129)

    static let hairline = Color.white.opacity(0.08)

    /// Atmospheric ground: a subtle warm vertical gradient instead of a flat fill.
    static var ground: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.094, green: 0.082, blue: 0.071), base],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Diagonal ember used for the send affordance and user-bubble edge.
    static var emberStroke: LinearGradient {
        LinearGradient(colors: [ember, emberDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The "machine voice": monospaced, for the wordmark, tool-call chips, and hints.
    static func mono(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced).weight(weight)
    }
}
