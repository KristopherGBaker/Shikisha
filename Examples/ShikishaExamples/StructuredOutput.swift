import Foundation
import Shikisha

/// Often you want a *typed* value back from the model rather than free-form text. Describe the
/// shape with ``JSONSchema``, ask the model to return JSON, and decode it into a `Decodable`
/// Swift type with ``StructuredOutputParser`` (or the `asStructuredOutput(_:)` convenience).
enum StructuredOutputExample {
    struct Recipe: Decodable {
        let title: String
        let ingredients: [String]
        let minutes: Int
    }

    static func run() async throws {
        // A JSON Schema you can pass to a provider's structured-output / response-format option
        // (e.g. `OpenAIResponseFormat.jsonSchema(name:schema:)`) so the model is constrained to
        // emit matching JSON.
        let schema = JSONSchema.object(
            properties: [
                "title": JSONSchema.string(description: "Name of the dish"),
                "ingredients": JSONSchema.array(items: JSONSchema.string()),
                "minutes": JSONSchema.integer(description: "Total time in minutes")
            ],
            required: ["title", "ingredients", "minutes"]
        )
        section("Generated JSON Schema")
        print(schema.serialized(prettyPrinted: true))

        // The model returns a JSON object as its text content. A real provider would be told to
        // honor `schema`; here we hand `FakeChatModel` a matching reply.
        let json = #"{"title":"Miso Soup","ingredients":["dashi","miso","tofu","scallion"],"minutes":15}"#
        let model = FakeChatModel(responses: [AIMessage(content: json)])

        // Decode straight from an `AIMessage` with `StructuredOutputParser`.
        let parser = StructuredOutputParser<Recipe>()
        let reply = try await model.invoke([HumanMessage(content: "Give me a quick recipe as JSON.")])
        let recipe = try await parser.invoke(reply)

        section("Decoded value")
        print("title:       \(recipe.title)")
        print("ingredients: \(recipe.ingredients.joined(separator: ", "))")
        print("minutes:     \(recipe.minutes)")

        // The same thing as a single runnable: `model.asStructuredOutput(Recipe.self)` invokes
        // the model and decodes in one step.
        let structured = model.asStructuredOutput(Recipe.self)
        _ = structured  // shown for reference; reuse `model` would need another queued response
    }
}
