import XCTest
@testable import PlatesKitchen

@MainActor
final class EvalConcurrencyTests: XCTestCase {
    func testCapsActiveTrialsAndKeepsEveryResult() async {
        let probe = ConcurrencyProbe()
        var completed: [Int] = []
        await EvalConcurrency.run(Array(0..<9), limit: 2) { value in
            await probe.begin()
            try? await Task.sleep(for: .milliseconds(value.isMultiple(of: 2) ? 40 : 10))
            await probe.end()
            return value
        } onResult: { value in
            completed.append(value)
        }
        let maximum = await probe.maximum()
        XCTAssertEqual(completed, Array(0..<9))
        XCTAssertEqual(maximum, 2)
    }
}

private actor ConcurrencyProbe {
    private var active = 0
    private var peak = 0

    func begin() {
        active += 1
        peak = max(peak, active)
    }

    func end() { active -= 1 }
    func maximum() -> Int { peak }
}
