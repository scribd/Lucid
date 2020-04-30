//
//  CacheStoreTests.swift
//  APICoreDataTests
//
//  Created by Théophane Rupin on 12/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Lucid
@testable import LucidTestKit

final class CacheStoreTests: StoreTests {
    
    override var additionalWaitTime: TimeInterval? {
        return 0.1
    }
    
    override func setUp() {
        super.setUp()

        entityStore = CacheStore<EntitySpy>(
            keyValueStore: LRUStore(
                store: InMemoryStore().storing,
                limit: 10
            ).storing,
            persistentStore: CoreDataStore(coreDataManager: StubCoreDataManagerFactory.shared).storing
        ).storing
        
        entityRelationshipStore = CacheStore<EntityRelationshipSpy>(
            keyValueStore: LRUStore(
                store: InMemoryStore().storing,
                limit: 10
            ).storing,
            persistentStore: CoreDataStore(coreDataManager: StubCoreDataManagerFactory.shared).storing
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
        return XCTestSuite(forTestCaseClass: CacheStoreTests.self)
    }
    
    func test_store_should_search_and_retrieve_a_complete_result_when_search_by_identifiers_and_cache_is_not_complete() {

        let expectation = self.expectation(description: "entities")

        let entities = (0..<20).map { EntitySpy(idValue: .remote($0, nil)) }
        write(entities) {
            self.entityStore.search(withQuery: .filter(.identifier >> entities.map { $0.identifier }), in: self.context) { result in
                switch result {
                case .success(let result):
                    XCTAssertEqual(result.count, entities.count)
                    expectation.fulfill()

                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
        
        waitForExpectations(timeout: 1)
    }
    
    func test_store_should_search_and_retrieve_a_complete_result_when_search_by_identifiers_and_cache_is_complete() {
        
        let expectation = self.expectation(description: "entities")
        
        let entities = (0..<9).map { EntitySpy(idValue: .remote($0, nil)) }
        write(entities) {
            self.entityStore.search(withQuery: .filter(.identifier >> entities.map { $0.identifier }), in: self.context) { result in
                switch result {
                case .success(let result):
                    XCTAssertEqual(result.count, entities.count)
                    expectation.fulfill()
                    
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
        
        waitForExpectations(timeout: 1)
    }

    func test_store_should_not_try_to_write_if_trying_to_save_an_entity_that_matches_exactly() {

        let entity = EntitySpy(idValue: .remote(1, nil))

        let storeSpy = StoreSpy<EntitySpy>()
        storeSpy.setResultStub = .success([entity])
        storeSpy.searchResultStub = .success(.entity(nil))

        entityStore = CacheStore<EntitySpy>(
            keyValueStore: LRUStore(
                store: storeSpy.storing,
                limit: 10
            ).storing,
            persistentStore: CoreDataStore(coreDataManager: StubCoreDataManagerFactory.shared).storing
        ).storing

        let expectation = self.expectation(description: "entities")

        self.entityStore.set(entity, in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .some(.success):
                XCTAssertEqual(storeSpy.setCallCount, 1)
                XCTAssertEqual(storeSpy.entityRecords, [entity])
                storeSpy.searchResultStub = .success(.entity(entity))

                self.entityStore.set(entity, in: WriteContext(dataTarget: .local)) { secondResult in
                    switch secondResult {
                    case .some(.success):
                        XCTAssertEqual(storeSpy.setCallCount, 1)
                        XCTAssertEqual(storeSpy.entityRecords, [entity])
                        expectation.fulfill()
                    case .some(.failure),
                         .none:
                        XCTFail("Unexpected state")
                    }
                }
            case .some(.failure),
                 .none:
                XCTFail("Unexpected state")
            }
        }

        waitForExpectations(timeout: 1)
    }

    func test_store_should_save_entity_even_when_matching_local_version_if_remote_sync_state_is_set_to_merge_identifier() {

        let entity = EntitySpy(idValue: .remote(1, nil))

        let storeSpy = StoreSpy<EntitySpy>()
        storeSpy.setResultStub = .success([entity])
        storeSpy.searchResultStub = .success(.entity(nil))

        entityStore = CacheStore<EntitySpy>(
            keyValueStore: LRUStore(
                store: storeSpy.storing,
                limit: 10
            ).storing,
            persistentStore: CoreDataStore(coreDataManager: StubCoreDataManagerFactory.shared).storing
        ).storing

        let expectation = self.expectation(description: "entities")

        self.entityStore.set(entity, in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .some(.success):
                XCTAssertEqual(storeSpy.setCallCount, 1)
                XCTAssertEqual(storeSpy.entityRecords, [entity])
                storeSpy.searchResultStub = .success(.entity(entity))

                self.entityStore.set(entity, in: WriteContext(dataTarget: .local, remoteSyncState: .mergeIdentifier)) { secondResult in
                    switch secondResult {
                    case .some(.success):
                        XCTAssertEqual(storeSpy.setCallCount, 2)
                        XCTAssertEqual(storeSpy.entityRecords, [entity, entity])
                        expectation.fulfill()
                    case .some(.failure),
                         .none:
                        XCTFail("Unexpected state")
                    }
                }
            case .some(.failure),
                 .none:
                XCTFail("Unexpected state")
            }
        }

        waitForExpectations(timeout: 1)
    }
}
