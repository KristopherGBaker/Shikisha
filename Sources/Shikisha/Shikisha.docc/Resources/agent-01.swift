import Foundation
import Shikisha

// A tool is a Swift function the model can choose to call. TypedTool decodes the
// arguments into a Decodable struct for you.
struct AddArgs: Decodable { let a: Int; let b: Int }

let add = TypedTool(
    name: "add",
    description: "Add two integers and return the sum.",
    inputSchema: JSONSchema.object(
        properties: [
            "a": JSONSchema.integer(description: "First addend"),
            "b": JSONSchema.integer(description: "Second addend")
        ],
        required: ["a", "b"]
    ),
    execute: { (args: AddArgs) in String(args.a + args.b) }
)
