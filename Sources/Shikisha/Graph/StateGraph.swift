import Foundation

/// A LangGraph-style state machine. Nodes are async functions that take and return a `State`;
/// edges define which node runs next. Add static edges with `addEdge`, conditional ones with
/// `addConditionalEdge`. Mark `entryNode` and `finishNodes` and call `run(initial:)` to execute.
public actor StateGraph<State: Sendable> {
    public typealias Node = @Sendable (State) async throws -> State
    public typealias Router = @Sendable (State) async throws -> String

    private var nodes: [String: Node] = [:]
    private var edges: [String: String] = [:]
    private var conditionalEdges: [String: Router] = [:]
    private var entryNode: String?
    private var finishNodes: Set<String> = []

    public init() {}

    public func addNode(_ name: String, _ body: @escaping Node) {
        nodes[name] = body
    }

    public func addEdge(from source: String, to destination: String) {
        edges[source] = destination
    }

    public func addConditionalEdge(from source: String, router: @escaping Router) {
        conditionalEdges[source] = router
    }

    public func setEntry(_ name: String) { entryNode = name }
    public func addFinish(_ name: String) { finishNodes.insert(name) }

    public func run(initial state: State, maxSteps: Int = 100) async throws -> State {
        guard var current = entryNode else {
            throw HTTPError.transport(message: "StateGraph has no entry node")
        }
        var stateValue = state
        for _ in 0..<maxSteps {
            guard let node = nodes[current] else {
                throw HTTPError.transport(message: "StateGraph node not found: \(current)")
            }
            stateValue = try await node(stateValue)
            if finishNodes.contains(current) { return stateValue }
            if let next = edges[current] {
                current = next
                continue
            }
            if let router = conditionalEdges[current] {
                current = try await router(stateValue)
                continue
            }
            return stateValue
        }
        throw HTTPError.transport(message: "StateGraph exceeded maxSteps")
    }
}
