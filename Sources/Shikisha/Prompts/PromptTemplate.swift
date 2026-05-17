import Foundation

/// Thrown when a template references a variable that wasn't supplied.
public struct MissingPromptVariableError: Error, CustomStringConvertible, Sendable {
    public let variable: String

    public init(variable: String) { self.variable = variable }

    public var description: String { "Missing prompt variable: \(variable)" }
}

// swiftlint:disable:next force_try
private let variableRegex = try! NSRegularExpression(pattern: #"\{([A-Za-z_][A-Za-z0-9_]*)\}"#)

/// A mustache-style `{variable}` text template. Substitution is purely lexical — no escapes,
/// no conditional logic. Use `ChatPromptTemplate` to build multi-message prompts.
public struct PromptTemplate: Sendable, Runnable {
    public typealias Input = [String: any Sendable]
    public typealias Output = String

    public let template: String
    public let inputVariables: [String]
    public let partialVariables: [String: any Sendable]

    private init(template: String, inputVariables: [String], partialVariables: [String: any Sendable]) {
        self.template = template
        self.inputVariables = inputVariables
        self.partialVariables = partialVariables
    }

    public static func fromTemplate(
        _ template: String,
        partialVariables: [String: any Sendable] = [:]
    ) -> PromptTemplate {
        let allVars = extractVariables(template)
        let inputs = allVars.filter { !partialVariables.keys.contains($0) }
        return PromptTemplate(template: template, inputVariables: inputs, partialVariables: partialVariables)
    }

    public func format(_ variables: [String: any Sendable] = [:]) throws -> String {
        let merged = partialVariables.merging(variables) { _, new in new }
        return try substitute(template: template, variables: merged)
    }

    public func partial(_ variables: [String: any Sendable]) -> PromptTemplate {
        let merged = partialVariables.merging(variables) { _, new in new }
        let remaining = inputVariables.filter { !merged.keys.contains($0) }
        return PromptTemplate(template: template, inputVariables: remaining, partialVariables: merged)
    }

    public func invoke(_ input: [String: any Sendable]) async throws -> String {
        try format(input)
    }
}

func extractVariables(_ template: String) -> [String] {
    let nsTemplate = template as NSString
    let range = NSRange(location: 0, length: nsTemplate.length)
    var seen = Set<String>()
    var ordered: [String] = []
    variableRegex.enumerateMatches(in: template, range: range) { match, _, _ in
        guard let match, match.numberOfRanges > 1 else { return }
        let name = nsTemplate.substring(with: match.range(at: 1))
        if seen.insert(name).inserted {
            ordered.append(name)
        }
    }
    return ordered
}

func substitute(template: String, variables: [String: any Sendable]) throws -> String {
    let nsTemplate = template as NSString
    let range = NSRange(location: 0, length: nsTemplate.length)
    let matches = variableRegex.matches(in: template, range: range)
    var result = ""
    var cursor = 0
    for match in matches {
        let prefix = nsTemplate.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
        result.append(prefix)
        let key = nsTemplate.substring(with: match.range(at: 1))
        guard let value = variables[key] else {
            throw MissingPromptVariableError(variable: key)
        }
        result.append(String(describing: value))
        cursor = match.range.location + match.range.length
    }
    if cursor < nsTemplate.length {
        result.append(nsTemplate.substring(from: cursor))
    }
    return result
}
