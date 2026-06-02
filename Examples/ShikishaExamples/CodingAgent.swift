import Foundation
import Shikisha

// Typed arguments for the file tools. Declared at file scope so the snake_case
// CodingKeys stay within the project's nesting limits.

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

/// A miniature coding agent — inspired by "how to build an agent": a model, a few file tools,
/// and a loop. ``ToolCallingAgent`` provides the loop; the tools give the model the ability to
/// read, list, and edit files inside a sandbox directory.
///
/// This example runs offline with a scripted ``FakeChatModel`` so it needs no API key. The
/// tools execute for real against a temporary directory — watch `greet.swift` appear. See the
/// "Build a Coding Agent" tutorial for the live, provider-backed version.
enum CodingAgentExample {
    /// Build the three file tools, scoped to `root` so the agent can't escape the sandbox.
    static func makeTools(root: URL) -> [any Tool] {
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
                let updated = current.replacingOccurrences(of: args.oldStr, with: args.newStr)
                try updated.write(to: url, atomically: true, encoding: .utf8)
                return "Edited \(args.path)"
            }
        )

        return [readFile, listFiles, editFile]
    }

    static func run() async throws {
        let fileManager = FileManager.default

        // A scratch directory the agent operates in. Cleaned up when we're done.
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("shikisha-coding-agent-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        // Seed the sandbox with a note for the agent to act on.
        try "TODO: add a greet(name) helper that prints a friendly hello.\n"
            .write(to: root.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let tools = makeTools(root: root)

        // Offline, scripted model. With a real provider you must build the model WITH the tool
        // specs so it can emit tool calls — the agent only executes them:
        //
        //   let model = OpenAIChatModel(config: cfg, model: "gpt-4o",
        //                               tools: tools.map { $0.toOpenAISpec() })
        //
        let model = FakeChatModel(responses: [
            AIMessage(content: "", toolCalls: [
                ToolCall(id: "1", name: "list_files", arguments: .object([:]))
            ]),
            AIMessage(content: "", toolCalls: [
                ToolCall(id: "2", name: "read_file", arguments: .object(["path": "notes.txt"]))
            ]),
            AIMessage(content: "", toolCalls: [
                ToolCall(id: "3", name: "edit_file", arguments: .object([
                    "path": "greet.swift",
                    "old_str": "",
                    "new_str": "func greet(_ name: String) {\n    print(\"Hello, \\(name)!\")\n}\n"
                ]))
            ]),
            AIMessage(content: "Done. I read notes.txt and created greet.swift with a greet(_:) helper.")
        ])

        // ConsoleCallback prints each model/tool event so you can watch the loop.
        let agent = ToolCallingAgent(
            model: model,
            tools: tools,
            maxIterations: 8,
            callbacks: CallbackManager(handlers: [ConsoleCallback()])
        )

        let result = try await agent.run([
            SystemMessage(content: "You are a coding assistant working in the project directory."),
            HumanMessage(content: "Read my notes and implement what they ask for.")
        ])

        section("Final answer")
        print(result.finalMessage.content)
        print("(\(result.iterations) iterations)")

        section("Sandbox after the run")
        let entries = (try? fileManager.contentsOfDirectory(atPath: root.path)) ?? []
        for entry in entries.sorted() { print("• \(entry)") }

        section("greet.swift (written by the agent)")
        let created = try? String(contentsOf: root.appendingPathComponent("greet.swift"), encoding: .utf8)
        print(created ?? "(missing)")
    }
}
