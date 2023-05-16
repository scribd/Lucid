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
                group.addTask {
                    for try await value in currentValue {
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
                group.addTask {
                    for try await value in currentValue {
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

                group.addTask {
                    currentValue.update(with: 10)
                    currentValue.update(with: 12)
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
                group.addTask {
                    currentValue.update(with: 10)
                }

                group.addTask {
                    for try await value in currentValue {
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
                group.addTask {
                    currentValue.update(with: 10)
                }

                group.addTask {
                    for try await value in currentValue {
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

                group.addTask {
                    currentValue.update(with: 20)
                    currentValue.update(with: 115)
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

                group.addTask {
                    var count = 0
                    for try await value in currentValue {
                        if count == 0 {
                            XCTAssertEqual(value, 5)
                        } else if count == 1 {
                            XCTAssertEqual(value, 22)
                            return
                        }
                        count += 1
                    }
                }

                group.addTask {
                    var count = 0
                    for try await value in currentValue {
                        if count == 0 {
                            XCTAssertEqual(value, 5)
                        } else if count == 1 {
                            XCTAssertEqual(value, 22)
                            return
                        }
                        count += 1
                    }
                }

                group.addTask {
                    var count = 0
                    for try await value in currentValue {
                        if count == 0 {
                            XCTAssertEqual(value, 5)
                        } else if count == 1 {
                            XCTAssertEqual(value, 22)
                            return
                        }
                        count += 1
                    }
                }

                group.addTask {
                    currentValue.update(with: 22)
                }

                try await group.waitForAll()
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
