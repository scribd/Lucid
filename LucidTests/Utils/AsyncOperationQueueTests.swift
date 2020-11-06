//
//  AsyncOperationQueueTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 9/3/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

@testable import Lucid

import XCTest

final class AsyncOperationQueueTests: XCTestCase {

    private var dispatchQueue: DispatchQueue!

    private var operationQueue: AsyncOperationQueue!

    override func setUp() {
        super.setUp()
        dispatchQueue = DispatchQueue(label: "test_queue")
        operationQueue = AsyncOperationQueue(dispatchQueue: dispatchQueue)
    }

    override func tearDown() {
        defer { super.tearDown() }
        dispatchQueue = nil
        operationQueue = nil
    }

    // MARK: Adding to empty queue

    func test_that_it_immediately_runs_a_concurrent_operation_added_to_an_empty_queue() {

        var operationDidRun = false

        let operation = AsyncOperation(title: "concurrent", barrier: false) { completion in
            operationDidRun = true
        }
        operationQueue.run(operation: operation)

        dispatchQueue.sync { }

        XCTAssertTrue(operationDidRun)
    }

    func test_that_it_immediately_runs_a_barrier_operation_added_to_an_empty_queue() {

        var operationDidRun = false

        let operation = AsyncOperation(title: "barrier", barrier: true) { completion in
            operationDidRun = true
        }
        operationQueue.run(operation: operation)

        dispatchQueue.sync { }

        XCTAssertTrue(operationDidRun)
    }

    // MARK: Adding to populated queue

    func test_that_it_immediately_runs_a_concurrent_operation_added_to_queue_with_a_running_concurrent_operation() {

        var firstOperationDidRun = false
        var secondOperationDidRun = false

        let operation1 = AsyncOperation(title: "concurren1", barrier: false) { completion in
            firstOperationDidRun = true
        }
        operationQueue.run(operation: operation1)

        let operation2 = AsyncOperation(title: "concurrent2", barrier: false) { completion in
            secondOperationDidRun = true
        }
        operationQueue.run(operation: operation2)

        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertTrue(secondOperationDidRun)
    }

    func test_that_it_immediately_runs_a_concurrent_operation_added_queue_with_an_existing_concurrent_operation_and_does_not_run_subsequently_added_barrier_operation() {

        var firstOperationDidRun = false
        var secondOperationDidRun = false
        var thirdOperationDidRun = false
        
        let operation1 = AsyncOperation(title: "concurren1", barrier: false) { completion in
            firstOperationDidRun = true
        }
        operationQueue.run(operation: operation1)

        let operation2 = AsyncOperation(title: "concurrent2", barrier: false) { completion in
            secondOperationDidRun = true
        }
        operationQueue.run(operation: operation2)

        let operation3 = AsyncOperation(title: "barrier", barrier: true) { completion in
            thirdOperationDidRun = true
        }
        operationQueue.run(operation: operation3)

        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertTrue(secondOperationDidRun)
        XCTAssertFalse(thirdOperationDidRun)
    }

    func test_that_it_immediately_runs_multiple_concurrent_operations_added_to_queue_with_an_existing_concurrent_operation() {

        var firstOperationDidRun = false
        var secondOperationDidRun = false
        var thirdOperationDidRun = false
        var fourthOperationDidRun = false

        let operation1 = AsyncOperation(title: "concurren1", barrier: false) { completion in
            firstOperationDidRun = true
        }
        operationQueue.run(operation: operation1)

        let operation2 = AsyncOperation(title: "concurrent2", barrier: false) { completion in
            secondOperationDidRun = true
        }
        operationQueue.run(operation: operation2)

        let operation3 = AsyncOperation(title: "concurrent3", barrier: false) { completion in
            thirdOperationDidRun = true
        }
        operationQueue.run(operation: operation3)

        let operation4 = AsyncOperation(title: "concurrent4", barrier: false) { completion in
            fourthOperationDidRun = true
        }
        operationQueue.run(operation: operation4)

        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertTrue(secondOperationDidRun)
        XCTAssertTrue(thirdOperationDidRun)
        XCTAssertTrue(fourthOperationDidRun)
    }

    func test_that_it_does_not_immediately_run_a_concurrent_operation_added_to_queue_with_a_running_barrier_operation() {

        var firstOperationDidRun = false
        var secondOperationDidRun = false

        let operation1 = AsyncOperation(title: "barrier", barrier: true) { completion in
            firstOperationDidRun = true
        }
        operationQueue.run(operation: operation1)

        let operation2 = AsyncOperation(title: "concurrent", barrier: false) { completion in
            secondOperationDidRun = true
        }
        operationQueue.run(operation: operation2)

        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertFalse(secondOperationDidRun)
    }

    func test_that_it_does_not_immediately_run_a_concurrent_operation_added_to_queue_with_a_barrier_operation_anywhere_in_the_queue() {

        var firstOperationDidRun = false
        var secondOperationDidRun = false
        var thirdOperationDidRun = false

        let operation1 = AsyncOperation(title: "concurrent1", barrier: false) { completion in
            firstOperationDidRun = true
        }
        operationQueue.run(operation: operation1)

        let operation2 = AsyncOperation(title: "barrier", barrier: true) { completion in
            secondOperationDidRun = true
        }
        operationQueue.run(operation: operation2)

        let operation3 = AsyncOperation(title: "concurrent2", barrier: false) { completion in
            thirdOperationDidRun = true
        }
        operationQueue.run(operation: operation3)

        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertFalse(secondOperationDidRun)
        XCTAssertFalse(thirdOperationDidRun)
    }

    func test_that_it_does_not_immediately_run_a_barrier_operation_added_to_queue_with_a_running_concurrent_operation() {

        var firstOperationDidRun = false
        var secondOperationDidRun = false

        let operation1 = AsyncOperation(title: "concurrent", barrier: false) { completion in
            firstOperationDidRun = true
        }
        operationQueue.run(operation: operation1)

        let operation2 = AsyncOperation(title: "barrier", barrier: true) { completion in
            secondOperationDidRun = true
        }
        operationQueue.run(operation: operation2)

        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertFalse(secondOperationDidRun)
    }

    func test_that_it_does_not_immediately_run_a_barrier_operation_added_to_queue_with_a_running_barrier_operation() {

        var firstOperationDidRun = false
        var secondOperationDidRun = false

        let operation1 = AsyncOperation(title: "barrier1", barrier: true) { completion in
            firstOperationDidRun = true
        }
        operationQueue.run(operation: operation1)

        let operation2 = AsyncOperation(title: "barrier2", barrier: true) { completion in
            secondOperationDidRun = true
        }
        operationQueue.run(operation: operation2)

        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertFalse(secondOperationDidRun)
    }

    // MARK: Queue continuing on completion

    func test_that_it_only_runs_the_subsequent_barrier_operation_when_completing_a_barrier_operation() {

        let waitQueue = DispatchQueue(label: "wait_queue")

        var firstOperationDidRun = false
        var secondOperationDidRun = false
        var thirdOperationDidRun = false

        let firstOperationCompletedExpectation = self.expectation(description: "operation_completed_1")

        let operation1 = AsyncOperation(title: "barrier1", barrier: true) { completion in
            firstOperationDidRun = true
            waitQueue.async {
                self.wait(for: [firstOperationCompletedExpectation], timeout: 1)
                completion()
            }
        }
        operationQueue.run(operation: operation1)

        let operation2 = AsyncOperation(title: "barrier2", barrier: true) { completion in
            secondOperationDidRun = true
        }
        operationQueue.run(operation: operation2)

        let operation3 = AsyncOperation(title: "concurrent", barrier: false) { completion in
            thirdOperationDidRun = true
        }
        operationQueue.run(operation: operation3)

        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertFalse(secondOperationDidRun)
        XCTAssertFalse(thirdOperationDidRun)

        firstOperationCompletedExpectation.fulfill()

        waitQueue.sync { }
        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertTrue(secondOperationDidRun)
        XCTAssertFalse(thirdOperationDidRun)
    }

    func test_that_it_only_runs_the_subsequent_N_concurrent_operations_when_completing_a_barrier_operation() {

        let waitQueue = DispatchQueue(label: "wait_queue")

        var firstOperationDidRun = false
        var secondOperationDidRun = false
        var thirdOperationDidRun = false
        var fourthOperationDidRun = false
        var fifthOperationDidRun = false
        var sixthOperationDidRun = false

        let firstOperationCompletedExpectation = self.expectation(description: "operation_completed_1")

        let operation1 = AsyncOperation(title: "barrier1", barrier: true) { completion in
            firstOperationDidRun = true
            waitQueue.async {
                self.wait(for: [firstOperationCompletedExpectation], timeout: 1)
                completion()
            }
        }
        operationQueue.run(operation: operation1)

        let operation2 = AsyncOperation(title: "concurrent1", barrier: false) { completion in
            secondOperationDidRun = true
        }
        operationQueue.run(operation: operation2)

        let operation3 = AsyncOperation(title: "concurrent2", barrier: false) { completion in
            thirdOperationDidRun = true
        }
        operationQueue.run(operation: operation3)

        let operation4 = AsyncOperation(title: "concurrent3", barrier: false) { completion in
            fourthOperationDidRun = true
        }
        operationQueue.run(operation: operation4)

        let operation5 = AsyncOperation(title: "concurrent4", barrier: false) { completion in
            fifthOperationDidRun = true
        }
        operationQueue.run(operation: operation5)

        let operation6 = AsyncOperation(title: "barrier2", barrier: true) { completion in
            sixthOperationDidRun = true
        }
        operationQueue.run(operation: operation6)

        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertFalse(secondOperationDidRun)
        XCTAssertFalse(thirdOperationDidRun)
        XCTAssertFalse(fourthOperationDidRun)
        XCTAssertFalse(fifthOperationDidRun)
        XCTAssertFalse(sixthOperationDidRun)

        firstOperationCompletedExpectation.fulfill()

        waitQueue.sync { }
        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertTrue(secondOperationDidRun)
        XCTAssertTrue(thirdOperationDidRun)
        XCTAssertTrue(fourthOperationDidRun)
        XCTAssertTrue(fifthOperationDidRun)
        XCTAssertFalse(sixthOperationDidRun)
    }

    func test_that_it_doesnt_run_the_subsequent_barrier_operation_if_only_a_partial_set_of_running_concurrent_operations_are_completed() {

        let waitQueue = DispatchQueue(label: "wait_queue")

        var firstOperationDidRun = false
        var secondOperationDidRun = false
        var thirdOperationDidRun = false
        var fourthOperationDidRun = false

        let firstOperationCompletedExpectation = self.expectation(description: "operation_completed_1")
        let secondOperationCompletedExpectation = self.expectation(description: "operation_completed_2")

        let operation1 = AsyncOperation(title: "concurrent1", barrier: false) { completion in
            firstOperationDidRun = true
            waitQueue.async {
                self.wait(for: [firstOperationCompletedExpectation], timeout: 1)
                completion()
            }
        }
        operationQueue.run(operation: operation1)

        let operation2 = AsyncOperation(title: "concurrent2", barrier: false) { completion in
            secondOperationDidRun = true
            waitQueue.async {
                self.wait(for: [secondOperationCompletedExpectation], timeout: 1)
                completion()
            }
        }
        operationQueue.run(operation: operation2)

        let operation3 = AsyncOperation(title: "concurrent3", barrier: false) { completion in
            thirdOperationDidRun = true
        }
        operationQueue.run(operation: operation3)

        let operation4 = AsyncOperation(title: "barrier", barrier: true) { completion in
            fourthOperationDidRun = true
        }
        operationQueue.run(operation: operation4)

        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertTrue(secondOperationDidRun)
        XCTAssertTrue(thirdOperationDidRun)
        XCTAssertFalse(fourthOperationDidRun)

        firstOperationCompletedExpectation.fulfill()
        secondOperationCompletedExpectation.fulfill()

        waitQueue.sync { }
        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertTrue(secondOperationDidRun)
        XCTAssertTrue(thirdOperationDidRun)
        XCTAssertFalse(fourthOperationDidRun)
    }

    func test_that_it_runs_the_subsequent_barrier_operation_once_all_running_concurrent_operations_are_completed() {

        let waitQueue = DispatchQueue(label: "wait_queue")

        var firstOperationDidRun = false
        var secondOperationDidRun = false
        var thirdOperationDidRun = false
        var fourthOperationDidRun = false

        let firstOperationCompletedExpectation = self.expectation(description: "operation_completed_1")
        let secondOperationCompletedExpectation = self.expectation(description: "operation_completed_2")
        let thirdOperationCompletedExpectation = self.expectation(description: "operation_completed_3")

        let operation1 = AsyncOperation(title: "concurrent1", barrier: false) { completion in
            firstOperationDidRun = true
            waitQueue.async {
                self.wait(for: [firstOperationCompletedExpectation], timeout: 1)
                completion()
            }
        }
        operationQueue.run(operation: operation1)

        let operation2 = AsyncOperation(title: "concurrent2", barrier: false) { completion in
            secondOperationDidRun = true
            waitQueue.async {
                self.wait(for: [secondOperationCompletedExpectation], timeout: 1)
                completion()
            }
        }
        operationQueue.run(operation: operation2)

        let operation3 = AsyncOperation(title: "concurrent3", barrier: false) { completion in
            thirdOperationDidRun = true
            waitQueue.async {
                self.wait(for: [thirdOperationCompletedExpectation], timeout: 1)
                completion()
            }
        }
        operationQueue.run(operation: operation3)

        let operation4 = AsyncOperation(title: "barrier", barrier: true) { completion in
            fourthOperationDidRun = true
        }
        operationQueue.run(operation: operation4)

        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertTrue(secondOperationDidRun)
        XCTAssertTrue(thirdOperationDidRun)
        XCTAssertFalse(fourthOperationDidRun)

        firstOperationCompletedExpectation.fulfill()
        secondOperationCompletedExpectation.fulfill()
        thirdOperationCompletedExpectation.fulfill()

        waitQueue.sync { }
        dispatchQueue.sync { }

        XCTAssertTrue(firstOperationDidRun)
        XCTAssertTrue(secondOperationDidRun)
        XCTAssertTrue(thirdOperationDidRun)
        XCTAssertTrue(fourthOperationDidRun)
    }
}
