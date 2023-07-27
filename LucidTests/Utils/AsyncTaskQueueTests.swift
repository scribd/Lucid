//
//  AsyncTaskQueueTests.swift
//  LucidTests
//
//  Created by Stephane Magne on 2023-05-12.
//  Copyright © 2023 Scribd. All rights reserved.
//

import XCTest
@testable import Lucid

final class AsyncTaskQueueTests: XCTestCase {

    // MARK: Adding to empty queue

    func test_that_it_immediately_runs_a_concurrent_operation_added_to_an_empty_queue() {

        let asyncTaskQueue = AsyncTaskQueue(maxConcurrentTasks: 1)
        let operation = BlockingOperation()

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation.setUp()
                    await operation.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        let setUpExpectation = expectation(description: "set_up_expectation")

        Task { @MainActor in
            await operation.waitForSetUp()

            let hasStarted = await operation.hasStarted
            let runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(hasStarted)
            XCTAssertEqual(runningTasks, 1)

            await operation.resume()
            setUpExpectation.fulfill()
        }

        wait(for: [setUpExpectation], timeout: 1)
    }

    func test_that_it_decrements_the_running_tasks_after_completion() {

        let asyncTaskQueue = AsyncTaskQueue(maxConcurrentTasks: 1)
        let operation = BlockingOperation()

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation.setUp()
                    await operation.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        let setUpExpectation = expectation(description: "set_up_expectation")

        Task { @MainActor in
            await operation.waitForSetUp()

            let hasStarted = await operation.hasStarted
            var runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(hasStarted)
            XCTAssertEqual(runningTasks, 1)

            await operation.resume()
            try? await Task.sleep(nanoseconds: 1000000)

            let hasCompleted = await operation.hasCompleted
            runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(hasCompleted)
            XCTAssertEqual(runningTasks, 0)

            setUpExpectation.fulfill()
        }

        wait(for: [setUpExpectation], timeout: 1)
    }

    // MARK: Adding to populated queue

    func test_that_it_does_not_immediately_runs_a_concurrent_operation_added_to_queue_at_capacity() {

        let asyncTaskQueue = AsyncTaskQueue(maxConcurrentTasks: 1)

        let operation1 = BlockingOperation()
        let operation2 = BlockingOperation()

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation1.setUp()
                    await operation1.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation2.setUp()
                    await operation2.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        let setUpExpectation = expectation(description: "set_up_expectation")

        Task { @MainActor in
            await operation1.waitForSetUp()
            try? await Task.sleep(nanoseconds: 1000)
            let operation1HasStarted = await operation1.hasStarted
            let operation2HasStarted = await operation2.hasStarted
            let runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(operation1HasStarted)
            XCTAssertFalse(operation2HasStarted)
            XCTAssertEqual(runningTasks, 1)

            await operation1.resume()
            await operation2.resume()

            setUpExpectation.fulfill()
        }

        wait(for: [setUpExpectation], timeout: 1)
    }

    func test_that_it_immediately_runs_a_concurrent_operation_added_to_queue_not_at_capacity() {

        let asyncTaskQueue = AsyncTaskQueue(maxConcurrentTasks: 2)

        let operation1 = BlockingOperation()
        let operation2 = BlockingOperation()

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation1.setUp()
                    await operation1.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation2.setUp()
                    await operation2.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        let setUpExpectation = expectation(description: "set_up_expectation")

        Task { @MainActor in
            await operation1.waitForSetUp()
            await operation2.waitForSetUp()

            let operation1HasStarted = await operation1.hasStarted
            let operation2HasStarted = await operation2.hasStarted
            let runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(operation1HasStarted)
            XCTAssertTrue(operation2HasStarted)
            XCTAssertEqual(runningTasks, 2)

            await operation1.resume()
            await operation2.resume()

            setUpExpectation.fulfill()
        }

        wait(for: [setUpExpectation], timeout: 1)
    }

    func test_that_it_immediately_starts_the_next_time_after_an_operation_has_completed() {

        let asyncTaskQueue = AsyncTaskQueue(maxConcurrentTasks: 2)

        let operation1 = BlockingOperation()
        let operation2 = BlockingOperation()
        let operation3 = BlockingOperation()

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation1.setUp()
                    await operation1.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation2.setUp()
                    await operation2.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation3.setUp()
                    await operation3.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        let setUpExpectation = expectation(description: "set_up_expectation")

        Task { @MainActor in
            await operation1.waitForSetUp()
            await operation2.waitForSetUp()
            try? await Task.sleep(nanoseconds: 1000)

            let operation1HasStarted = await operation1.hasStarted
            let operation2HasStarted = await operation2.hasStarted
            var operation3HasStarted = await operation3.hasStarted
            var runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(operation1HasStarted)
            XCTAssertTrue(operation2HasStarted)
            XCTAssertFalse(operation3HasStarted)
            XCTAssertEqual(runningTasks, 2)

            await operation1.resume()
            await operation3.waitForSetUp()

            let operation1HasCompleted = await operation1.hasCompleted
            let operation2HasCompleted = await operation2.hasCompleted
            operation3HasStarted = await operation3.hasStarted
            runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(operation1HasCompleted)
            XCTAssertFalse(operation2HasCompleted)
            XCTAssertTrue(operation3HasStarted)
            XCTAssertEqual(runningTasks, 2)

            setUpExpectation.fulfill()
        }

        wait(for: [setUpExpectation], timeout: 1)
    }

    // MARK: Barrier

    func test_that_it_immediately_runs_a_barrier_operation_when_queue_is_empty() {
        let asyncTaskQueue = AsyncTaskQueue(maxConcurrentTasks: 2)

        let operation = BlockingOperation()

        Task {
            do {
                try await asyncTaskQueue.enqueueBarrier(operation: { completion in
                    defer { completion() }

                    await operation.setUp()
                    await operation.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        let setUpExpectation = expectation(description: "set_up_expectation")

        Task { @MainActor in
            await operation.waitForSetUp()

            let hasStarted = await operation.hasStarted
            let runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(hasStarted)
            XCTAssertEqual(runningTasks, 1)

            await operation.resume()
            setUpExpectation.fulfill()
        }

        wait(for: [setUpExpectation], timeout: 1)
    }

    func test_that_it_waits_until_barrier_finishes_before_starting_next_operation() {
        let asyncTaskQueue = AsyncTaskQueue(maxConcurrentTasks: 1)

        let operation1 = BlockingOperation()
        let operation2 = BlockingOperation()

        Task {
            do {
                try await asyncTaskQueue.enqueueBarrier(operation: { completion in
                    defer { completion() }

                    await operation1.setUp()
                    await operation1.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation2.setUp()
                    await operation2.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        let setUpExpectation = expectation(description: "set_up_expectation")

        Task { @MainActor in
            await operation1.waitForSetUp()
            try? await Task.sleep(nanoseconds: 1000)

            let operation1HasStarted = await operation1.hasStarted
            var operation2HasStarted = await operation2.hasStarted
            var runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(operation1HasStarted)
            XCTAssertFalse(operation2HasStarted)
            XCTAssertEqual(runningTasks, 1)

            await operation1.resume()
            await operation2.waitForSetUp()

            let operation1HasCompleted = await operation1.hasCompleted
            operation2HasStarted = await operation2.hasStarted
            runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(operation1HasCompleted)
            XCTAssertTrue(operation2HasStarted)
            XCTAssertEqual(runningTasks, 1)

            setUpExpectation.fulfill()
        }

        wait(for: [setUpExpectation], timeout: 1)
    }

    func test_that_it_runs_in_parallel_until_it_finds_a_barrier() {
        let asyncTaskQueue = AsyncTaskQueue(maxConcurrentTasks: 2)

        let operation1 = BlockingOperation()
        let operation2 = BlockingOperation()
        let operation3 = BlockingOperation()

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation1.setUp()
                    await operation1.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation2.setUp()
                    await operation2.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        Task {
            do {
                try await asyncTaskQueue.enqueueBarrier(operation: { completion in
                    defer { completion() }

                    await operation3.setUp()
                    await operation3.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        let setUpExpectation = expectation(description: "set_up_expectation")

        Task { @MainActor in
            await operation1.waitForSetUp()
            await operation2.waitForSetUp()
            try? await Task.sleep(nanoseconds: 1000)

            let operation1HasStarted = await operation1.hasStarted
            let operation2HasStarted = await operation2.hasStarted
            var operation3HasStarted = await operation3.hasStarted
            var runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(operation1HasStarted)
            XCTAssertTrue(operation2HasStarted)
            XCTAssertFalse(operation3HasStarted)
            XCTAssertEqual(runningTasks, 2)

            await operation1.resume()
            await operation2.resume()
            await operation3.waitForSetUp()

            let operation1HasCompleted = await operation1.hasCompleted
            let operation2HasCompleted = await operation2.hasCompleted
            operation3HasStarted = await operation3.hasStarted
            runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(operation1HasCompleted)
            XCTAssertTrue(operation2HasCompleted)
            XCTAssertTrue(operation3HasStarted)
            XCTAssertEqual(runningTasks, 1)

            await operation3.resume()

            let operation3HasCompleted = await operation3.hasCompleted
            XCTAssertTrue(operation1HasCompleted)
            XCTAssertTrue(operation2HasCompleted)
            XCTAssertTrue(operation3HasCompleted)

            setUpExpectation.fulfill()
        }

        wait(for: [setUpExpectation], timeout: 1)
    }

    func test_that_it_runs_in_parallel_until_it_finds_a_barrier_then_it_waits_for_barrier_to_end_to_continue() {
        let asyncTaskQueue = AsyncTaskQueue(maxConcurrentTasks: 2)

        let operation1 = BlockingOperation()
        let operation2 = BlockingOperation()
        let operation3 = BlockingOperation()
        let operation4 = BlockingOperation()

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation1.setUp()
                    await operation1.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation2.setUp()
                    await operation2.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        Task {
            do {
                try await asyncTaskQueue.enqueueBarrier(operation: { completion in
                    defer { completion() }

                    await operation3.setUp()
                    await operation3.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        Task {
            do {
                try await asyncTaskQueue.enqueue(operation: {
                    await operation4.setUp()
                    await operation4.perform()
                })
            } catch {
                XCTFail("unexpected error thrown: \(error)")
            }
        }

        let setUpExpectation = expectation(description: "set_up_expectation")

        Task { @MainActor in
            await operation1.waitForSetUp()
            await operation2.waitForSetUp()
            try? await Task.sleep(nanoseconds: 1000)

            let operation1HasStarted = await operation1.hasStarted
            let operation2HasStarted = await operation2.hasStarted
            var operation3HasStarted = await operation3.hasStarted
            var operation4HasStarted = await operation4.hasStarted
            var runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(operation1HasStarted)
            XCTAssertTrue(operation2HasStarted)
            XCTAssertFalse(operation3HasStarted)
            XCTAssertFalse(operation4HasStarted)
            XCTAssertEqual(runningTasks, 2)

            await operation1.resume()
            await operation2.resume()
            await operation3.waitForSetUp()

            let operation1HasCompleted = await operation1.hasCompleted
            let operation2HasCompleted = await operation2.hasCompleted
            operation3HasStarted = await operation3.hasStarted
            operation4HasStarted = await operation4.hasStarted
            runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(operation1HasCompleted)
            XCTAssertTrue(operation2HasCompleted)
            XCTAssertTrue(operation3HasStarted)
            XCTAssertFalse(operation4HasStarted)
            XCTAssertEqual(runningTasks, 1)

            await operation3.resume()
            await operation4.waitForSetUp()

            let operation3HasCompleted = await operation3.hasCompleted
            operation4HasStarted = await operation4.hasStarted
            runningTasks = await asyncTaskQueue.runningTasks

            XCTAssertTrue(operation1HasCompleted)
            XCTAssertTrue(operation2HasCompleted)
            XCTAssertTrue(operation3HasCompleted)
            XCTAssertTrue(operation4HasStarted)
            XCTAssertEqual(runningTasks, 1)

            setUpExpectation.fulfill()
        }

        wait(for: [setUpExpectation], timeout: 1)
    }
}

private final actor BlockingOperation {

    private(set) var hasStarted: Bool = false

    private(set) var hasCompleted: Bool = false

    private var performContinuation: CheckedContinuation<Void, Never>?

    private var setUpObserverContinuation: CheckedContinuation<Void, Never>?

    func setUp() async {
        await withCheckedContinuation { continuation in
            hasStarted = true
            continuation.resume()
            if let setUpObserverContinuation = self.setUpObserverContinuation {
                setUpObserverContinuation.resume()
            }
        }
    }

    func waitForSetUp() async {
        await withCheckedContinuation { continuation in
            if self.hasStarted {
                continuation.resume()
                return
            }
            self.setUpObserverContinuation = continuation
        }
    }

    func perform() async {
        await withCheckedContinuation { continuation in
            self.performContinuation = continuation
        }
    }

    func resume() async {
        guard let performContinuation = performContinuation else { return }
        hasCompleted = true
        performContinuation.resume()
    }
}
