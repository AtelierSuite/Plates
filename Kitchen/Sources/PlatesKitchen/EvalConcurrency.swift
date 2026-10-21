import Foundation

/// Runs a bounded number of independent trials while keeping result writes on the main actor.
@MainActor
enum EvalConcurrency {
    static func run<Job: Sendable, Result: Sendable>(
        _ jobs: [Job], limit: Int,
        operation: @escaping @MainActor @Sendable (Job) async -> Result,
        onResult: @escaping @MainActor (Result) -> Void
    ) async {
        let width = max(1, min(limit, 4))
        for batchStart in stride(from: 0, to: jobs.count, by: width) {
            if Task.isCancelled { break }
            let batch = Array(jobs[batchStart..<min(batchStart + width, jobs.count)])
            await withTaskGroup(of: (Int, Result).self) { group in
                for (index, job) in batch.enumerated() {
                    group.addTask { (index, await operation(job)) }
                }
                var ready: [Int: Result] = [:]
                var next = 0
                for await (index, result) in group {
                    ready[index] = result
                    while let ordered = ready.removeValue(forKey: next) {
                        onResult(ordered)
                        next += 1
                    }
                }
            }
        }
    }
}
