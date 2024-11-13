//
//  BackgroundTaskManagerTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 7/16/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

@testable import Lucid
import LucidTestKit

import XCTest

final class BackgroundTaskManagerTests: XCTestCase {

    private var coreManagerSpy: CoreBackgroundTaskManagerSpy!

    private var manager: BackgroundTaskManager!

    override func setUp() {
        super.setUp()
        coreManagerSpy = CoreBackgroundTaskManagerSpy()
        manager = BackgroundTaskManager(coreManagerSpy, timeout: 0.3)
    }

    override func tearDown() {
        defer { super.tearDown() }
        coreManagerSpy = nil
        manager = nil
    }

    func test_start_should_begin_background_task() {
        let expectation = self.expectation(description: "start")
        _ = manager.start {}

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.coreManagerSpy.beginBackgroundTaskCallCountRecord, 1)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func test_start_several_times_should_begin_one_background_task() {
        let expectation = self.expectation(description: "start")
        _ = manager.start {}
        _ = manager.start {}
        _ = manager.start {}

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.coreManagerSpy.beginBackgroundTaskCallCountRecord, 1)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func test_start_should_keep_a_background_task_leaving_until_stop_is_called() {
        let expectation = self.expectation(description: "start")
        _ = manager.start {}

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertEqual(self.coreManagerSpy.beginBackgroundTaskCallCountRecord, 2)
            XCTAssertEqual(self.coreManagerSpy.endBackgroundTaskRecords.count, 1)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func test_stop_should_only_end_background_task_once_it_expires() {
        let expectation = self.expectation(description: "start")
        let id = manager.start {}
        _ = manager.stop(id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.coreManagerSpy.beginBackgroundTaskCallCountRecord, 1)
            XCTAssertEqual(self.coreManagerSpy.endBackgroundTaskRecords.count, 0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func test_stop_should_end_background_task_once_it_expires() {
        let expectation = self.expectation(description: "start")
        let id = manager.start {}
        _ = manager.stop(id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.coreManagerSpy.beginBackgroundTaskCallCountRecord, 1)
            XCTAssertEqual(self.coreManagerSpy.endBackgroundTaskRecords.count, 1)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)
    }
}
