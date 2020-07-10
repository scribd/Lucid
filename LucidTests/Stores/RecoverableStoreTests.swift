//
//  RecoverableStoreTests.swift
//  LucidTests
//
//  Created by Ibrahim Sha'ath on 2/4/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import XCTest

@testable import Lucid_ReactiveKit
@testable import LucidTestKit_ReactiveKit

final class RecoverableStoreTests: StoreTests {

    private var innerMainStore: FakeStore<EntitySpy>!
    private var innerRecoveryStore: FakeStore<EntitySpy>!
    private var outerRecoverableStore: RecoverableStore<EntitySpy>!

    override func setUp() {
        super.setUp()

        innerMainStore = FakeStore<EntitySpy>(level: .disk)
        innerRecoveryStore = FakeStore<EntitySpy>(level: .disk)

        entityStore = RecoverableStore<EntitySpy>(
            mainStore: innerMainStore.storing,
            recoveryStore: innerRecoveryStore.storing
        ).storing

        entityRelationshipStore = RecoverableStore<EntityRelationshipSpy>(
            mainStore: FakeStore<EntityRelationshipSpy>(level: .disk).storing,
            recoveryStore: FakeStore<EntityRelationshipSpy>(level: .disk).storing
        ).storing
    }

    override func asyncTearDown(_ completion: @escaping () -> Void) {
        StubCoreDataManagerFactory.shared.clearDatabase { success in
            if success == false {
                XCTFail("Did not clear database successfully.")
            }
            completion()
        }
    }

    override class var defaultTestSuite: XCTestSuite {
        return XCTestSuite(forTestCaseClass: RecoverableStoreTests.self)
    }
}

extension RecoverableStoreTests {

    func test_store_should_overwrite_an_empty_main_store_with_a_non_empty_recovery_store_at_init() {

        let expectation = self.expectation(description: "expectation")

        let entities: [EntitySpy] = [
            EntitySpy(idValue: .remote(0, nil), title: "entity_one"),
            EntitySpy(idValue: .remote(1, nil), title: "entity_two"),
            EntitySpy(idValue: .remote(2, nil), title: "entity_three"),
            EntitySpy(idValue: .remote(3, nil), title: "entity_four")
        ]

        innerRecoveryStore.set(entities, in: WriteContext(dataTarget: .local)) { result in
            XCTAssertNotNil(result)
            XCTAssertNil(result?.error)

            self.outerRecoverableStore = RecoverableStore<EntitySpy>(
                mainStore: self.innerMainStore.storing,
                recoveryStore: self.innerRecoveryStore.storing
            )

            self.outerRecoverableStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in

                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.array.count, 4)

                    self.innerMainStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in

                        switch result {
                        case .success(let queryResult):
                            XCTAssertEqual(queryResult.array.count, 4)
                        case .failure:
                            XCTFail("searching main store failed")
                        }
                        expectation.fulfill()
                    }

                case .failure:
                    XCTFail("searching outer store failed")
                }
            }
        }

        self.waitForExpectations(timeout: 1)
    }

    func test_store_should_overwrite_an_empty_recovery_store_with_a_non_empty_main_store_at_init() {

        let expectation = self.expectation(description: "expectation")

        let entities: [EntitySpy] = [
            EntitySpy(idValue: .remote(0, nil), title: "entity_one"),
            EntitySpy(idValue: .remote(1, nil), title: "entity_two"),
            EntitySpy(idValue: .remote(2, nil), title: "entity_three"),
            EntitySpy(idValue: .remote(3, nil), title: "entity_four")
        ]

        innerMainStore.set(entities, in: WriteContext(dataTarget: .local)) { result in
            XCTAssertNotNil(result)
            XCTAssertNil(result?.error)

            self.outerRecoverableStore = RecoverableStore<EntitySpy>(
                mainStore: self.innerMainStore.storing,
                recoveryStore: self.innerRecoveryStore.storing
            )

            self.outerRecoverableStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in

                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.array.count, 4)

                    self.innerRecoveryStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in

                        switch result {
                        case .success(let queryResult):
                            XCTAssertEqual(queryResult.array.count, 4)
                        case .failure:
                            XCTFail("searching recovery store failed")
                        }
                        expectation.fulfill()
                    }

                case .failure:
                    XCTFail("searching outer store failed")
                }
            }
        }

        self.waitForExpectations(timeout: 1)
    }

    func test_store_should_overwrite_a_non_empty_recovery_store_with_a_non_empty_main_store_at_init() {

        let expectation = self.expectation(description: "expectation")

        let mainEntities: [EntitySpy] = [
            EntitySpy(idValue: .remote(987, nil), title: "987"),
        ]

        let recoveryEntities: [EntitySpy] = [
            EntitySpy(idValue: .remote(654, nil), title: "654"),
        ]

        innerMainStore.set(mainEntities, in: WriteContext(dataTarget: .local)) { result in
            XCTAssertNotNil(result)
            XCTAssertNil(result?.error)

            self.innerRecoveryStore.set(recoveryEntities, in: WriteContext(dataTarget: .local)) { result in
                XCTAssertNotNil(result)
                XCTAssertNil(result?.error)

                self.outerRecoverableStore = RecoverableStore<EntitySpy>(
                    mainStore: self.innerMainStore.storing,
                    recoveryStore: self.innerRecoveryStore.storing
                )

                self.outerRecoverableStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in

                    switch result {
                    case .success(let queryResult):
                        XCTAssertEqual(queryResult.array.count, 1)
                        XCTAssertEqual(queryResult.array.first?.identifier.value.remoteValue, 987)

                        self.innerRecoveryStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in

                            switch result {
                            case .success(let queryResult):
                                XCTAssertEqual(queryResult.array.count, 1)
                                XCTAssertEqual(queryResult.array.first?.identifier.value.remoteValue, 987)
                            case .failure:
                                XCTFail("searching recovery store failed")
                            }
                            expectation.fulfill()
                        }

                    case .failure:
                        XCTFail("searching outer store failed")
                    }
                }
            }
        }

        self.waitForExpectations(timeout: 1)
    }

    func test_store_only_reflects_main_store_in_get_operations() {

        let expectation = self.expectation(description: "expectation")

        let mainEntities: [EntitySpy] = [
            EntitySpy(idValue: .remote(123, nil), title: "entity_one"),
        ]

        let recoveryEntities: [EntitySpy] = [
            EntitySpy(idValue: .remote(456, nil), title: "entity_two"),
        ]

        innerMainStore.set(mainEntities, in: WriteContext(dataTarget: .local)) { result in
            XCTAssertNotNil(result)
            XCTAssertNil(result?.error)

            self.innerRecoveryStore.set(recoveryEntities, in: WriteContext(dataTarget: .local)) { result in
                XCTAssertNotNil(result)
                XCTAssertNil(result?.error)

                self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(123, nil)), in: ReadContext<EntitySpy>()) { result in

                    switch result {
                    case .success(let queryResult):
                        XCTAssertEqual(queryResult.array.count, 1)

                        self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(456, nil)), in: ReadContext<EntitySpy>()) { result in
                            switch result {
                            case .success(let queryResult):
                                XCTAssertEqual(queryResult.array.count, 0)
                            case .failure:
                                XCTFail("getting second ID from outer store failed")
                            }
                            expectation.fulfill()
                        }

                    case .failure:
                        XCTFail("getting first ID from outer store failed")
                    }
                }
            }
        }

        self.waitForExpectations(timeout: 1)
    }

    func test_store_affects_both_inner_stores_in_set_operations() {

        let expectation = self.expectation(description: "expectation")

        let entities: [EntitySpy] = [
            EntitySpy(idValue: .remote(789, nil), title: "entity_one"),
        ]

        entityStore.set(entities, in: WriteContext(dataTarget: .local)) { result in

            XCTAssertNotNil(result)
            XCTAssertNil(result?.error)

            self.innerMainStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in

                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.array.first?.identifier.value.remoteValue, 789)

                    self.innerRecoveryStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in
                        switch result {
                        case .success(let queryResult):
                            XCTAssertEqual(queryResult.array.first?.identifier.value.remoteValue, 789)
                        case .failure:
                            XCTFail("searching recovery store failed")
                        }
                        expectation.fulfill()
                    }

                case .failure:
                    XCTFail("searching main store failed")
                }
            }
        }

        self.waitForExpectations(timeout: 1)
    }

    func test_store_affects_both_inner_stores_in_remove_all_operations() {

        let expectation = self.expectation(description: "expectation")

        let entities: [EntitySpy] = [
            EntitySpy(idValue: .remote(0, nil), title: "entity_one"),
            EntitySpy(idValue: .remote(1, nil), title: "entity_two"),
            EntitySpy(idValue: .remote(2, nil), title: "entity_three"),
            EntitySpy(idValue: .remote(3, nil), title: "entity_four")
        ]

        entityStore.set(entities, in: WriteContext(dataTarget: .local)) { result in
            XCTAssertNotNil(result)
            XCTAssertNil(result?.error)

            self.entityStore.removeAll(withQuery: .all, in: WriteContext(dataTarget: .local)) { result in

                XCTAssertNotNil(result)
                XCTAssertNil(result?.error)

                self.innerMainStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in
                    switch result {
                    case .success(let queryResult):

                        XCTAssertEqual(queryResult.array.count, 0)

                        self.innerRecoveryStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in
                            switch result {
                            case .success(let queryResult):
                                XCTAssertEqual(queryResult.array.count, 0)
                            case .failure:
                                XCTFail("searching recovery store failed")
                            }
                            expectation.fulfill()
                        }

                    case .failure:
                        XCTFail("searching main store failed")
                    }
                }
            }
        }

        self.waitForExpectations(timeout: 1)
    }

    func test_store_affects_both_inner_stores_in_remove_operations() {

        let expectation = self.expectation(description: "expectation")

        let entities: [EntitySpy] = [
            EntitySpy(idValue: .remote(123, nil), title: "entity_one"),
        ]

        entityStore.set(entities, in: WriteContext(dataTarget: .local)) { result in
            XCTAssertNotNil(result)
            XCTAssertNil(result?.error)

            self.entityStore.remove(entities.map { $0.identifier }, in: WriteContext(dataTarget: .local)) { result in

                XCTAssertNotNil(result)
                XCTAssertNil(result?.error)

                self.innerMainStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in
                    switch result {
                    case .success(let queryResult):

                        XCTAssertEqual(queryResult.array.count, 0)

                        self.innerRecoveryStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in
                            switch result {
                            case .success(let queryResult):
                                XCTAssertEqual(queryResult.array.count, 0)
                            case .failure:
                                XCTFail("searching main store failed")
                            }
                            expectation.fulfill()
                        }

                    case .failure:
                        XCTFail("searching main store failed")
                    }
                }
            }
        }

        self.waitForExpectations(timeout: 1)
    }

    func test_store_only_reflects_main_store_in_search_operations() {

        let expectation = self.expectation(description: "expectation")

        let mainEntities: [EntitySpy] = [
            EntitySpy(idValue: .remote(123, nil), title: "entity_one"),
        ]

        let recoveryEntities: [EntitySpy] = [
            EntitySpy(idValue: .remote(456, nil), title: "entity_two"),
        ]

        innerMainStore.set(mainEntities, in: WriteContext(dataTarget: .local)) { result in
            XCTAssertNotNil(result)
            XCTAssertNil(result?.error)

            self.innerRecoveryStore.set(recoveryEntities, in: WriteContext(dataTarget: .local)) { result in
                XCTAssertNotNil(result)
                XCTAssertNil(result?.error)

                self.entityStore.search(withQuery: .all, in: ReadContext<EntitySpy>()) { result in

                    switch result {
                    case .success(let queryResult):
                        XCTAssertEqual(queryResult.array.first?.identifier.value.remoteValue, 123)
                    case .failure:
                        XCTFail("searching outer store failed")
                    }
                    expectation.fulfill()
                }
            }
        }

        self.waitForExpectations(timeout: 1)
    }
}
