import Foundation
import Shikisha

// The agent operates inside one directory — a simple sandbox.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
@Sendable func resolve(_ path: String) -> URL { root.appendingPathComponent(path) }

// Tool 1 — let the model read a file.
struct ReadFileArgs: Decodable { let path: String }

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

// A tool-capable model must be built WITH the tool specs so it can emit tool calls.
// The agent only *executes* them — this split is easy to miss.
let tools: [any Tool] = [readFile]
let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let model = OpenAIChatModel(
    config: OpenAIConfig(apiKey: apiKey),
    model: "gpt-4o",
    tools: tools.map { $0.toOpenAISpec() }
)
let agent = ToolCallingAgent(model: model, tools: tools, maxIterations: 10)

let result = try await agent.run([
    SystemMessage(content: "You are a coding assistant working in the current directory."),
    HumanMessage(content: "What does Package.swift declare?")
])
print(result.finalMessage.content)
