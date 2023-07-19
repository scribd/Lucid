//
//  InMemoryStoreTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 12/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Lucid
@testable import LucidTestKit

final class InMemoryStoreTests: StoreTests {

    private var notificationCenter: NotificationCenter!

    override func setUp() {
        super.setUp()
        notificationCenter = NotificationCenter()
        entityStore = InMemoryStore<EntitySpy>(notificationCenter: notificationCenter).storing
        entityRelationshipStore = InMemoryStore<EntityRelationshipSpy>().storing
    }

    override func tearDown() {
        notificationCenter = nil
        super.tearDown()
    }

    override class var defaultTestSuite: XCTestSuite {
        return XCTestSuite(forTestCaseClass: InMemoryStoreTests.self)
    }

    func test_store_should_respond_to_platform_specific_notification_for_memory_pressure() {
        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let setExpectation = self.expectation(description: "set_entity")

        let entities: [EntitySpy] = [
            EntitySpy(idValue: .remote(0, nil), title: "book_one"),
            EntitySpy(idValue: .remote(1, nil), title: "book_two"),
            EntitySpy(idValue: .remote(2, nil), title: "book_three"),
            EntitySpy(idValue: .remote(3, nil), title: "book_four")
        ]

        entityStore.set(entities, in: WriteContext(dataTarget: .local)) { result in
            guard let result = result else {
                XCTFail("Unexpectedly received nil.")
                return
            }

            if let error = result.error {
                XCTFail("Unexpected error: \(error).")
            }

            setExpectation.fulfill()
        }

        wait(for: [setExpectation], timeout: 1)

        let notificationName = InMemoryStore<EntitySpy>.Constants.memoryPressureNotification
        var expectedResultCountForPlatform: Int = -1
        #if os(iOS) || os(tvOS)
        expectedResultCountForPlatform = 0
        #elseif os(macOS) || os(Linux)
        expectedResultCountForPlatform = entities.count
        #elseif os(watchOS)
        if #available(watchOS 7.0, *) {
            expectedResultCountForPlatform = 0
        } else {
            expectedResultCountForPlatform = entities.count
        }
        #else
        XCTFail("Testing on unexpected platform.")
        #endif

        if let notificationName = notificationName {
            notificationCenter.post(name: notificationName, object: nil)
        }

        let getExpectation = self.expectation(description: "get_entity")

        entityStore.search(withQuery: .all, in: context) { result in
            switch result {
            case .success(let queryResult):
                XCTAssertEqual(queryResult.count, expectedResultCountForPlatform)
            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }
            getExpectation.fulfill()
        }

        wait(for: [getExpectation], timeout: 1)
    }

    func test_store_should_respond_to_platform_specific_notification_for_memory_pressure_async() async {
        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let entities: [EntitySpy] = [
            EntitySpy(idValue: .remote(0, nil), title: "book_one"),
            EntitySpy(idValue: .remote(1, nil), title: "book_two"),
            EntitySpy(idValue: .remote(2, nil), title: "book_three"),
            EntitySpy(idValue: .remote(3, nil), title: "book_four")
        ]

        let result = await entityStore.set(entities, in: WriteContext(dataTarget: .local))
        guard let result = result else {
            XCTFail("Unexpectedly received nil.")
            return
        }

        if let error = result.error {
            XCTFail("Unexpected error: \(error).")
        }

        let notificationName = InMemoryStore<EntitySpy>.Constants.memoryPressureNotification
        var expectedResultCountForPlatform: Int = -1
        #if os(iOS) || os(tvOS)
        expectedResultCountForPlatform = 0
        #elseif os(macOS) || os(Linux)
        expectedResultCountForPlatform = entities.count
        #elseif os(watchOS)
        if #available(watchOS 7.0, *) {
            expectedResultCountForPlatform = 0
        } else {
            expectedResultCountForPlatform = entities.count
        }
        #else
        XCTFail("Testing on unexpected platform.")
        #endif

        if let notificationName = notificationName {
            notificationCenter.post(name: notificationName, object: nil)
        }

        let getResult = await entityStore.search(withQuery: .all, in: context)
        switch getResult {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, expectedResultCountForPlatform)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }
}
