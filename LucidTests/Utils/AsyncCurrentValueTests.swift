//
//  AsyncCurrentValueTests.swift
//  LucidTests
//
//  Created by Stephane Magne on 2023-05-16.
//  Copyright © 2023 Scribd. All rights reserved.
//

import XCTest
@testable import Lucid

final class AsyncCurrentValueTests: XCTestCase {

    private var continuousCount: Int!

    override func setUp() async throws {
        try await super.setUp()
        continuousCount = 0
    }

    override func tearDown() async throws {
        continuousCount = nil
        try await super.tearDown()
    }

    // MARK: Adding to empty queue

    func test_that_observer_gets_initial_value() async {

        let currentValue = AsyncCurrentValue(5)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask(priority: .high) {
                    let iterator = currentValue.makeAsyncIterator()
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

    func test_that_observer_gets_initial_value_and_following_values() async {

        let currentValue = AsyncCurrentValue(5)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask(priority: .high) {
                    let iterator = currentValue.makeAsyncIterator()
                    for try await value in iterator {
                        if self.continuousCount == 0 {
                            XCTAssertEqual(value, 5)
                        } else if self.continuousCount == 1 {
                            XCTAssertEqual(value, 10)
                        } else if self.continuousCount == 2 {
                            XCTAssertEqual(value, 12)
                            return
                        }
                        self.continuousCount += 1
                    }
                }

                group.addTask(priority: .low) {
                    try? await Task.sleep(nanoseconds: 100000)
                    await currentValue.update(with: 10)
                    await currentValue.update(with: 12)
                }

                try await group.waitForAll()
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_that_new_observer_gets_the_most_recent_value() async {

        let currentValue = AsyncCurrentValue(5)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask(priority: .high) {
                    await currentValue.update(with: 10)
                }

                group.addTask(priority: .low) {
                    let iterator = currentValue.makeAsyncIterator()
                    for try await value in iterator {
                        XCTAssertEqual(value, 10)
                        return
                    }
                }

                try await group.waitForAll()
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_that_new_observer_gets_the_most_recent_value_and_following_values() async {

        let currentValue = AsyncCurrentValue(5)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask(priority: .high) {
                    await currentValue.update(with: 10)
                }

                group.addTask(priority: .high) {
                    let iterator = currentValue.makeAsyncIterator()
                    for try await value in iterator {
                        if self.continuousCount == 0 {
                            XCTAssertEqual(value, 10)
                        } else if self.continuousCount == 1 {
                            XCTAssertEqual(value, 20)
                        } else if self.continuousCount == 2 {
                            XCTAssertEqual(value, 115)
                            return
                        }
                        self.continuousCount += 1
                    }
                }

                group.addTask(priority: .low) {
                    try? await Task.sleep(nanoseconds: 100000)
                    await currentValue.update(with: 20)
                    await currentValue.update(with: 115)
                }

                try await group.waitForAll()
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_that_all_observers_receive_values() async {

        let currentValue = AsyncCurrentValue(5)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in

                group.addTask(priority: .high) {
                    var count = 0
                    let iterator = currentValue.makeAsyncIterator()
                    for try await value in iterator {
                        if count == 0 {
                            XCTAssertEqual(value, 5)
                        } else if count == 1 {
                            XCTAssertEqual(value, 22)
                            return
                        }
                        count += 1
                    }
                }

                group.addTask(priority: .high) {
                    var count = 0
                    let iterator = currentValue.makeAsyncIterator()
                    for try await value in iterator {
                        if count == 0 {
                            XCTAssertEqual(value, 5)
                        } else if count == 1 {
                            XCTAssertEqual(value, 22)
                            return
                        }
                        count += 1
                    }
                }

                group.addTask(priority: .high) {
                    var count = 0
                    let iterator = currentValue.makeAsyncIterator()
                    for try await value in iterator {
                        if count == 0 {
                            XCTAssertEqual(value, 5)
                        } else if count == 1 {
                            XCTAssertEqual(value, 22)
                            return
                        }
                        count += 1
                    }
                }

                group.addTask(priority: .low) {
                    try? await Task.sleep(nanoseconds: 100000)
                    await currentValue.update(with: 22)
                }

                try await group.waitForAll()
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_that_did_remove_final_iterator_is_called() async {

        let valueObserver = ValueObserver()
        let currentValue = AsyncCurrentValue(5)
        await currentValue.setDelegate(valueObserver)

        let iterator1 = currentValue.makeAsyncIterator()
        let iterator2 = currentValue.makeAsyncIterator()
        let iterator3 = currentValue.makeAsyncIterator()

        try? await Task.sleep(nanoseconds: 1000000)

        await currentValue.cancelIterator(iterator1)
        await currentValue.cancelIterator(iterator2)

        let didComplete1 = await valueObserver.didComplete
        XCTAssertFalse(didComplete1)

        await currentValue.cancelIterator(iterator3)

        let didComplete2 = await valueObserver.didComplete
        XCTAssertTrue(didComplete2)
    }
}

private final actor ValueObserver: AsyncCurrentValueDelegate {

    private(set) var didComplete = false

    func didRemoveFinalIterator() async {
        didComplete = true
    }
}
