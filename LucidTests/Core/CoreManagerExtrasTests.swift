//
//  CoreManagerExtrasTests.swift
//  LucidTests
//
//  Created by Stephane Magne on 6/4/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import ReactiveKit
import XCTest

@testable import Lucid_ReactiveKit
@testable import LucidTestKit_ReactiveKit

final class CoreManagerExtrasTests: XCTestCase {

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

    // MARK: - GET

    func test_core_manager_get_should_return_complete_results_when_no_extras_are_requested() {

        buildManager(for: .local)

        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested)
        ))

        let onceExpectation = self.expectation(description: "once")

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)), extras: [])
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

    func test_core_manager_get_should_return_complete_results_when_extra_is_requested_and_entity_has_lazy_data() {

        buildManager(for: .local)

        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(1))
        ))

        let onceExpectation = self.expectation(description: "once")

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)), extras: [.lazy])
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

    func test_core_manager_get_should_filter_results_when_extras_are_requested_and_entity_is_missing_lazy_data() {

        buildManager(for: .local)

        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested)
        ))

        let onceExpectation = self.expectation(description: "once")

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)), extras: [.lazy])
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

    func test_core_manager_search_should_return_complete_results_when_no_extras_are_requested() {

        buildManager(for: .local)

        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(2))
        ]))

        let onceExpectation = self.expectation(description: "once")

        manager
            .search(withQuery: Query(extras: []))
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

    func test_core_manager_search_should_return_complete_results_when_extra_is_requested_and_entities_have_lazy_data() {

        buildManager(for: .local)

        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(1)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(2))
        ]))

        let onceExpectation = self.expectation(description: "once")

        manager
            .search(withQuery: Query(extras: [.lazy]))
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

    func test_core_manager_search_should_return_filtered_results_when_extra_is_requested_and_some_entities_are_missing_lazy_data() {

        buildManager(for: .local)

        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(2))
        ]))

        let onceExpectation = self.expectation(description: "once")

        manager
            .search(withQuery: Query(extras: [.lazy]))
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

    func test_continuous_obvserver_should_get_filtered_results_matching_extras_in_query() {

        buildManager(for: .remoteAndLocal)

        memoryStoreSpy.searchResultStub = .success(.entities([]))

        var continuousCount = 0
        let continuousSetupExpectation = self.expectation(description: "continuous")
        let continuousCompletedExpectation = self.expectation(description: "continuous")

        manager
            .search(withQuery: Query(extras: [.lazy]))
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
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(2))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(2))
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
            .search(withQuery: Query(extras: []), in: context)
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

    // MARK: - ReadContext.DataSource

    // MARK: GET

    func test_core_manager_get_should_return_empty_results_when_no_entities_match_in_local_store_for_local_data_source() {

        buildManager(for: .remoteAndLocal)

        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested)
        ))

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource: .local)

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)),
                 extras: [.lazy],
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

    func test_core_manager_get_should_return_results_from_remote_when_no_entities_match_in_local_store_for_local_or_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9))
        ))
        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested)
        ))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9))
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
                 extras: [.lazy],
                 in: context)
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.lazy.value(), 9)

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

    func test_core_manager_get_should_return_results_from_remote_when_no_entities_match_in_local_store_for_local_then_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9))
        ))
        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested)
        ))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9))
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
                 extras: [.lazy],
                 in: context)
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.lazy.value(), 9)

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

    func test_core_manager_get_should_return_local_result_when_no_entities_match_in_remote_store_for_remote_or_local_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested)
        ))
        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9))
        ))
        memoryStoreSpy.setResultStub = .success([
        EntitySpy(idValue: .remote(1, nil), lazy: .requested(9))
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
                 extras: [.lazy],
                 in: context)
            .observe { event in
                switch event {
                case .next(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                    XCTAssertEqual(queryResult.first?.lazy.value(), 9)

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

    func test_core_manager_get_should_return_empty_results_when_no_entities_match_in_remote_store_for_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested)
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
                 extras: [.lazy],
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
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource: .local)

        manager
            .get(byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                 extras: [.lazy],
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

    func test_core_manager_search_by_ids_should_return_remote_results_when_at_least_one_entity_doesnt_match_in_local_store_for_local_or_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
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
                 extras: [.lazy],
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

    func test_core_manager_search_by_ids_should_return_remote_results_when_at_least_one_entity_doesnt_match_in_local_store_for_local_then_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
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
                 extras: [.lazy],
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
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
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
                 extras: [.lazy],
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

    func test_core_manager_search_by_ids_should_trust_remote_results_when_filtering_extras_for_remote_or_local_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .unrequested)
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
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
                 extras: [.lazy],
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

    func test_core_manager_search_by_ids_should_trust_remote_results_when_filtering_extras_for_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .unrequested)
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
                 extras: [.lazy],
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
            EntitySpy(idValue: .remote(1, nil), title: "test", lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), title: "test", lazy: .requested(5))
        ]))

        let onceExpectation = self.expectation(description: "once")

        let context = ReadContext<EntitySpy>(dataSource: .local)

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.lazy])

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
            EntitySpy(idValue: .remote(1, nil), title: "test", lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), title: "test", lazy: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), title: "test", lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), title: "test", lazy: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), title: "test", lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), title: "test", lazy: .requested(5))
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

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.lazy])

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
            EntitySpy(idValue: .remote(1, nil), title: "test", lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), title: "test", lazy: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), title: "test", lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), title: "test", lazy: .unrequested)
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), title: "test", lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), title: "test", lazy: .requested(5))
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

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.lazy])

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
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
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

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.lazy])

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
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .unrequested)
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
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

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.lazy])

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
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
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

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.lazy])

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

    func test_core_manager_search_by_query_should_trust_remote_results_when_filtering_extras_for_remote_or_local_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .unrequested)
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
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

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.lazy])

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

    func test_core_manager_search_by_query_should_trust_remote_results_when_filtering_extras_for_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .unrequested)
        ]))
        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(5))
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

        let query = Query<EntitySpy>(filter: .title == .string("test"), extras: [.lazy])

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
