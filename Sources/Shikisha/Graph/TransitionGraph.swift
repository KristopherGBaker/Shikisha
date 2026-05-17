import Foundation

/// A lightweight directed graph for transition-tracking use cases (analytics, UI flows).
/// Distinct from `StateGraph` — no execution semantics, just structure + lookup.
public struct TransitionGraph<NodeID: Hashable & Sendable>: Sendable {
    public private(set) var nodes: Set<NodeID>
    public private(set) var transitions: [NodeID: Set<NodeID>]

    public init(nodes: Set<NodeID> = [], transitions: [NodeID: Set<NodeID>] = [:]) {
        self.nodes = nodes
        self.transitions = transitions
    }

    public mutating func add(node: NodeID) {
        nodes.insert(node)
    }

    public mutating func add(from: NodeID, to: NodeID) {
        nodes.insert(from)
        nodes.insert(to)
        transitions[from, default: []].insert(to)
    }

    public func neighbors(of node: NodeID) -> [NodeID] {
        Array(transitions[node] ?? [])
    }

    public func hasPath(from: NodeID, to: NodeID) -> Bool {
        var visited: Set<NodeID> = [from]
        var queue: [NodeID] = [from]
        while let current = queue.first {
            queue.removeFirst()
            if current == to { return true }
            for neighbor in neighbors(of: current) where !visited.contains(neighbor) {
                visited.insert(neighbor)
                queue.append(neighbor)
            }
        }
        return false
    }
}
