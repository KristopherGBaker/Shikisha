import Foundation
import Shikisha

// Typed arguments for the file tools (same shapes as the coding-agent tutorial).

struct ReadFileArgs: Decodable {
    let path: String
}

struct ListFilesArgs: Decodable {
    let path: String?
}

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

/// The coding agent's tools, scoped to a sandbox directory so the agent can't escape it.
enum AgentTools {
    static func fileTools(root: URL) -> [any Tool] {
        @Sendable func resolve(_ path: String) -> URL { root.appendingPathComponent(path) }

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
            description: "List entries in a directory (defaults to the sandbox root).",
            inputSchema: JSONSchema.object(
                properties: ["path": JSONSchema.string(description: "Relative directory path")]
            ),
            execute: { (args: ListFilesArgs) in
                let dir = resolve(args.path ?? ".")
                let entries = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
                return entries.isEmpty ? "(empty)" : entries.sorted().joined(separator: "\n")
            }
        )

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
                guard current.contains(args.oldStr) else {
                    return "ERROR: old_str not found in \(args.path)"
                }
                try current.replacingOccurrences(of: args.oldStr, with: args.newStr)
                    .write(to: url, atomically: true, encoding: .utf8)
                return "Edited \(args.path)"
            }
        )

        return [readFile, listFiles, editFile]
    }
}
