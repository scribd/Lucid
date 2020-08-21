//
//  CacheStoreTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 12/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Lucid_ReactiveKit
@testable import LucidTestKit_ReactiveKit

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

    // MARK: shouldOverwrite

    func test_cache_store_does_not_overwrite_local_when_should_overwrite_returns_false() {

        let memoryStoreSpy = StoreSpy<CacheStoreEntitySpy>()
        memoryStoreSpy.levelStub = .memory

        let diskStoreSpy = StoreSpy<CacheStoreEntitySpy>()
        diskStoreSpy.levelStub = .disk

        let entityStore = CacheStore<CacheStoreEntitySpy>(
            keyValueStore: memoryStoreSpy.storing,
            persistentStore: diskStoreSpy.storing
        ).storing

        let localEntity = CacheStoreEntitySpy(additionalValue: false)
        let updatedEntity = CacheStoreEntitySpy(additionalValue: false)

        memoryStoreSpy.searchResultStub = .success(.entity(localEntity))

        let expectation = self.expectation(description: "entities")

        entityStore.set(updatedEntity, in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .some(.success):
                XCTAssertEqual(memoryStoreSpy.searchCallCount, 1)
                XCTAssertEqual(memoryStoreSpy.setCallCount, 0)
                XCTAssertEqual(diskStoreSpy.setCallCount, 0)
                expectation.fulfill()
            case .some(.failure),
                 .none:
                XCTFail("Unexpected state")
            }
        }

        waitForExpectations(timeout: 1)
    }

    func test_cache_store_overwrites_local_when_should_overwrite_returns_true() {

        let memoryStoreSpy = StoreSpy<CacheStoreEntitySpy>()
        memoryStoreSpy.levelStub = .memory

        let diskStoreSpy = StoreSpy<CacheStoreEntitySpy>()
        diskStoreSpy.levelStub = .disk

        let entityStore = CacheStore<CacheStoreEntitySpy>(
            keyValueStore: memoryStoreSpy.storing,
            persistentStore: diskStoreSpy.storing
        ).storing

        let localEntity = CacheStoreEntitySpy(additionalValue: false)
        let updatedEntity = CacheStoreEntitySpy(additionalValue: true)

        memoryStoreSpy.searchResultStub = .success(.entity(localEntity))
        memoryStoreSpy.setResultStub = .success([updatedEntity])
        diskStoreSpy.setResultStub = .success([updatedEntity])

        let expectation = self.expectation(description: "entities")

        entityStore.set(updatedEntity, in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .some(.success):
                XCTAssertEqual(memoryStoreSpy.searchCallCount, 1)
                XCTAssertEqual(memoryStoreSpy.setCallCount, 1)
                XCTAssertEqual(diskStoreSpy.setCallCount, 1)
                expectation.fulfill()
            case .some(.failure),
                 .none:
                XCTFail("Unexpected state")
            }
        }

        waitForExpectations(timeout: 1)
    }

    func test_cache_store_uses_standard_equality_and_does_not_overwrite_local_when_should_overwrite_is_not_implemented_and_data_is_the_same() {

        let memoryStoreSpy = StoreSpy<EntitySpy>()
        memoryStoreSpy.levelStub = .memory

        let diskStoreSpy = StoreSpy<EntitySpy>()
        diskStoreSpy.levelStub = .disk

        let entityStore = CacheStore<EntitySpy>(
            keyValueStore: memoryStoreSpy.storing,
            persistentStore: diskStoreSpy.storing
        ).storing

        let localEntity = EntitySpy(idValue: .remote(42, nil), title: "test")
        let updatedEntity = EntitySpy(idValue: .remote(42, nil), title: "test")

        memoryStoreSpy.searchResultStub = .success(.entity(localEntity))

        let expectation = self.expectation(description: "entities")

        entityStore.set(updatedEntity, in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .some(.success):
                XCTAssertEqual(memoryStoreSpy.searchCallCount, 1)
                XCTAssertEqual(memoryStoreSpy.setCallCount, 0)
                XCTAssertEqual(diskStoreSpy.setCallCount, 0)
                expectation.fulfill()
            case .some(.failure),
                 .none:
                XCTFail("Unexpected state")
            }
        }

        waitForExpectations(timeout: 1)
    }

    func test_cache_store_uses_standard_equality_and_overwrites_local_when_should_overwrite_is_not_implemented_and_data_is_different() {

        let memoryStoreSpy = StoreSpy<EntitySpy>()
        memoryStoreSpy.levelStub = .memory

        let diskStoreSpy = StoreSpy<EntitySpy>()
        diskStoreSpy.levelStub = .disk

        let entityStore = CacheStore<EntitySpy>(
            keyValueStore: memoryStoreSpy.storing,
            persistentStore: diskStoreSpy.storing
        ).storing

        let localEntity = EntitySpy(idValue: .remote(42, nil), title: "test")
        let updatedEntity = EntitySpy(idValue: .remote(42, nil), title: "other_title")

        memoryStoreSpy.searchResultStub = .success(.entity(localEntity))
        memoryStoreSpy.setResultStub = .success([updatedEntity])
        diskStoreSpy.setResultStub = .success([updatedEntity])

        let expectation = self.expectation(description: "entities")

        entityStore.set(updatedEntity, in: WriteContext(dataTarget: .local)) { result in
            switch result {
            case .some(.success):
                XCTAssertEqual(memoryStoreSpy.searchCallCount, 1)
                XCTAssertEqual(memoryStoreSpy.setCallCount, 1)
                XCTAssertEqual(diskStoreSpy.setCallCount, 1)
                expectation.fulfill()
            case .some(.failure),
                 .none:
                XCTFail("Unexpected state")
            }
        }

        waitForExpectations(timeout: 1)
    }
}

private final class CacheStoreEntitySpy: LocalEntity {

    public typealias Metadata = VoidMetadata
    public typealias ResultPayload = EntityEndpointResultPayloadSpy
    public typealias QueryContext = Never

    public static let identifierTypeID = "entity_spy"

    static var stubEndpointData: EndpointStubData?

    // MARK: - Records

    static var indexNameRecords = [IndexName]()

    static var mergingRecords = [CacheStoreEntitySpy]()

    static func resetRecords() {
        stubEndpointData = nil
        indexNameRecords.removeAll()
        mergingRecords.removeAll()
    }

    // MARK: - API

    public typealias Identifier = EntitySpyIdentifier
    public typealias IndexName = EntitySpyIndexName

    public let identifier: EntitySpyIdentifier
    let title: String
    let subtitle: String
    let extra: Extra<Int>
    let additionalValue: Bool

    let oneRelationship: EntityRelationshipSpyIdentifier?
    let manyRelationships: AnySequence<EntityRelationshipSpyIdentifier>?

    init(identifier: EntitySpyIdentifier = EntitySpyIdentifier(value: .remote(1, nil)),
         title: String = "title",
         subtitle: String = "subtitle",
         extra: Extra<Int> = .unrequested,
         additionalValue: Bool) {

        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.extra = extra
        self.additionalValue = additionalValue
        self.oneRelationship = nil
        self.manyRelationships = nil
    }

    public func merging(_ updated: CacheStoreEntitySpy) -> CacheStoreEntitySpy {
        CacheStoreEntitySpy.mergingRecords.append(updated)
        return CacheStoreEntitySpy(
            identifier: updated.identifier,
            title: updated.title,
            subtitle: updated.subtitle,
            extra: extra.merging(with: updated.extra),
            additionalValue: additionalValue
        )
    }

    public func entityIndexValue(for indexName: EntitySpyIndexName) -> EntityIndexValue<EntityRelationshipSpyIdentifier, VoidSubtype> {
        CacheStoreEntitySpy.indexNameRecords.append(indexName)
        switch indexName {
        case .title:
            return .string(title)
        case .subtitle:
            return .string(subtitle)
        case .extra:
            return extra.extraValue().flatMap { (extraValue) in .optional(.int(extraValue)) } ?? .none
        case .oneRelationship:
            return oneRelationship.flatMap { .optional(.relationship($0)) } ?? .none
        case .manyRelationships:
            if let many = manyRelationships { return .optional(.array(many.map { .relationship($0) }.any)) }
            else { return .none }
        }
    }

    public var entityRelationshipIndices: [EntitySpyIndexName] {
        return [
            .oneRelationship,
            .manyRelationships
        ]
    }

    public var entityRelationshipEntityTypeUIDs: [String] {
        return [EntityRelationshipSpyIdentifier.entityTypeUID]
    }

    public static func == (lhs: CacheStoreEntitySpy, rhs: CacheStoreEntitySpy) -> Bool {
        guard lhs.identifier == rhs.identifier else { return false }
        guard lhs.title == rhs.title else { return false }
        guard lhs.extra == rhs.extra else { return false }
        guard lhs.oneRelationship == rhs.oneRelationship else { return false }
        guard lhs.manyRelationships == rhs.manyRelationships else { return false }
        return true
    }

    public func shouldOverwrite(with updated: CacheStoreEntitySpy) -> Bool {
        if updated.additionalValue != additionalValue { return true }
        if updated != self { return true }
        return false
    }
}
