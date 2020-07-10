//
//  AsyncOperationQueueTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 9/3/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

@testable import Lucid_ReactiveKit

import XCTest

final class AsyncOperationQueueTests: XCTestCase {

    func test_operation_queue_should_add_several_operation_and_execute_them_serially() {
        let queue = AsyncOperationQueue()

        var operationCounter = 0
        let expectation = self.expectation(description: "operations")
        expectation.expectedFulfillmentCount = 10

        for i in 0..<expectation.expectedFulfillmentCount {
            queue.run(title: "\(i)") { completion in
                XCTAssertEqual(operationCounter, i)
                operationCounter += 1
                completion()
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1)
    }

    func test_operation_queue_should_add_nested_operation_and_execute_them_serially() {
        let queue = AsyncOperationQueue()
        let expectation = self.expectation(description: "operations")

        queue.run(title: "parent") { completion in
            queue.run(title: "child") { completion in
                completion()
                expectation.fulfill()
            }
            completion()
        }

        waitForExpectations(timeout: 1)
    }

    func test_operation_queue_should_block_queue_until_barrier_is_executed() {
        let queue = AsyncOperationQueue()

        let beforeBarrierExpectation = self.expectation(description: "before")
        let barrierExpectation = self.expectation(description: "barrier")
        let afterBarrierExpectation = self.expectation(description: "after")

        queue.run(operation: AsyncOperation(title: "before", barrier: false) { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                beforeBarrierExpectation.fulfill()
                completion()
            }
        })

        queue.run(operation: AsyncOperation(title: "barrier", barrier: true) { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                barrierExpectation.fulfill()
                completion()
            }
        })

        queue.run(operation: AsyncOperation(title: "after", barrier: false) { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                afterBarrierExpectation.fulfill()
                completion()
            }
        })

        wait(for: [beforeBarrierExpectation, barrierExpectation, afterBarrierExpectation],
             timeout: 1,
             enforceOrder: true)
    }

    func test_operation_queue_should_cancel_an_operation_after_a_given_delay() {
        let queue = AsyncOperationQueue()
        let longExpectation = self.expectation(description: "long")
        let timeoutExpectation = self.expectation(description: "timout")

        queue.run(operation: AsyncOperation(title: "long", barrier: true, timeout: 0.1) { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                longExpectation.fulfill()
                completion()
            }
        })

        queue.run(operation: AsyncOperation(title: "timeout", barrier: true) { completion in
            timeoutExpectation.fulfill()
            completion()
        })

        wait(for: [timeoutExpectation, longExpectation], timeout: 1, enforceOrder: true)
    }

    func test_operation_queue_should_not_cancel_an_operation_after_it_already_completed() {
        let queue = AsyncOperationQueue()
        let shortExpectation = self.expectation(description: "short")
        let timeoutExpectation = self.expectation(description: "timout")

        queue.run(operation: AsyncOperation(title: "short", barrier: true, timeout: 0.3) { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                shortExpectation.fulfill()
                completion()
            }
        })

        queue.run(operation: AsyncOperation(title: "timeout", barrier: true) { completion in
            timeoutExpectation.fulfill()
            completion()
        })

        wait(for: [shortExpectation, timeoutExpectation], timeout: 1, enforceOrder: true)
    }
}
