import Foundation
import Shikisha

/// Some workflows aren't a straight line — they loop, branch, or revisit steps (retry until
/// valid, plan → act → reflect, and so on). ``StateGraph`` models these as named nodes that
/// transform a shared `State`, with edges (including *conditional* edges) deciding what runs
/// next. This example loops a counter until it reaches a threshold.
enum StateGraphFlowExample {
    struct Counter: Sendable {
        var value: Int
        var log: [String] = []
    }

    static func run() async throws {
        let graph = StateGraph<Counter>()

        // A node is `(State) async throws -> State`.
        await graph.addNode("increment") { state in
            var next = state
            next.value += 1
            next.log.append("incremented to \(next.value)")
            return next
        }

        await graph.addNode("done") { state in
            var next = state
            next.log.append("finished at \(next.value)")
            return next
        }

        // A conditional edge is a router `(State) -> String` that names the next node — here it
        // loops back to "increment" until the counter hits 3, then proceeds to "done".
        await graph.addConditionalEdge(from: "increment") { state in
            state.value < 3 ? "increment" : "done"
        }

        await graph.setEntry("increment")
        await graph.addFinish("done")

        let result = try await graph.run(initial: Counter(value: 0))

        section("Execution log")
        for line in result.log {
            print("• \(line)")
        }
        print("\nfinal value: \(result.value)")
    }
}
