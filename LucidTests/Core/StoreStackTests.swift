//
//  StoreStackTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 12/7/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import XCTest

@testable import Lucid
@testable import LucidTestKit

final class StoreStackTests: XCTestCase {

    private var remoteStoreSpy: StoreSpy<EntitySpy>!

    private var memoryStoreSpy: StoreSpy<EntitySpy>!

    private var storeStack: StoreStack<EntitySpy>!

    override func setUp() {
        super.setUp()

        LucidConfiguration.logger = LoggerMock()

        remoteStoreSpy = StoreSpy<EntitySpy>()
        remoteStoreSpy.levelStub = .remote

        memoryStoreSpy = StoreSpy<EntitySpy>()
        memoryStoreSpy.levelStub = .memory

        storeStack = StoreStack(stores: [memoryStoreSpy.storing, remoteStoreSpy.storing], queues: StoreStackQueues())
    }

    override func tearDown() {
        defer { super.tearDown() }

        remoteStoreSpy = nil
        memoryStoreSpy = nil
        storeStack = nil
    }

    // MARK: - get(byID:in:completion:)

    func test_should_get_from_memory_store_only() {
        memoryStoreSpy.getResultStub = .success(QueryResult(from: EntitySpy(idValue: .remote(42, nil))))

        let expectation = self.expectation(description: "entity")
        storeStack.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: ReadContext<EntitySpy>()) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.count, 0)
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.first?.value.remoteValue, 42)
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.count, 1)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_get_from_memory_then_remote_store_when_no_entity_is_found_in_memory() {
        memoryStoreSpy.getResultStub = .success(.empty())
        remoteStoreSpy.getResultStub = .success(QueryResult(from: EntitySpy(idValue: .remote(42, nil))))

        let expectation = self.expectation(description: "entity")
        storeStack.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: ReadContext<EntitySpy>()) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.first?.value.remoteValue, 42)
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.first?.value.remoteValue, 42)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.count, 1)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_get_from_memory_then_remote_store_when_memory_store_fails() {
        memoryStoreSpy.getResultStub = .failure(.notSupported)
        remoteStoreSpy.getResultStub = .success(QueryResult(from: EntitySpy(idValue: .remote(42, nil))))

        let expectation = self.expectation(description: "entity")
        storeStack.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: ReadContext<EntitySpy>()) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.first?.value.remoteValue, 42)
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.first?.value.remoteValue, 42)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.count, 1)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_fail_to_get_with_a_composite_error() {
        memoryStoreSpy.getResultStub = .failure(.notSupported)
        remoteStoreSpy.getResultStub = .failure(.api(.api(
            httpStatusCode: 400, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)
        )))

        let expectation = self.expectation(description: "entity")
        storeStack.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: ReadContext<EntitySpy>()) { result in
            switch result {
            case .failure(.composite(
                current: .api(.api(httpStatusCode: 400, errorPayload: nil, _)), previous: .notSupported)
            ):
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.first?.value.remoteValue, 42)
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.first?.value.remoteValue, 42)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.count, 1)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success:
                XCTFail("Unexpected success.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_complete_with_an_empty_result_when_stack_is_empty() {
        storeStack = StoreStack(stores: [], queues: StoreStackQueues())

        let expectation = self.expectation(description: "entity")
        storeStack.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: ReadContext<EntitySpy>()) { result in
            switch result {
            case .success(let result):
                XCTAssertNil(result.entity)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: - set(_:in:completion:)

    func test_should_set_in_remote_and_memory_stores() {
        let entity = EntitySpy(idValue: .remote(42, nil))
        memoryStoreSpy.setResultStub = .success([entity])
        remoteStoreSpy.setResultStub = .success([entity])

        let expectation = self.expectation(description: "entity")
        storeStack.set(entity, in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .success(let entity):
                XCTAssertEqual(entity.identifier.value, .remote(42, nil))
                XCTAssertEqual(self.memoryStoreSpy.entityRecords.first, entity)
                XCTAssertEqual(self.memoryStoreSpy.entityRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.entityRecords.first, entity)
                XCTAssertEqual(self.remoteStoreSpy.entityRecords.count, 1)
            case .none:
                XCTFail("Unexpected empty result.")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_fail_to_set_in_remote_and_memory_stores() {
        memoryStoreSpy.setResultStub = .failure(.notSupported)
        remoteStoreSpy.setResultStub = .failure(.api(.api(
            httpStatusCode: 400, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)
        )))

        let expectation = self.expectation(description: "entity")
        storeStack.set(EntitySpy(idValue: .remote(42, nil)), in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .failure(.composite(
                current: .api(.api(httpStatusCode: 400, errorPayload: nil, _)), previous: .notSupported)
            ):
                XCTAssertEqual(self.memoryStoreSpy.entityRecords.first?.identifier.value.remoteValue, 42)
                XCTAssertEqual(self.memoryStoreSpy.entityRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.entityRecords.first?.identifier.value.remoteValue, 42)
                XCTAssertEqual(self.remoteStoreSpy.entityRecords.count, 1)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success:
                XCTFail("Unexpected success.")
            case .none:
                XCTFail("Unexpected empty result.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_fail_to_set_in_remote_store_only() {
        memoryStoreSpy.setResultStub = .success([EntitySpy(idValue: .remote(42, nil))])
        remoteStoreSpy.setResultStub = .failure(.api(.api(
            httpStatusCode: 400, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)
        )))

        let expectation = self.expectation(description: "entity")
        storeStack.set(EntitySpy(idValue: .remote(42, nil)), in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .failure(.api(.api(httpStatusCode: 400, errorPayload: nil, _))):
                XCTAssertEqual(self.memoryStoreSpy.entityRecords.first?.identifier.value.remoteValue, 42)
                XCTAssertEqual(self.memoryStoreSpy.entityRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.entityRecords.first?.identifier.value.remoteValue, 42)
                XCTAssertEqual(self.remoteStoreSpy.entityRecords.count, 1)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .none:
                XCTFail("Unexpected empty result.")
            case .success:
                XCTFail("Unexpected success.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_not_fail_to_set_when_stack_is_empty() {
        storeStack = StoreStack(stores: [], queues: StoreStackQueues())

        let expectation = self.expectation(description: "entity")
        storeStack.set(EntitySpy(idValue: .remote(42, nil)), in: WriteContext(dataTarget: .local)) { result in
            XCTAssertNil(result?.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: - remove(atID:transaction:completion:)

    func test_should_remove_from_remote_and_memory_stores() {
        let entity = EntitySpy(idValue: .remote(42, nil))
        memoryStoreSpy.removeResultStub = .success(())
        remoteStoreSpy.removeResultStub = .success(())

        let expectation = self.expectation(description: "remove")
        storeStack.remove(atID: entity.identifier, in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .success:
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.first, entity.identifier)
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.first, entity.identifier)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.count, 1)
            case .none:
                XCTFail("Unexpected empty result.")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_fail_to_remove_in_remote_and_memory_stores() {
        memoryStoreSpy.removeResultStub = .failure(.notSupported)
        remoteStoreSpy.removeResultStub = .failure(.api(.api(
            httpStatusCode: 400, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)
        )))

        let expectation = self.expectation(description: "remove")
        storeStack.remove(atID: EntitySpyIdentifier(value: .remote(42, nil)), in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .failure(.composite(
                current: .api(.api(httpStatusCode: 400, errorPayload: nil, _)), previous: .notSupported)
            ):
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.first?.value.remoteValue, 42)
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.first?.value.remoteValue, 42)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.count, 1)
            case .none:
                XCTFail("Unexpected empty result.")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success:
                XCTFail("Unexpected success.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func _testShouldFailToRemoveInRemoteStoreOnly() {
        memoryStoreSpy.removeResultStub = .success(())
        remoteStoreSpy.removeResultStub = .failure(.api(.api(
            httpStatusCode: 400, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)
        )))

        let expectation = self.expectation(description: "remove")
        storeStack.remove(atID: EntitySpyIdentifier(value: .remote(42, nil)), in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .failure(.api(.api(httpStatusCode: 400, errorPayload: nil, _))):
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.first?.value.remoteValue, 42)
                XCTAssertEqual(self.memoryStoreSpy.identifierRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.first?.value.remoteValue, 42)
                XCTAssertEqual(self.remoteStoreSpy.identifierRecords.count, 1)
            case .none:
                XCTFail("Unexpected empty result.")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success:
                XCTFail("Unexpected success.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_fail_to_remove_in_remote_store_only_with_memory_store_first() {
        storeStack = StoreStack(stores: [memoryStoreSpy.storing, remoteStoreSpy.storing], queues: StoreStackQueues())
        _testShouldFailToRemoveInRemoteStoreOnly()
    }

    func test_should_fail_to_remove_in_remote_store_only_with_remote_store_first() {
        storeStack = StoreStack(stores: [remoteStoreSpy.storing, memoryStoreSpy.storing], queues: StoreStackQueues())
        _testShouldFailToRemoveInRemoteStoreOnly()
    }

    func test_should_not_fail_to_remove_when_stack_is_empty() {
        storeStack = StoreStack(stores: [], queues: StoreStackQueues())

        let expectation = self.expectation(description: "entity")
        storeStack.remove(atID: EntitySpyIdentifier(value: .remote(42, nil)), in: WriteContext(dataTarget: .local)) { result in
            XCTAssertNil(result?.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: - search(withQuery:in:completion:)

    func test_should_search_from_memory_store_only_when_at_least_one_local_entity_is_found() {
        memoryStoreSpy.searchResultStub = .success(.entities([EntitySpy(idValue: .remote(42, nil))]))

        let query = Query<EntitySpy>.filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(42, nil))))

        let expectation = self.expectation(description: "entities")
        storeStack.search(withQuery: query, in: ReadContext<EntitySpy>()) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.first?.identifier.value.remoteValue, 42)
                XCTAssertEqual(entities.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.queryRecords.count, 0)
                XCTAssertEqual(self.memoryStoreSpy.queryRecords.first, query)
                XCTAssertEqual(self.memoryStoreSpy.queryRecords.count, 1)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_search_from_memory_first_and_then_the_remote_store_when_no_entity_is_found_in_memory() {
        memoryStoreSpy.searchResultStub = .success(.entities([]))
        remoteStoreSpy.searchResultStub = .success(.entities([]))

        let query = Query<EntitySpy>.filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(42, nil))))

        let expectation = self.expectation(description: "entities")
        storeStack.search(withQuery: query, in: ReadContext<EntitySpy>()) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.count, 0)
                XCTAssertEqual(self.memoryStoreSpy.queryRecords.first, query)
                XCTAssertEqual(self.memoryStoreSpy.queryRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.queryRecords.count, 1)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_search_from_memory_then_remote_store_when_memory_store_fails() {
        memoryStoreSpy.searchResultStub = .failure(.notSupported)
        remoteStoreSpy.searchResultStub = .success(.entities([EntitySpy(idValue: .remote(42, nil))]))

        let query = Query<EntitySpy>.filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(42, nil))))

        let expectation = self.expectation(description: "entity")
        storeStack.search(withQuery: query, in: ReadContext<EntitySpy>()) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.first?.identifier.value.remoteValue, 42)
                XCTAssertEqual(entities.count, 1)
                XCTAssertEqual(self.memoryStoreSpy.queryRecords.first, query)
                XCTAssertEqual(self.memoryStoreSpy.queryRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.queryRecords.first, query)
                XCTAssertEqual(self.remoteStoreSpy.queryRecords.count, 1)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_fail_to_search_with_a_composite_error() {
        memoryStoreSpy.searchResultStub = .failure(.notSupported)
        remoteStoreSpy.searchResultStub = .failure(.api(.api(
            httpStatusCode: 400, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)
        )))

        let query = Query<EntitySpy>.filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(42, nil))))

        let expectation = self.expectation(description: "entity")
        storeStack.search(withQuery: query, in: ReadContext<EntitySpy>()) { result in
            switch result {
            case .failure(.composite(
                current: .api(.api(httpStatusCode: 400, errorPayload: nil, _)), previous: .notSupported)
            ):
                XCTAssertEqual(self.memoryStoreSpy.queryRecords.first, query)
                XCTAssertEqual(self.memoryStoreSpy.queryRecords.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.queryRecords.first, query)
                XCTAssertEqual(self.remoteStoreSpy.queryRecords.count, 1)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success:
                XCTFail("Unexpected success.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_only_search_in_remote_store_when_order_is_natural() {

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        remoteStoreSpy.searchResultStub = .success(.entities([EntitySpy(idValue: .remote(42, nil))]))

        let query = Query<EntitySpy>
            .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(42, nil))))
            .order([.natural])

        let expectation = self.expectation(description: "entities")
        storeStack.search(withQuery: query, in: ReadContext<EntitySpy>()) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.first?.identifier.value.remoteValue, 42)
                XCTAssertEqual(entities.count, 1)
                XCTAssertEqual(self.remoteStoreSpy.queryRecords.first, query)
                XCTAssertEqual(self.remoteStoreSpy.queryRecords.count, 1)
                XCTAssertEqual(self.memoryStoreSpy.queryRecords.count, 0)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_complete_with_empty_result_when_stack_is_empty() {
        storeStack = StoreStack(stores: [], queues: StoreStackQueues())

        let query = Query<EntitySpy>.filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(42, nil))))

        let expectation = self.expectation(description: "entity")
        storeStack.search(withQuery: query, in: ReadContext<EntitySpy>()) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success(let result):
                XCTAssertEqual(result.array.count, 0)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}
