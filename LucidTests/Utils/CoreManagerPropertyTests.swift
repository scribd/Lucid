//
//  CoreManagerPropertyTests.swift
//  LucidTests
//
//  Created by Stephane Magne on 2023-05-16.
//  Copyright © 2023 Scribd. All rights reserved.
//

import XCTest
@testable import Lucid

final class CoreManagerPropertyTests: XCTestCase {

    // MARK: Adding to empty queue

    func test_that_observer_gets_initial_value() async {

        let property = await CoreManagerProperty<Int>()

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask(priority: .high) {
                    await property.update(with: 5)
                }

                group.addTask(priority: .low) {
                    let iterator = await property.stream.makeAsyncIterator()
                    for try await value in iterator {
                        XCTAssertEqual(value, 5)
                        return
                    }
                }

                try await group.waitForAll()
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_that_observer_gets_update() async {

        let property = await CoreManagerProperty<Int>()

        do {
            Task(priority: .low) {
                try? await Task.sleep(nanoseconds: NSEC_PER_MSEC)
                await property.update(with: 5)
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    var count = 0
                    let iterator = await property.stream.makeAsyncIterator()
                    for try await value in iterator {
                        if count == 0 {
                            XCTAssertEqual(value, nil)
                        } else if count == 1 {
                            XCTAssertEqual(value, 5)
                            return
                        }
                        count += 1
                    }
                }

                group.addTask {
                    // Timeout
                    try? await Task.sleep(nanoseconds: NSEC_PER_SEC * 5)
                    if Task.isCancelled { return }
                    XCTFail("Timed out")
                }

                try await group.next()
                group.cancelAll()
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_that_observer_does_not_get_update_for_duplicate_values() async {

        let property = await CoreManagerProperty<Int>()

        do {
            Task(priority: .low) {
                try? await Task.sleep(nanoseconds: NSEC_PER_MSEC)
                await property.update(with: 5)
                await property.update(with: 5)
                await property.update(with: 17)
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    var count = 0
                    let iterator = await property.stream.makeAsyncIterator()
                    for try await value in iterator {
                        defer { count += 1 }
                        if count == 0 {
                            XCTAssertEqual(value, nil)
                        } else if count == 1 {
                            XCTAssertEqual(value, 5)
                        } else if count == 2 {
                            XCTAssertEqual(value, 17)
                            return
                        }
                    }
                }

                group.addTask {
                    // Timeout
                    try? await Task.sleep(nanoseconds: NSEC_PER_SEC * 2)
                    if Task.isCancelled { return }
                    XCTFail("Timed out")
                }

                try await group.next()
                group.cancelAll()
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_that_delegate_gets_called_when_observers_are_released() async {

        let property = await CoreManagerProperty<Int>()
        let delegateExpectation = self.expectation(description: "delegate_called_expectation")
        let asyncTasks = AsyncTasks()


        Task(priority: .high) {
            await property.setDidRemoveLastObserver {
                delegateExpectation.fulfill()
            }
        }

        Task(priority: .high) {
            var count = 0
            let iterator = await property.stream.makeAsyncIterator()
            for try await value in iterator {
                if count == 0 {
                    XCTAssertEqual(value, nil)
                } else if count == 1 {
                    XCTAssertEqual(value, 5)
                } else if count == 2 {
                    XCTAssertEqual(value, 17)
                    return
                }
                count += 1
            }
        }.store(in: asyncTasks)

        Task(priority: .high) {
            var count = 0
            let iterator = await property.stream.makeAsyncIterator()
            for try await value in iterator {
                if count == 0 {
                    XCTAssertEqual(value, nil)
                } else if count == 1 {
                    XCTAssertEqual(value, 5)
                } else if count == 2 {
                    XCTAssertEqual(value, 17)
                    return
                }
                count += 1
            }
        }.store(in: asyncTasks)

        Task(priority: .background) {
            try? await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
            await property.update(with: 5)
            try? await Task.sleep(nanoseconds: NSEC_PER_MSEC)
            await property.update(with: 17)
            try? await Task.sleep(nanoseconds: NSEC_PER_MSEC)
            await property.update(with: 20)
        }

        await fulfillment(of: [delegateExpectation], timeout: 1)
    }
}
