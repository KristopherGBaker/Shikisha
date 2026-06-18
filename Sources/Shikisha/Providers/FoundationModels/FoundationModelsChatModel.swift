#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// `ChatModel` backed by Apple's on-device Foundation Models (`SystemLanguageModel`). Runs
/// privately on device — no API key, no base URL, no network.
///
/// ## Gating
/// FoundationModels ships only on macOS 26 / iOS 26. To keep Shikisha's package floor at
/// macOS 14 / iOS 17 and its zero-dependency story intact, this whole file is wrapped in
/// `#if canImport(FoundationModels)` and the type is `@available(macOS 26, iOS 26, *)`:
/// - An older toolchain without the SDK simply excludes the type (`canImport` is false);
///   such consumers build exactly as before and never see this symbol.
/// - A current toolchain compiles it, but callers must satisfy the availability annotation,
///   so macOS 14 / iOS 17 builds remain valid — the type just isn't reachable there.
///
/// It lives in the main `Shikisha` target (rather than a separate product) because
/// FoundationModels is a *system* framework, weak-linked via `canImport` — it adds no
/// SwiftPM dependency, so a separate target/product would buy nothing. Keeping it here also
/// means a caller can swap `OpenAIChatModel` → `FoundationModelsChatModel` with no new import.
///
/// ## Streaming
/// `streamResponse(to:)` yields cumulative snapshots; this adapter converts them to the
/// incremental deltas Shikisha's contract expects (see ``CumulativeToDelta``).
///
/// Tool-calling is out of scope for v1.
@available(macOS 26, iOS 26, *)
public struct FoundationModelsChatModel: ChatModel {
    public let modelName: String
    public let config: FoundationModelsConfig
    public let callbacks: CallbackManager

    public init(
        config: FoundationModelsConfig = FoundationModelsConfig(),
        modelName: String = "apple-foundation-models",
        callbacks: CallbackManager = .empty
    ) {
        self.config = config
        self.modelName = modelName
        self.callbacks = callbacks
    }

    public func invoke(_ input: [any Message]) async throws -> AIMessage {
        await callbacks.onLLMStart(model: modelName, messages: input)
        do {
            try checkAvailability()
            let session = makeSession(messages: input)
            let prompt = foundationModelsPrompt(from: input)
            let response = try await session.respond(to: prompt, options: generationOptions)
            let result = AIMessage(content: response.content)
            await callbacks.onLLMEnd(model: modelName, response: result)
            return result
        } catch {
            await callbacks.onLLMError(model: modelName, error: error)
            throw error
        }
    }

    public func stream(_ messages: [any Message]) -> AsyncThrowingStream<AIMessageChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    await callbacks.onLLMStart(model: modelName, messages: messages)
                    try checkAvailability()
                    let session = makeSession(messages: messages)
                    let prompt = foundationModelsPrompt(from: messages)
                    var tracker = CumulativeToDelta()
                    var accumulator = AIMessageChunk()
                    let responses = session.streamResponse(to: prompt, options: generationOptions)
                    for try await snapshot in responses {
                        // FoundationModels yields the whole response so far; emit only the
                        // newly appended suffix so callers that accumulate don't duplicate.
                        let delta = tracker.delta(for: snapshot.content)
                        guard !delta.isEmpty else { continue }
                        let chunk = AIMessageChunk(content: delta)
                        accumulator += chunk
                        continuation.yield(chunk)
                    }
                    await callbacks.onLLMEnd(model: modelName, response: accumulator.toAIMessage())
                    continuation.finish()
                } catch {
                    await callbacks.onLLMError(model: modelName, error: error)
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Private

    private func checkAvailability() throws {
        let state: FMAvailabilityState
        switch SystemLanguageModel.default.availability {
        case .available:
            state = .available
        case .unavailable(let reason):
            state = .unavailable(reason: String(describing: reason))
        @unknown default:
            state = .unavailable(reason: "unknown")
        }
        if let error = foundationModelsAvailabilityError(for: state) {
            throw error
        }
    }

    private func makeSession(messages: [any Message]) -> LanguageModelSession {
        if let instructions = config.instructions ?? foundationModelsInstructions(from: messages) {
            return LanguageModelSession(instructions: instructions)
        }
        return LanguageModelSession()
    }

    private var generationOptions: GenerationOptions {
        GenerationOptions(
            temperature: config.temperature,
            maximumResponseTokens: config.maximumResponseTokens
        )
    }
}
#endif
