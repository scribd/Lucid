//
//  BackgroundTaskManagerTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 7/16/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

@testable import Lucid_ReactiveKit
import LucidTestKit_ReactiveKit

import XCTest
import ReactiveKit

final class BackgroundTaskManagerTests: XCTestCase {

    private var backgroundTaskManagerSpy: BackgroundTaskManagerSpy!

    override func setUp() {
        super.setUp()
        backgroundTaskManagerSpy = BackgroundTaskManagerSpy()
    }

    override func tearDown() {
        defer { super.tearDown() }
        backgroundTaskManagerSpy = nil
    }

    func test_begin_task_renew_after_it_times_out() {

        let taskID = backgroundTaskManagerSpy.beginBackgroundTask(timeout: 0.05, expirationHandler: {})

        var observationCallCount = 0
        taskID.observeNext { taskID in
            observationCallCount += 1
        }.dispose(in: bag)

        let expectation = self.expectation(description: "new_task_id")
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { timer in
            XCTAssertGreaterThan(observationCallCount, 1)
            XCTAssertEqual(self.backgroundTaskManagerSpy.endBackgroundTaskRecords.count, observationCallCount)
            XCTAssertEqual(self.backgroundTaskManagerSpy.beginBackgroundTaskCallCountRecord, self.backgroundTaskManagerSpy.endBackgroundTaskRecords.count + 1)
            expectation.fulfill()
            timer.invalidate()
        }

        waitForExpectations(timeout: 1)
    }
}
