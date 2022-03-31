//
//  CoreManagerContractTests.swift
//  LucidTests
//
//  Created by Stephane Magne on 6/4/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Combine
import XCTest

@testable import Lucid
@testable import LucidTestKit

final class CoreManagerContractTests: XCTestCase {

    private var remoteStoreSpy: StoreSpy<EntitySpy>!

    private var memoryStoreSpy: StoreSpy<EntitySpy>!

    private var manager: CoreManaging<EntitySpy, AnyEntitySpy>!

    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        remoteStoreSpy = StoreSpy()
        remoteStoreSpy.levelStub = .remote

        memoryStoreSpy = StoreSpy()
        memoryStoreSpy.levelStub = .memory

        cancellables = Set()
    }

    override func tearDown() {
        defer { super.tearDown() }

        remoteStoreSpy = nil
        memoryStoreSpy = nil
        manager = nil
        cancellables = nil
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
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested)
        ))

        let onceExpectation = self.expectation(description: "once")

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)))
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_return_complete_results_when_entity_meets_contract_requirements() {

        buildManager(for: .local)

        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(1))
        ))

        let onceExpectation = self.expectation(description: "once")

        let contract = IdentifierContract(successfulIdentifiers: [
            EntitySpyIdentifier(value: .remote(1, nil))
        ])
        let context = ReadContext<EntitySpy>(dataSource: .local, contract: contract)

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)), in: context)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_filter_results_when_enity_does_not_meet_contract_requirements() {

        buildManager(for: .local)

        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested)
        ))

        let onceExpectation = self.expectation(description: "once")

        let contract = IdentifierContract(successfulIdentifiers: [])
        let context = ReadContext<EntitySpy>(dataSource: .local, contract: contract)

        manager
            .get(byID: EntitySpyIdentifier(value: .remote(1, nil)), in: context)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertTrue(result.isEmpty)
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    // MARK: - SEARCH

    func test_core_manager_search_should_return_complete_results_when_no_contract_is_provided_for_local_only() {

        buildManager(for: .local)

        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(2))
        ]))

        let onceExpectation = self.expectation(description: "once")

        manager
            .search(withQuery: .all)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 2)
                XCTAssertEqual(result.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                XCTAssertEqual(result.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_should_return_complete_results_when_all_entities_meet_contract_requirements_for_local_only() {

        buildManager(for: .local)

        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(1)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(2))
        ]))

        let onceExpectation = self.expectation(description: "once")

        let contract = IdentifierContract(successfulIdentifiers: [
            EntitySpyIdentifier(value: .remote(1, nil)),
            EntitySpyIdentifier(value: .remote(2, nil))
        ])
        let context = ReadContext<EntitySpy>(dataSource: .local, contract: contract)

        manager
            .search(withQuery: .all, in: context)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 2)
                XCTAssertEqual(result.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                XCTAssertEqual(result.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_should_return_filtered_results_when_partial_entities_meet_contract_requirements_for_local_only() {

        buildManager(for: .local)

        memoryStoreSpy.searchResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(2))
        ]))

        let onceExpectation = self.expectation(description: "once")

        let contract = IdentifierContract(successfulIdentifiers: [
            EntitySpyIdentifier(value: .remote(2, nil))
        ])
        let context = ReadContext<EntitySpy>(dataSource: .local, contract: contract)

        manager
            .search(withQuery: .all, in: context)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    // MARK: - CONTINUOUS

    func test_continuous_obvserver_should_get_filtered_results_matching_entities_that_meet_contract_requirements() {

        buildManager(for: .remoteAndLocal)

        memoryStoreSpy.searchResultStub = .success(.entities([]))

        var continuousCount = 0
        let continuousSetupExpectation = self.expectation(description: "continuous")
        let continuousCompletedExpectation = self.expectation(description: "continuous")

        let continuousContract = IdentifierContract(successfulIdentifiers: [
            EntitySpyIdentifier(value: .remote(2, nil))
        ])
        let continuousContext = ReadContext<EntitySpy>(dataSource: .local, contract: continuousContract)

        manager
            .search(withQuery: .all, in: continuousContext)
            .continuous
            .sink { result in
                continuousCount += 1
                if continuousCount == 1 {
                    XCTAssertEqual(result.count, 0)
                    continuousSetupExpectation.fulfill()
                } else if continuousCount == 2 {
                    XCTAssertEqual(result.count, 1)
                    XCTAssertEqual(result.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                    continuousCompletedExpectation.fulfill()
                } else {
                    XCTFail("Received more responses than expected")
                }
            }
            .store(in: &cancellables)

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
            .search(withQuery: .all, in: context)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 2)
                XCTAssertEqual(result.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                XCTAssertEqual(result.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [continuousCompletedExpectation, onceExpectation], timeout: 1)
    }

    // MARK: - ReadContext.DataSource Tests

    // MARK: GET

    func test_core_manager_get_should_return_empty_results_when_no_entities_in_local_store_meet_contract_requirements() {

        buildManager(for: .remoteAndLocal)

        memoryStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested)
        ))

        let onceExpectation = self.expectation(description: "once")

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(dataSource: .local, contract: contract)

        manager
            .get(
                byID: EntitySpyIdentifier(value: .remote(1, nil)),
                in: context
            )
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertTrue(result.isEmpty)
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_return_results_from_remote_when_no_entities_in_local_store_meet_contract_requirements_for_local_or_remote_data_source() {

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: .localOr(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            ),
            contract: contract
        )

        manager
            .get(
                byID: EntitySpyIdentifier(value: .remote(1, nil)),
                in: context
            )
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.lazy.value(), 9)
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_return_results_from_remote_if_any_entities_in_local_store_do_not_meet_contract_requirements_for_local_or_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.getResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(10))
        ]))
        memoryStoreSpy.getResultStub = .success(.entities([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .unrequested)
        ]))
        memoryStoreSpy.setResultStub = .success([
            EntitySpy(idValue: .remote(1, nil), lazy: .requested(9)),
            EntitySpy(idValue: .remote(2, nil), lazy: .requested(10))
        ])

        let onceExpectation = self.expectation(description: "once")

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: .localOr(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            ),
            contract: contract
        )

        manager
            .get(
                byID: EntitySpyIdentifier(value: .remote(1, nil)),
                in: context
            )
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 2)
                XCTAssertEqual(result.array.first?.lazy.value(), 9)
                XCTAssertEqual(result.array.last?.lazy.value(), 10)
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_return_results_from_remote_when_no_entities_meet_contract_requirements_in_local_store_for_local_then_remote_data_source() {

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: .localThen(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            ),
            contract: contract
        )

        manager
            .get(
                byID: EntitySpyIdentifier(value: .remote(1, nil)),
                in: context
            )
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.lazy.value(), 9)
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_return_local_result_when_no_entities_meet_contract_requirements_in_remote_store_for_remote_or_local_data_source() {

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: true,
                trustRemoteFiltering: true
            ),
            contract: contract
        )

        manager
            .get(
                byID: EntitySpyIdentifier(value: .remote(1, nil)),
                in: context
            )
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.lazy.value(), 9)
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_get_should_return_empty_results_when_no_entities_meet_contract_requirements_in_remote_store_for_remote_data_source() {

        buildManager(for: .remoteAndLocal)

        remoteStoreSpy.getResultStub = .success(.entity(
            EntitySpy(idValue: .remote(1, nil), lazy: .unrequested)
        ))

        let onceExpectation = self.expectation(description: "once")

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .doNotPersist,
                orLocal: false,
                trustRemoteFiltering: true
            ),
            contract: contract
        )

        manager
            .get(
                byID: EntitySpyIdentifier(value: .remote(1, nil)),
                in: context
            )
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
            }, receiveValue: { result in
                XCTAssertTrue(result.isEmpty)
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(dataSource: .local, contract: contract)

        manager
            .get(
                byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                in: context
            )
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_ids_should_return_remote_results_when_at_least_one_entity_doesnt_meet_contract_requirements_in_local_store_for_local_or_remote_data_source() {

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: .localOr(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            ),
            contract: contract
        )

        manager
            .get(
                byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                in: context
            )
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 2)
                XCTAssertEqual(result.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                XCTAssertEqual(result.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_ids_should_return_remote_results_when_at_least_one_entity_doesnt_meet_contract_requirements_in_local_store_for_local_then_remote_data_source() {

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: .localThen(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            ),
            contract: contract
        )

        manager
            .get(
                byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                in: context
            )
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 2)
                XCTAssertEqual(result.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                XCTAssertEqual(result.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: true,
                trustRemoteFiltering: true
            ),
            contract: contract
        )

        manager
            .get(
                byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                in: context
            )
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_ids_should_trust_remote_results_when_applying_contract_for_remote_or_local_data_source() {

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: true,
                trustRemoteFiltering: true
            ),
            contract: contract
        )

        manager
            .get(
                byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                in: context
            )
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertTrue(result.isEmpty)
                onceExpectation.fulfill()
            })
        .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_ids_should_trust_remote_results_when_applying_contract_for_remote_data_source() {

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: false,
                trustRemoteFiltering: true
            ),
            contract: contract
        )

        manager
            .get(
                byIDs: [EntitySpyIdentifier(value: .remote(1, nil)), EntitySpyIdentifier(value: .remote(2, nil))],
                in: context
            )
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertTrue(result.isEmpty)
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(dataSource: .local, contract: contract)

        let query = Query<EntitySpy>(filter: .title == .string("test"))

        manager
            .search(withQuery: query, in: context)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: .localOr(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            ),
            contract: contract
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"))

        manager
            .search(withQuery: query, in: context)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: .localOr(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            ),
            contract: contract
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"))

        manager
            .search(withQuery: query, in: context)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 2)
                XCTAssertEqual(result.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                XCTAssertEqual(result.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: .localThen(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            ),
            contract: contract
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"))

        manager
            .search(withQuery: query, in: context)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: .localThen(
                ._remote(
                    endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                    persistenceStrategy: .persist(.retainExtraLocalData),
                    orLocal: false,
                    trustRemoteFiltering: true
                )
            ),
            contract: contract
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"))

        manager
            .search(withQuery: query, in: context)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 2)
                XCTAssertEqual(result.array.first?.identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                XCTAssertEqual(result.array.last?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: true,
                trustRemoteFiltering: true
            ),
            contract: contract
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"))

        manager
            .search(withQuery: query, in: context)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first?.identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_query_should_trust_remote_results_when_applying_contract_for_remote_or_local_data_source() {

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: true,
                trustRemoteFiltering: true
            ),
            contract: contract
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"))

        manager
            .search(withQuery: query, in: context)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertTrue(result.isEmpty)
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_core_manager_search_by_query_should_trust_remote_results_when_applying_contract_for_remote_data_source() {

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

        let contract = LazyPropertyContract()
        let context = ReadContext<EntitySpy>(
            dataSource: ._remote(
                endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42")), resultPayload: .empty),
                persistenceStrategy: .persist(.retainExtraLocalData),
                orLocal: false,
                trustRemoteFiltering: true
            ),
            contract: contract
        )

        let query = Query<EntitySpy>(filter: .title == .string("test"))

        manager
            .search(withQuery: query, in: context)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    return
                }
                onceExpectation.fulfill()
            }, receiveValue: { result in
                XCTAssertTrue(result.isEmpty)
                onceExpectation.fulfill()
            })
            .store(in: &cancellables)

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
