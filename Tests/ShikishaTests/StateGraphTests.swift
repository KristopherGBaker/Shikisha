import Foundation
import Testing
@testable import Shikisha

@Suite("StateGraph")
struct StateGraphTests {
    @Test func testLinearGraphRuns() async throws {
        let graph = StateGraph<Int>()
        await graph.addNode("plus2") { state in state + 2 }
        await graph.addNode("times3") { state in state * 3 }
        await graph.addEdge(from: "plus2", to: "times3")
        await graph.addFinish("times3")
        await graph.setEntry("plus2")
        let result = try await graph.run(initial: 4)
        #expect(result == 18)
    }

    @Test func testConditionalEdgeBranching() async throws {
        let graph = StateGraph<Int>()
        await graph.addNode("entry") { $0 }
        await graph.addNode("evenPath") { $0 / 2 }
        await graph.addNode("oddPath") { $0 * 3 + 1 }
        await graph.addConditionalEdge(from: "entry") { state in
            state.isMultiple(of: 2) ? "evenPath" : "oddPath"
        }
        await graph.addFinish("evenPath")
        await graph.addFinish("oddPath")
        await graph.setEntry("entry")
        let evenResult = try await graph.run(initial: 10)
        let oddResult = try await graph.run(initial: 5)
        #expect(evenResult == 5)
        #expect(oddResult == 16)
    }
}
