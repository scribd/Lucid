//
//  CoreManagerContractTests.swift
//  LucidTests
//
//  Created by Stephane Magne on 6/4/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import ReactiveKit
import XCTest

@testable import Lucid_ReactiveKit
@testable import LucidTestKit_ReactiveKit

final class CoreManagerContractTests: XCTestCase {

    private var remoteStoreSpy: StoreSpy<EntitySpy>!

    private var memoryStoreSpy: StoreSpy<EntitySpy>!

    private var manager: CoreManaging<EntitySpy, AnyEntitySpy>!

    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()

        Logger.shared = LoggerMock(shouldCauseFailures: false)

        remoteStoreSpy = StoreSpy()
        remoteStoreSpy.levelStub = .remote

        memoryStoreSpy = StoreSpy()
        memoryStoreSpy.levelStub = .memory

        disposeBag = DisposeBag()
    }

    override func tearDown() {
        defer { super.tearDown() }

        remoteStoreSpy = nil
        memoryStoreSpy = nil
        manager = nil
        disposeBag = nil
    }

    private enum StackType {
        case local
        case remoteAndLocal
    }

    private func buildManager(for stackType: StackType) {
        switch stackType {
        case .local:
            manager = CoreManager(stores: [memoryStoreSpy.storing]).managing()
        case .remoteAndLocal:
            manager = CoreManager(stores: [remoteStoreSpy.storing, memoryStoreSpy.storing]).managing()
        }
    }

    // MARK: - Base EntityContext Tests

    // MARK: GET

    func test_core_manager_get_should_return_complete_results_when_no_contract_is_provided() {

        buildManager(for: .local)

        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested)
        ))

        let onceExpectation = self.expectation(description: "once")

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)))
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_return_complete_results_when_extra_is_requested_and_entity_has_extra_data() {

        buildManager(for: .local)

        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), extra: .requested(1))
        ))

        let onceExpectation = self.expectation(description: "once")

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)), extras: [.extra])
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_filter_results_when_extras_are_requested_and_entity_is_missing_extra_data() {

        buildManager(for: .local)

        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested)
        ))

        let onceExpectation = self.expectation(description: "once")

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)), extras: [.extra])
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertTrue(queryResult.isEmpty)

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    // MARK: - SEARCH

    func test_core_manager_search_should_return_complete_results_when_no_contract_is_provided() {

        buildManager(for: .local)

        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(2))
        ]))

        let onceExpectation = self.expectation(description: "once")

        manager
            .search(withQuery: .all)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                    XCTAssertEqual(queryResult.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                    XCTAssertEqual(queryResult.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_should_return_complete_results_when_extra_is_requested_and_entities_have_extra_data() {

        buildManager(for: .local)

        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(1)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(2))
        ]))

        let onceExpectation = self.expectation(description: "once")

        manager
            .search(withQuery: Query(extras: [.extra]))
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                    XCTAssertEqual(queryResult.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                    XCTAssertEqual(queryResult.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_should_return_filtered_results_when_extra_is_requested_and_some_entities_are_missing_extra_data() {

        buildManager(for: .local)

        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(2))
        ]))

        let onceExpectation = self.expectation(description: "once")

        manager
            .search(withQuery: Query(extras: [.extra]))
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    // MARK: - CONTINUOUS

    func test_continuous_obvserver_should_get_filtered_results_matching_entities_that_meet_contract_requirements() {

        buildManager(for: .remoteAndLocal)

        memoryStoreSpy.searchResultStub = .success(.entities([]))

        var continuousCount = 0
        let continuousSetupExpectation = self.expectation(description: "continuous")
        let continuousCompletedExpectation = self.expectation(description: "continuous")

        manager
            .search(withQuery: Query(extras: [.extra]))
            .continuous
            .observe { event in
                switch event {
                case .next(let queryResult):
                    continuousCount += 1
                    if continuousCount == 1 {
                        XCTAssertEqual(queryResult.count, 0)
                        continuousSetupExpectation.fulfill()
                    } else if continuousCount == 2 {
                        XCTAssertEqual(queryResult.count, 1)
                        XCTAssertEqual(queryResult.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                        continuousCompletedExpectation.fulfill()
                    } else {
                        XCTFail("Received more responses than expected")
                    }

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
        }
        .dispose(in: disposeBag)

        wait(for: [continuousSetupExpectation], timeout: 1)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(2))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(2))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(
            dataSource: ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: false,
                trustRemoteFiltering: true)
        )

        manager
            .search(withQuery: .all, in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                    XCTAssertEqual(queryResult.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                    XCTAssertEqual(queryResult.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        wait(for: [continuousCompletedExpectation, onceExpectation], timeout: 1)
    }

    // MARK: - ReadContext.DataSource Tests

    // MARK: GET

    func test_core_manager_get_should_return_empty_results_when_no_entities_in_local_store_meet_contract_requirements() {

        buildManager(for: .remoteAndLocal)

        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested)
        ))

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource: .local)

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)),
                 extras: [.extra],
                 in: context)
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertTrue(queryResult.isEmpty)

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_return_results_from_remote_when_no_entities_in_local_store_meet_contract_requirements_for_local_or_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9))
        ))
        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested)
        ))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            .localOr(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            )
        )

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)),
                 extras: [.extra],
                 in: context)
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.extra.extraValue(), 9)

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_return_results_from_remote_when_no_entities_meet_contract_requirements_in_local_store_for_local_then_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9))
        ))
        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested)
        ))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            .localThen(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            )
        )

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)),
                 extras: [.extra],
                 in: context)
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.extra.extraValue(), 9)

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_return_local_result_when_no_entities_meet_contract_requirements_in_remote_store_for_remote_or_local_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested)
        ))
        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9))
        ))
        memoryStoreSpy.setResultStub = .success([
        EntitySpy(idValue: .remote(1, nil), extra: .requested(9))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: true,
                trustRemoteFiltering: true
            )
        )

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)),
                 extras: [.extra],
                 in: context)
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.extra.extraValue(), 9)

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_return_empty_results_when_no_entities_meet_contract_requirements_in_remote_store_for_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested)
        ))

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .doNotPersist,
                orLocal: false,
                trustRemoteFiltering: true
            )
        )

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)),
                 extras: [.extra],
                 in: context)
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertTrue(queryResult.isEmpty)

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }
    // MARK: SEARCH by IDs

    func test_core_manager_search_by_ids_should_trust_partial_results_in_local_store_for_local_data_source() {

        buildManager(for: .remoteAndLocal)

        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource: .local)

        manager
            .get(byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                 extras: [.extra],
                 in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_ids_should_return_remote_results_when_at_least_one_entity_doesnt_meet_contract_requirements_in_local_store_for_local_or_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            .localOr(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            )
        )

        manager
            .get(byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                 extras: [.extra],
                 in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                    XCTAssertEqual(queryResult.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                    XCTAssertEqual(queryResult.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_ids_should_return_remote_results_when_at_least_one_entity_doesnt_meet_contract_requirements_in_local_store_for_local_then_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            .localThen(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            )
        )

        manager
            .get(byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                 extras: [.extra],
                 in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                    XCTAssertEqual(queryResult.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                    XCTAssertEqual(queryResult.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
        }
        .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_ids_should_trust_partial_results_in_remote_store_for_remote_or_local_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: true,
                trustRemoteFiltering: true
            )
        )

        manager
            .get(byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                 extras: [.extra],
                 in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
        }
        .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_ids_should_trust_remote_results_when_applying_contract_for_remote_or_local_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .unrequested)
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: true,
                trustRemoteFiltering: true
            )
        )

        manager
            .get(byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                 extras: [.extra],
                 in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertTrue(queryResult.isEmpty)

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
        }
        .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_ids_should_trust_remote_results_when_applying_contract_for_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .unrequested)
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
        ]))
        memoryStoreSpy.setResultStub = .success([
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: false,
                trustRemoteFiltering: true
            )
        )

        manager
            .get(byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                 extras: [.extra],
                 in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertTrue(queryResult.isEmpty)

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
        }
        .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    // MARK: SEARCH by Query

    func test_core_manager_search_by_query_should_trust_local_store_for_local_data_source() {

        buildManager(for: .remoteAndLocal)

        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), title: "test", extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), title: "test", extra: .requested(5))
        ]))

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource: .local)

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.extra])

        manager
            .search(withQuery: query, in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_query_should_trust_partial_results_in_local_store_for_local_or_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), title: "test", extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), title: "test", extra: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), title: "test", extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), title: "test", extra: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), title: "test", extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), title: "test", extra: .requested(5))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            .localOr(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            )
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.extra])

        manager
            .search(withQuery: query, in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_query_should_fetch_results_in_remote_store_when_local_store_returns_nil_for_local_or_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), title: "test", extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), title: "test", extra: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), title: "test", extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), title: "test", extra: .unrequested)
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), title: "test", extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), title: "test", extra: .requested(5))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            .localOr(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            )
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.extra])

        manager
            .search(withQuery: query, in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                    XCTAssertEqual(queryResult.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                    XCTAssertEqual(queryResult.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
            }
            .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_query_should_trust_partial_results_in_local_store_for_local_then_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            .localThen(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            )
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.extra])

        manager
            .search(withQuery: query, in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
        }
        .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_query_should_fetch_results_in_remote_store_when_local_store_returns_nil_for_local_then_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .unrequested)
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            .localThen(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            )
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.extra])

        manager
            .search(withQuery: query, in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                    XCTAssertEqual(queryResult.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                    XCTAssertEqual(queryResult.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
        }
        .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_query_should_trust_partial_results_in_remote_store_for_remote_or_local_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: true,
                trustRemoteFiltering: true
            )
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.extra])

        manager
            .search(withQuery: query, in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
        }
        .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_query_should_trust_remote_results_when_applying_contract_for_remote_or_local_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .unrequested)
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: true,
                trustRemoteFiltering: true
            )
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.extra])

        manager
            .search(withQuery: query, in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertTrue(queryResult.isEmpty)

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
        }
        .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_query_should_trust_remote_results_when_applying_contract_for_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .unrequested),
            EntitySpy(idValue: .remote(2, nil), extra: .unrequested)
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), extra: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), extra: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
        ])

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource:
            ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: false,
                trustRemoteFiltering: true
            )
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.extra])

        manager
            .search(withQuery: query, in: context)
            .once
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertTrue(queryResult.isEmpty)

                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")

                case .completed:
                    return
                }
                onceExpectation.fulfill()
        }
        .dispose(in: disposeBag)

        waitForExpectations(timeout: 1, handler: nil)
    }
}

// MARK: - Contract Helpers

private struct IdentifierContract: EntityContract {

    let successfulIdentifiers: [EntitySpyIdentifier]

    init(successfulIdentifiers: [EntitySpyIdentifier]) {
        self.successfulIdentifiers = successfulIdentifiers
    }

    public func shouldValidate<E>(_ entityType: E.Type) -> Bool where E: Entity {
        return true
    }

    func isEntityValid<E>(_ entity: E, for query: Query<E>) -> Bool where E: Entity {
        switch entity {
        case let entity as EntitySpy:
            return successfulIdentifiers.contains(entity.identifier)
        default:
            return true
        }
    }
}

private struct LazyPropertyContract: EntityContract {

    public func shouldValidate<E>(_ entityType: E.Type) -> Bool where E: Entity {
        return true
    }

    func isEntityValid<E>(_ entity: E, for query: Query<E>) -> Bool where E: Entity {
        switch entity {
        case let entity as EntitySpy:
            switch entity.lazy {
            case .requested: return true
            case .unrequested: return false
            }
        default:
            return true
        }
    }
}
