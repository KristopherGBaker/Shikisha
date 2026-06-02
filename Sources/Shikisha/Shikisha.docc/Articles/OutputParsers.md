# Output Parsers

Turn the model's text into values your code can use.

## Overview

A model returns text. An output parser converts that text into a `String`, a list, a JSON
object, a date, or a typed Swift value. Parsers are `Runnable`s whose `Input` is an
``AIMessage``, so you pipe them onto the end of a chain:

```swift
let chain = prompt |> model |> StringOutputParser()
```

Choosing a parser is mostly about the shape you want back.

### Text and lists

```swift
StringOutputParser()                 // AIMessage -> String (just the content)
CommaSeparatedListOutputParser()     // "a, b, c"          -> ["a", "b", "c"]
LineSeparatedListOutputParser()      // one item per line  -> [String]
NumberedListOutputParser()           // strips "1." / "1)" -> [String]
```

`CommaSeparatedListOutputParser` is the classic pairing with a prompt like *"Return a
comma-separated list."*

### JSON

```swift
let json = try await (model |> JSONOutputParser()).invoke(messages)   // -> JSONValue
let title = json["title"]?.stringValue
```

For tabular text, ``CsvOutputParser`` returns `[[String]]` (rows of fields, with a configurable
delimiter).

### Structured (typed) output

When you want a `Decodable` Swift type, use ``StructuredOutputParser`` — see
<doc:StructuredOutput> for the full pattern, including generating a JSON Schema and constraining
the model.

```swift
struct Person: Decodable { let name: String; let age: Int }
let person = try await (model |> StructuredOutputParser<Person>()).invoke(messages)
```

### XML, regex, and dates

```swift
let element = try await (model |> XmlOutputParser()).invoke(messages)   // -> XMLElement tree
let name = element.child(named: "name")?.text

let fields = try await (model |> RegexOutputParser(pattern: #"Name: (\w+)"#,
                                                   groupNames: ["name"])).invoke(messages)

let due = try await (model |> ISODateOutputParser()).invoke(messages)   // "2026-06-02" -> Date
```

### Streaming partial JSON

While a model is *still streaming* a JSON object, you can parse the incomplete buffer to drive a
live UI. ``PartialJSON`` tolerates truncated input:

```swift
var buffer = ""
for try await chunk in model.stream(messages) {
    buffer += chunk.content
    if let partial = PartialJSON.parse(buffer) {
        render(partial)            // update the UI as fields fill in
    }
}
```

### Self-fixing output

Models sometimes return *almost*-valid output. ``OutputFixingParser`` wraps another parser: if
parsing throws, it asks a model to repair the text and retries.

```swift
let robust = OutputFixingParser(
    parser: StructuredOutputParser<Person>(),
    fixer: model,
    maxRetries: 1
)
```

**Use it when** you parse strict formats from a less reliable/cheaper model and want a safety
net without writing repair logic yourself.

## Topics

### Text and lists

- ``StringOutputParser``
- ``CommaSeparatedListOutputParser``
- ``LineSeparatedListOutputParser``
- ``NumberedListOutputParser``
- ``CsvOutputParser``

### Structured

- ``JSONOutputParser``
- ``StructuredOutputParser``
- ``XmlOutputParser``
- ``XMLElement``
- ``RegexOutputParser``
- ``ISODateOutputParser``
- ``ISODateTimeOutputParser``

### Streaming and recovery

- ``PartialJSON``
- ``OutputFixingParser``

## See Also

- <doc:StructuredOutput>
- <doc:ChatModels>
