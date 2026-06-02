import Foundation
import Shikisha

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
@Sendable func resolve(_ path: String) -> URL { root.appendingPathComponent(path) }

struct ReadFileArgs: Decodable { let path: String }
struct ListFilesArgs: Decodable { let path: String? }

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

// Tool 2 — let the model discover what's there.
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

let tools: [any Tool] = [readFile, listFiles]
let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let model = OpenAIChatModel(
    config: OpenAIConfig(apiKey: apiKey),
    model: "gpt-4o",
    tools: tools.map { $0.toOpenAISpec() }
)
let agent = ToolCallingAgent(model: model, tools: tools, maxIterations: 12)

let result = try await agent.run([
    SystemMessage(content: "You are a coding assistant working in the current directory."),
    HumanMessage(content: "What Swift files are in Sources, and what does the main one do?")
])
print(result.finalMessage.content)
