import Foundation
import Shikisha

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
@Sendable func resolve(_ path: String) -> URL { root.appendingPathComponent(path) }

struct ReadFileArgs: Decodable { let path: String }
struct ListFilesArgs: Decodable { let path: String? }
struct EditFileArgs: Decodable {
    let path: String
    let oldStr: String
    let newStr: String
    enum CodingKeys: String, CodingKey {
        case path
        case oldStr = "old_str"
        case newStr = "new_str"
    }
}

let readFile = TypedTool(
    name: "read_file",
    description: "Read the contents of a file at a relative path.",
    inputSchema: JSONSchema.object(
        properties: ["path": JSONSchema.string(description: "Relative file path")],
        required: ["path"]
    ),
    execute: { (args: ReadFileArgs) in
        (try? String(contentsOf: resolve(args.path), encoding: .utf8))
            ?? "ERROR: cannot read \(args.path)"
    }
)

let listFiles = TypedTool(
    name: "list_files",
    description: "List entries in a directory (defaults to the project root).",
    inputSchema: JSONSchema.object(
        properties: ["path": JSONSchema.string(description: "Relative directory path")]
    ),
    execute: { (args: ListFilesArgs) in
        let dir = resolve(args.path ?? ".")
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return entries.sorted().joined(separator: "\n")
    }
)

// Tool 3 — give it hands. edit_file replaces old_str with new_str, or creates the file
// when old_str is empty. That single operation is enough to write whole files or patch them.
let editFile = TypedTool(
    name: "edit_file",
    description: """
        Edit a text file. Replaces the first occurrence of old_str with new_str. \
        If old_str is empty, creates the file with new_str as its contents.
        """,
    inputSchema: JSONSchema.object(
        properties: [
            "path": JSONSchema.string(description: "Relative file path"),
            "old_str": JSONSchema.string(description: "Text to replace (empty to create the file)"),
            "new_str": JSONSchema.string(description: "Replacement text")
        ],
        required: ["path", "old_str", "new_str"]
    ),
    execute: { (args: EditFileArgs) in
        let url = resolve(args.path)
        if args.oldStr.isEmpty {
            try args.newStr.write(to: url, atomically: true, encoding: .utf8)
            return "Created \(args.path)"
        }
        let current = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        guard current.contains(args.oldStr) else { return "ERROR: old_str not found in \(args.path)" }
        try current.replacingOccurrences(of: args.oldStr, with: args.newStr)
            .write(to: url, atomically: true, encoding: .utf8)
        return "Edited \(args.path)"
    }
)

let tools: [any Tool] = [readFile, listFiles, editFile]
let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let model = OpenAIChatModel(
    config: OpenAIConfig(apiKey: apiKey),
    model: "gpt-4o",
    tools: tools.map { $0.toOpenAISpec() }
)
let agent = ToolCallingAgent(model: model, tools: tools, maxIterations: 15)

let result = try await agent.run([
    SystemMessage(content: "You are a coding assistant working in the current directory."),
    HumanMessage(content: "Create greet.swift with a greet(_:) function that prints a hello.")
])
print(result.finalMessage.content)
