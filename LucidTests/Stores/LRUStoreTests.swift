//
//  LRUStoreTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 12/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import XCTest

@testable import Lucid_ReactiveKit
@testable import LucidTestKit_ReactiveKit

final class LRUStoreTests: XCTestCase {

    private var context: ReadContext<EntitySpy>!

    private var storeSpy: StoreSpy<EntitySpy>!

    private var store: LRUStore<EntitySpy>!

    override func setUp() {
        super.setUp()

        LucidConfiguration.logger = LoggerMock()

        context = ReadContext<EntitySpy>()
        storeSpy = StoreSpy()
        store = LRUStore(store: storeSpy.storing, limit: 5)
    }

    override func tearDown() {
        defer { super.tearDown() }

        context = nil
        storeSpy = nil
        store = nil
    }

    func test_store_should_keep_5_entities_out_of_10() {

        storeSpy.removeResultStub = .success(())

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }

        let dispatchGroup = DispatchGroup()
        for entity in entities {
            dispatchGroup.enter()
            storeSpy.setResultStub = .success([entity])
            store.set(entity, in: WriteContext(dataTarget: .local)) { result in
                guard let result = result else {
                    XCTFail("Unexpectedly received nil.")
                    return
                }

                switch result {
                case .success:
                    break
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                dispatchGroup.leave()
            }
        }

        let expectation = self.expectation(description: "entities")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.storeSpy.setCallCount, 10)
            XCTAssertEqual(self.storeSpy.removeCallCount, 5)
            XCTAssertEqual(self.storeSpy.identifierRecords.map { $0.value.remoteValue }, [0, 1, 2, 3, 4])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_store_should_keep_5_entities_out_of_11_and_save_those_which_where_accessed_last_scenario_one() {

        storeSpy.removeResultStub = .success(())
        storeSpy.getResultStub = .success(QueryResult(from: EntitySpy()))

        let dispatchGroup = DispatchGroup()
        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        for entity in entities {
            dispatchGroup.enter()
            self.storeSpy.setResultStub = .success([entity])
            store.set(entity, in: WriteContext(dataTarget: .local)) { result in
                if result == nil {
                    XCTFail("Unexpectedly received nil.")
                } else if let error = result?.error {
                    XCTFail("Unexpected error: \(error)")
                }
                dispatchGroup.leave()
            }
        }

        let expectation = self.expectation(description: "entities")
        dispatchGroup.notify(queue: .main) {
            self.store.get(byID: EntitySpyIdentifier(value: .remote(5, nil)), in: self.context) { result in
                switch result {
                case .success(let result):
                    guard result.entity != nil else {
                        XCTFail("Did not receive valid entity")
                        return
                    }

                    let entity = EntitySpy(idValue: .remote(10, nil))
                    self.storeSpy.setResultStub = .success([entity])
                    self.store.set(entity, in: WriteContext(dataTarget: .local)) { result in
                        guard let result = result else {
                            XCTFail("Unexpectedly received nil.")
                            return
                        }

                        switch result {
                        case .success:
                            XCTAssertEqual(self.storeSpy.setCallCount, 11)
                            XCTAssertEqual(self.storeSpy.entityRecords.map { $0.identifier.value.remoteValue }, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
                            XCTAssertEqual(self.storeSpy.removeCallCount, 6)
                            XCTAssertEqual(self.storeSpy.getCallCount, 1)
                            XCTAssertEqual(self.storeSpy.identifierRecords.map { $0.value.remoteValue }, [0, 1, 2, 3, 4, 5, 6])

                        case .failure(let error):
                            XCTFail("Unexpected error: \(error)")
                        }
                        expectation.fulfill()
                    }
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_store_should_keep_5_entities_out_of_11_and_save_those_which_where_accessed_last_scenario_two() {

        storeSpy.removeResultStub = .success(())
        storeSpy.getResultStub = .success(QueryResult(from: EntitySpy()))

        let dispatchGroup = DispatchGroup()
        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        for entity in entities {
            dispatchGroup.enter()
            storeSpy.setResultStub = .success([entity])
            store.set(entity, in: WriteContext(dataTarget: .local)) { result in
                if result == nil {
                    XCTFail("Unexpectedly received nil.")
                } else if let error = result?.error {
                    XCTFail("Unexpected error: \(error)")
                }
                dispatchGroup.leave()
            }
        }

        let expectation = self.expectation(description: "entities")
        dispatchGroup.notify(queue: .main) {
            self.store.get(byID: EntitySpyIdentifier(value: .remote(2, nil)), in: self.context) { result in
                switch result {
                case .success(let result):
                    guard result.entity != nil else {
                        XCTFail("Expected entity.")
                        return
                    }
                    let entity = EntitySpy(idValue: .remote(8, nil))
                    self.storeSpy.setResultStub = .success([entity])
                    self.store.set(entity, in: WriteContext(dataTarget: .local)) { result in
                        guard let result = result else {
                            XCTFail("Unexpectedly received nil.")
                            return
                        }

                        switch result {
                        case .success:
                            XCTAssertEqual(self.storeSpy.setCallCount, 11)
                            XCTAssertEqual(self.storeSpy.entityRecords.map { $0.identifier.value.remoteValue }, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 8])
                            XCTAssertEqual(self.storeSpy.removeCallCount, 5)
                            XCTAssertEqual(self.storeSpy.getCallCount, 1)
                            XCTAssertEqual(self.storeSpy.identifierRecords.map { $0.value.remoteValue }, [0, 1, 2, 3, 4, 2])

                        case .failure(let error):
                            XCTFail("Unexpected error: \(error)")
                        }
                        expectation.fulfill()
                    }
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_store_should_store_10_entities_and_remove_10_entities() {

        storeSpy.removeResultStub = .success(())
        storeSpy.getResultStub = .success(QueryResult(from: EntitySpy()))

        let dispatchGroup = DispatchGroup()
        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        for entity in entities {
            dispatchGroup.enter()
            storeSpy.setResultStub = .success([entity])
            store.set(entity, in: WriteContext(dataTarget: .local)) { result in
                if result == nil {
                    XCTFail("Unexpectedly received nil.")
                } else if let error = result?.error {
                    XCTFail("Unexpected error: \(error)")
                }
                dispatchGroup.leave()
            }
        }

        let expectation = self.expectation(description: "entities")
        dispatchGroup.notify(queue: .main) {
            let dispatchGroup = DispatchGroup()
            for entity in entities {
                dispatchGroup.enter()
                self.store.remove(atID: entity.identifier, in: WriteContext(dataTarget: .local)) { result in
                    if result == nil {
                        XCTFail("Unexpectedly received nil.")
                    } else if let error = result?.error {
                        XCTFail("Unexpected error: \(error)")
                    }
                    dispatchGroup.leave()
                }
            }
            dispatchGroup.notify(queue: .main) {
                XCTAssertEqual(self.storeSpy.removeCallCount, 10)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }
}
