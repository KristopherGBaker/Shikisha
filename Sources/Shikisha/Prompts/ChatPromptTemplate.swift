import Foundation

/// One slot in a `ChatPromptTemplate`. Each renders to zero or more concrete messages.
public protocol ChatMessageTemplate: Sendable {
    func format(_ variables: [String: any Sendable]) throws -> [any Message]
    var inputVariables: [String] { get }
}

public struct SystemMessageTemplate: ChatMessageTemplate {
    public let template: PromptTemplate

    public init(_ template: PromptTemplate) { self.template = template }
    public init(_ content: String) { self.template = .fromTemplate(content) }

    public func format(_ variables: [String: any Sendable]) throws -> [any Message] {
        [SystemMessage(content: try template.format(variables))]
    }

    public var inputVariables: [String] { template.inputVariables }
}

public struct HumanMessageTemplate: ChatMessageTemplate {
    public let template: PromptTemplate

    public init(_ template: PromptTemplate) { self.template = template }
    public init(_ content: String) { self.template = .fromTemplate(content) }

    public func format(_ variables: [String: any Sendable]) throws -> [any Message] {
        [HumanMessage(content: try template.format(variables))]
    }

    public var inputVariables: [String] { template.inputVariables }
}

public struct AIMessageTemplate: ChatMessageTemplate {
    public let template: PromptTemplate

    public init(_ template: PromptTemplate) { self.template = template }
    public init(_ content: String) { self.template = .fromTemplate(content) }

    public func format(_ variables: [String: any Sendable]) throws -> [any Message] {
        [AIMessage(content: try template.format(variables))]
    }

    public var inputVariables: [String] { template.inputVariables }
}

/// Splice in a previously assembled `[any Message]` value at this position. The variable
/// must be present in the input map (or the placeholder must be marked optional).
public struct MessagesPlaceholder: ChatMessageTemplate {
    public let variableName: String
    public let optional: Bool

    public init(_ variableName: String, optional: Bool = false) {
        self.variableName = variableName
        self.optional = optional
    }

    public func format(_ variables: [String: any Sendable]) throws -> [any Message] {
        guard let value = variables[variableName] else {
            if optional { return [] }
            throw MissingPromptVariableError(variable: variableName)
        }
        guard let messages = value as? [any Message] else {
            throw MissingPromptVariableError(variable: variableName)
        }
        return messages
    }

    public var inputVariables: [String] { optional ? [] : [variableName] }
}

/// Compose a multi-message prompt from per-role templates. `inputVariables` is the union
/// of variables referenced anywhere in the template tree.
public struct ChatPromptTemplate: Sendable, Runnable {
    public typealias Input = [String: any Sendable]
    public typealias Output = [any Message]

    public let messages: [any ChatMessageTemplate]
    public let inputVariables: [String]

    public init(_ messages: [any ChatMessageTemplate]) {
        self.messages = messages
        var seen = Set<String>()
        var ordered: [String] = []
        for template in messages {
            for variable in template.inputVariables where seen.insert(variable).inserted {
                ordered.append(variable)
            }
        }
        self.inputVariables = ordered
    }

    public func formatMessages(_ variables: [String: any Sendable] = [:]) throws -> [any Message] {
        try messages.flatMap { try $0.format(variables) }
    }

    public func invoke(_ input: [String: any Sendable]) async throws -> [any Message] {
        try formatMessages(input)
    }

    /// Convenience initializer mirroring `ChatPromptTemplate.from_messages([("system", ...)])`
    /// in LangChain. The string-typed roles are normalized: `system`, `human`/`user`,
    /// `ai`/`assistant`, and `placeholder`.
    public static func fromTuples(_ tuples: [Tuple]) -> ChatPromptTemplate {
        ChatPromptTemplate(tuples.map(\.template))
    }

    public enum Tuple: Sendable {
        case system(String)
        case human(String)
        case ai(String)
        case placeholder(String, optional: Bool = false)

        public var template: any ChatMessageTemplate {
            switch self {
            case .system(let content): return SystemMessageTemplate(content)
            case .human(let content): return HumanMessageTemplate(content)
            case .ai(let content): return AIMessageTemplate(content)
            case .placeholder(let name, let optional): return MessagesPlaceholder(name, optional: optional)
            }
        }
    }
}
