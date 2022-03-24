//
//  CombineHelperTests.swift
//  LucidTests
//
//  Created by Stephane Magne on 3/23/22.
//  Copyright © 2022 Scribd. All rights reserved.
//

@testable import Lucid
@testable import LucidTestKit
import XCTest
import Combine

final class CombineHelperTests: XCTestCase {

    func test_cancellable_box_doesnt_crash_on_race_condition() {

        let cancellable = CancellableBox()

        let publisher = PassthroughSubject<Int, Never>()

        let testCount = 1000

        let expectation = self.expectation(description: "publisher_expectation")
        expectation.expectedFulfillmentCount = testCount

        for i in 0..<testCount {
            let dispatchQueue = DispatchQueue(label: "queue_\(i)")
            dispatchQueue.async {
                publisher
                    .sink(receiveValue: { _ in })
                    .store(in: cancellable)

                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5)
    }

    func test_cancellable_actor_doesnt_crash_on_race_condition() {

        let cancellable = CancellableActor()

        let publisher = PassthroughSubject<Int, Never>()

        let testCount = 1000

        let expectation = self.expectation(description: "publisher_expectation")
        expectation.expectedFulfillmentCount = testCount

        for i in 0..<testCount {
            let dispatchQueue = DispatchQueue(label: "queue_\(i)")
            dispatchQueue.async {
                Task {
                    await publisher
                        .sink(receiveValue: { _ in })
                        .store(in: cancellable)

                    expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 5)
    }
}
