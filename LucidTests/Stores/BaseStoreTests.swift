//
//  BaseStoreTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 12/12/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Lucid
@testable import LucidTestKit

class StoreTests: XCTestCase {

    var context: ReadContext<EntitySpy>!

    var entityStore: Storing<EntitySpy>!

    var entityRelationshipStore: Storing<EntityRelationshipSpy>!

    var additionalWaitTime: TimeInterval? { return nil }

    override class var defaultTestSuite: XCTestSuite {
        return XCTestSuite(name: "StoreTests")
    }

    override func setUp() {
        super.setUp()
        LucidConfiguration.logger = LoggerMock()
        context = ReadContext<EntitySpy>()

        let expectation = self.expectation(description: "set_up")
        asyncSetup {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    override func tearDown() {
        defer { super.tearDown() }
        context = nil
        entityStore = nil
        entityRelationshipStore = nil

        let expectation = self.expectation(description: "tear_down")
        asyncTearDown {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        EntitySpy.resetRecords()
    }

    open func asyncSetup(_ completion: @escaping () -> Void) {
        completion()
    }

    open func asyncTearDown(_ completion: @escaping () -> Void) {
        completion()
    }

    func test_store_should_create_entity_then_retrieve_it() {
        let expectation = self.expectation(description: "entity")

        entityStore.set(EntitySpy(idValue: .remote(42, nil)), in: WriteContext(dataTarget: .local)) { result in
            guard let result = result else {
                XCTFail("Unexpectedly received nil.")
                expectation.fulfill()
                return
            }

            switch result {
            case .success(let entity):

                self.entityStore.get(byID: entity.identifier, in: self.context) { result in
                    switch result {
                    case .success(let result):
                        XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                        XCTAssertEqual(result.entity?.title, "fake_title_42")

                    case .failure(let error):
                        XCTFail("Unexpected error: \(error).")
                    }
                    expectation.fulfill()
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_create_entity_then_retrieve_it_async() async {

        let setResult = await entityStore.set(EntitySpy(idValue: .remote(42, nil)), in: WriteContext(dataTarget: .local))
        guard let setResult = setResult else {
            XCTFail("Unexpectedly received nil.")
            return
        }

        switch setResult {
        case .success(let entity):

            let getResult = await self.entityStore.get(byID: entity.identifier, in: self.context)
            switch getResult {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                XCTAssertEqual(result.entity?.title, "fake_title_42")

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }

        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_complete_with_nil_when_entity_is_not_found() {
        let expectation = self.expectation(description: "entity")

        entityStore.set(EntitySpy(idValue: .remote(42, nil)), in: WriteContext(dataTarget: .local)) { result in
            guard let result = result else {
                XCTFail("Unexpectedly received nil.")
                expectation.fulfill()
                return
            }

            switch result {
            case .success:

                self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(24, nil)), in: self.context) { result in
                    switch result {
                    case .success(let result):
                        XCTAssertNil(result.entity)

                    case .failure(let error):
                        XCTFail("Unexpected error: \(error).")
                    }
                    expectation.fulfill()
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_complete_with_nil_when_entity_is_not_found_async() async {
        let result = await entityStore.set(EntitySpy(idValue: .remote(42, nil)), in: WriteContext(dataTarget: .local))
        guard let result = result else {
            XCTFail("Unexpectedly received nil.")
            return
        }

        switch result {
        case .success:

            let getResult = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(24, nil)), in: self.context)
            switch getResult {
            case .success(let result):
                XCTAssertNil(result.entity)

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }

        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_update_an_entity_and_retrieve_the_update() {
        let expectation = self.expectation(description: "entity")

        entityStore.set(EntitySpy(idValue: .remote(42, nil)), in: WriteContext(dataTarget: .local)) { result in
            guard let result = result else {
                XCTFail("Unexpectedly received nil.")
                expectation.fulfill()
                return
            }

            switch result {
            case .success(let entity):
                self.entityStore.get(byID: entity.identifier, in: self.context) { result in
                    switch result {
                    case .success(let result):
                        guard let entity = result.entity else {
                            XCTFail("Expected entity.")
                            expectation.fulfill()
                            return
                        }
                        XCTAssertEqual(entity.identifier.value.remoteValue, 42)
                        XCTAssertEqual(entity.title, "fake_title_42")

                        self.entityStore.set(EntitySpy(idValue: .remote(42, nil), title: "updated_fake_title"), in: WriteContext(dataTarget: .local)) { result in
                            guard let result = result else {
                                XCTFail("Unexpectedly received nil.")
                                expectation.fulfill()
                                return
                            }

                            switch result {
                            case .success(let entity):
                                self.entityStore.get(byID: entity.identifier, in: self.context) { result in
                                    switch result {
                                    case .success(let result):
                                        guard let entity = result.entity else {
                                            XCTFail("Expected entity.")
                                            expectation.fulfill()
                                            return
                                        }
                                        XCTAssertEqual(entity.identifier.value.remoteValue, 42)
                                        XCTAssertEqual(entity.title, "updated_fake_title")
                                    case .failure(let error):
                                        XCTFail("Unexpected error: \(error).")
                                    }
                                    expectation.fulfill()
                                }
                            case .failure(let error):
                                XCTFail("Unexpected error: \(error).")
                                expectation.fulfill()
                            }
                        }
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error).")
                        expectation.fulfill()
                    }
                }
            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_update_an_entity_and_retrieve_the_update_async() async {
        let result = await entityStore.set(EntitySpy(idValue: .remote(42, nil)), in: WriteContext(dataTarget: .local))
        guard let result = result else {
            XCTFail("Unexpectedly received nil.")
            return
        }

        switch result {
        case .success(let entity):
            let getResult = await self.entityStore.get(byID: entity.identifier, in: self.context)
            switch getResult {
            case .success(let result):
                guard let entity = result.entity else {
                    XCTFail("Expected entity.")
                    return
                }
                XCTAssertEqual(entity.identifier.value.remoteValue, 42)
                XCTAssertEqual(entity.title, "fake_title_42")

                let setResult = await self.entityStore.set(EntitySpy(idValue: .remote(42, nil), title: "updated_fake_title"), in: WriteContext(dataTarget: .local))
                guard let setResult = setResult else {
                    XCTFail("Unexpectedly received nil.")
                    return
                }

                switch setResult {
                case .success(let entity):
                    let innerGetResult = await self.entityStore.get(byID: entity.identifier, in: self.context)
                    switch innerGetResult {
                    case .success(let result):
                        guard let entity = result.entity else {
                            XCTFail("Expected entity.")
                            return
                        }
                        XCTAssertEqual(entity.identifier.value.remoteValue, 42)
                        XCTAssertEqual(entity.title, "updated_fake_title")
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error).")
                    }
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_set_1000_entities_in_under_1_second() {
        let expectation = self.expectation(description: "entity")

        let entities = (1...1000).map { EntitySpy(idValue: .remote($0, nil)) }

        entityStore.set(entities, in: WriteContext(dataTarget: .local)) { result in
            guard let result = result else {
                XCTFail("Unexpectedly received nil.")
                expectation.fulfill()
                return
            }

            switch result {
            case .success:
                expectation.fulfill()

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_set_1000_entities_in_under_1_second_async() async {
        let entities = (1...1000).map { EntitySpy(idValue: .remote($0, nil)) }

        let expectation = self.expectation(description: "entity")
        Task(priority: .high) {
            let result = await entityStore.set(entities, in: WriteContext(dataTarget: .local))

            guard let result = result else {
                XCTFail("Unexpectedly received nil.")
                expectation.fulfill()
                return
            }

            switch result {
            case .success:
                expectation.fulfill()

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
                expectation.fulfill()
            }
        }

        await waitForExpectations(timeout: 1)
    }

    func test_store_should_delete_an_entity() {
        let expectation = self.expectation(description: "entity")

        write(EntitySpy(idValue: .remote(42, nil))) {
            self.entityStore.remove(atID: EntitySpyIdentifier(value: .remote(42, nil)), in: WriteContext(dataTarget: .local)) { result in
                guard let result = result else {
                    XCTFail("Unexpectedly received nil.")
                    expectation.fulfill()
                    return
                }

                switch result {
                case .success:
                    self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.context) { result in
                        switch result {
                        case .success(let result):
                            XCTAssertNil(result.entity)

                        case .failure(let error):
                            XCTFail("Unexpected error: \(error).")
                        }
                        expectation.fulfill()
                    }
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                    expectation.fulfill()
                }
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_delete_an_entity_async() async {
        await write(EntitySpy(idValue: .remote(42, nil)))

        let result = await self.entityStore.remove(atID: EntitySpyIdentifier(value: .remote(42, nil)), in: WriteContext(dataTarget: .local))
        guard let result = result else {
            XCTFail("Unexpectedly received nil.")
            return
        }

        switch result {
        case .success:
            let getResult = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.context)
            switch getResult {
            case .success(let result):
                XCTAssertNil(result.entity)

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_delete_all_entities() {
        let doc1Expectation = self.expectation(description: "document1")
        let doc2Expectation = self.expectation(description: "document2")
        let doc3Expectation = self.expectation(description: "document3")

        write(EntitySpy(idValue: .remote(1, nil), title: "Test1")) {
            self.write(EntitySpy(idValue: .remote(2, nil), title: "Test2")) {
                self.write(EntitySpy(idValue: .remote(3, nil), title: "Another3")) {
                    self.entityStore.removeAll(withQuery: .filter(.title ~= .string("Test[1|2]")), in: WriteContext(dataTarget: .local)) { result in
                        guard let result = result else {
                            XCTFail("Unexpectedly received nil.")
                            return
                        }

                        switch result {
                        case .success:
                            self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(1, nil)), in: self.context) { result in
                                switch result {
                                case .success(let result):
                                    XCTAssertNil(result.entity)

                                case .failure(let error):
                                    XCTFail("Unexpected error: \(error).")
                                }
                                doc1Expectation.fulfill()
                            }

                            self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(2, nil)), in: self.context) { result in
                                switch result {
                                case .success(let result):
                                    XCTAssertNil(result.entity)

                                case .failure(let error):
                                    XCTFail("Unexpected error: \(error).")
                                }
                                doc2Expectation.fulfill()
                            }

                            self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(3, nil)), in: self.context) { result in
                                switch result {
                                case .success(let result):
                                    XCTAssertNotNil(result.entity)

                                case .failure(let error):
                                    XCTFail("Unexpected error: \(error).")
                                }
                                doc3Expectation.fulfill()
                            }

                        case .failure(let error):
                            XCTFail("Unexpected error: \(error).")
                        }
                    }
                }
            }
        }

        _wait(for: [doc1Expectation, doc2Expectation, doc3Expectation], timeout: 1)
    }

    func test_store_should_delete_all_entities_async() async {
        let doc1 = EntitySpy(idValue: .remote(1, nil), title: "Test1")
        let doc2 = EntitySpy(idValue: .remote(2, nil), title: "Test2")
        let doc3 = EntitySpy(idValue: .remote(3, nil), title: "Another3")

        await write([doc1, doc2, doc3])

        let result = await self.entityStore.removeAll(withQuery: .filter(.title ~= .string("Test[1|2]")), in: WriteContext(dataTarget: .local))
        guard let result = result else {
            XCTFail("Unexpectedly received nil.")
            return
        }

        switch result {
        case .success:
            let getResult1 = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(1, nil)), in: self.context)
            switch getResult1 {
            case .success(let result):
                XCTAssertNil(result.entity)

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }

            let getResult2 = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(2, nil)), in: self.context)
            switch getResult2 {
            case .success(let result):
                XCTAssertNil(result.entity)

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }

            let getResult3 = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(3, nil)), in: self.context)
            switch getResult3 {
            case .success(let result):
                XCTAssertNotNil(result.entity)

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }

        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_delete_all_entities_with_all_query() {
        let doc1Expectation = self.expectation(description: "document1")
        let doc2Expectation = self.expectation(description: "document2")
        let doc3Expectation = self.expectation(description: "document3")

        write(EntitySpy(idValue: .remote(1, nil), title: "Test1")) {
            self.write(EntitySpy(idValue: .remote(2, nil), title: "Test2")) {
                self.write(EntitySpy(idValue: .remote(3, nil), title: "Another3")) {
                    self.entityStore.removeAll(withQuery: .all, in: WriteContext(dataTarget: .local)) { result in
                        guard let result = result else {
                            XCTFail("Unexpectedly received nil.")
                            return
                        }

                        switch result {
                        case .success:
                            self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(1, nil)), in: self.context) { result in
                                switch result {
                                case .success(let result):
                                    XCTAssertNil(result.entity)

                                case .failure(let error):
                                    XCTFail("Unexpected error: \(error).")
                                }
                                doc1Expectation.fulfill()
                            }

                            self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(2, nil)), in: self.context) { result in
                                switch result {
                                case .success(let result):
                                    XCTAssertNil(result.entity)

                                case .failure(let error):
                                    XCTFail("Unexpected error: \(error).")
                                }
                                doc2Expectation.fulfill()
                            }

                            self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(3, nil)), in: self.context) { result in
                                switch result {
                                case .success(let result):
                                    XCTAssertNil(result.entity)

                                case .failure(let error):
                                    XCTFail("Unexpected error: \(error).")
                                }
                                doc3Expectation.fulfill()
                            }

                        case .failure(let error):
                            XCTFail("Unexpected error: \(error).")
                        }
                    }
                }
            }
        }

        _wait(for: [doc1Expectation, doc2Expectation, doc3Expectation], timeout: 1)
    }

    func test_store_should_delete_all_entities_with_all_query_async() async {
        let doc1 = EntitySpy(idValue: .remote(1, nil), title: "Test1")
        let doc2 = EntitySpy(idValue: .remote(2, nil), title: "Test2")
        let doc3 = EntitySpy(idValue: .remote(3, nil), title: "Another3")

        await write([doc1, doc2, doc3])

        let result = await self.entityStore.removeAll(withQuery: .all, in: WriteContext(dataTarget: .local))
        guard let result = result else {
            XCTFail("Unexpectedly received nil.")
            return
        }

        switch result {
        case .success:
            let getResult1 = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(1, nil)), in: self.context)
            switch getResult1 {
            case .success(let result):
                XCTAssertNil(result.entity)

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }

            let getResult2 = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(2, nil)), in: self.context)
            switch getResult2 {
            case .success(let result):
                XCTAssertNil(result.entity)

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }

            let getResult3 = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(3, nil)), in: self.context)
            switch getResult3 {
            case .success(let result):
                XCTAssertNil(result.entity)

            case .failure(let error):
                XCTFail("Unexpected error: \(error).")
            }

        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    // MARK: - Search

    func test_store_should_retrieve_entities_filtered_by_title_with_a_regex() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .filter(.title ~= .string("fake_title_[05]")), in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_entities_filtered_by_title_with_a_regex_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .filter(.title ~= .string("fake_title_[05]")), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 2)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_entities_with_remote_identifier_contained_in_array() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .filter(.identifier >> [EntitySpyIdentifier(value: .remote(5, nil)), EntitySpyIdentifier(value: .remote(0, nil))]), in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_entities_with_remote_identifier_contained_in_array_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .filter(.identifier >> [EntitySpyIdentifier(value: .remote(5, nil)), EntitySpyIdentifier(value: .remote(0, nil))]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 2)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_entities_with_local_identifier_contained_in_array() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .local("local_id_\($0)")) }) {
            self.entityStore.search(withQuery: .filter(.identifier >> [EntitySpyIdentifier(value: .local("local_id_5")), EntitySpyIdentifier(value: .local("local_id_0"))]), in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_entities_with_local_identifier_contained_in_array_async() async {
        await write((0..<10).map { EntitySpy(idValue: .local("local_id_\($0)")) })

        let result = await self.entityStore.search(withQuery: .filter(.identifier >> [EntitySpyIdentifier(value: .local("local_id_5")), EntitySpyIdentifier(value: .local("local_id_0"))]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 2)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_entities_with_local_and_remote_identifier_contained_in_array() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, "local_id_\($0)")) }) {
            self.entityStore.search(withQuery: .filter(.identifier >> [EntitySpyIdentifier(value: .remote(5, nil)), EntitySpyIdentifier(value: .local("local_id_0"))]), in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_entities_with_local_and_remote_identifier_contained_in_array_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, "local_id_\($0)")) })

        let result = await self.entityStore.search(withQuery: .filter(.identifier >> [EntitySpyIdentifier(value: .remote(5, nil)), EntitySpyIdentifier(value: .local("local_id_0"))]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 2)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_entities_with_identifier_and_title() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))) && .title == .string("fake_title_5")), in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_entities_with_identifier_and_title_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))) && .title == .string("fake_title_5")), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 1)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_entities_with_identifier_or_title() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))) || .title == .string("fake_title_7")),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 2)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_entities_with_identifier_or_title_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))) || .title == .string("fake_title_7")), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 2)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_entities_with_a_negated_identifier_or_title() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .filter(!(.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))) || .title == .string("fake_title_7"))),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 8)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_entities_with_a_negated_identifier_or_title_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .filter(!(.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))) || .title == .string("fake_title_7"))), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 8)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_entities_with_an_expression_evaluated_against_false() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .filter((.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil)))) == .value(.bool(false))),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 9)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_entities_with_an_expression_evaluated_against_false_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .filter((.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil)))) == .value(.bool(false))), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 9)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_entities_with_an_expression_evaluated_against_true() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .filter((.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil)))) == .value(.bool(true))),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 1)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_entities_with_an_expression_evaluated_against_true_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .filter((.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil)))) == .value(.bool(true))), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 1)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_all_entities_ordered_by_identifier_desc() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .order([.desc(by: .identifier)]),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 10)
                    XCTAssertEqual(queryResult.first?.identifier.value.remoteValue, 9)
                    XCTAssertEqual(queryResult.array.last?.identifier.value.remoteValue, 0)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_all_entities_ordered_by_identifier_desc_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .order([.desc(by: .identifier)]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 10)
            XCTAssertEqual(queryResult.first?.identifier.value.remoteValue, 9)
            XCTAssertEqual(queryResult.array.last?.identifier.value.remoteValue, 0)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_all_entities_ordered_by_identifier_asc() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .order([.asc(by: .identifier)]),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 10)
                    XCTAssertEqual(queryResult.first?.identifier.value.remoteValue, 0)
                    XCTAssertEqual(queryResult.array.last?.identifier.value.remoteValue, 9)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_all_entities_ordered_by_identifier_asc_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .order([.asc(by: .identifier)]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 10)
            XCTAssertEqual(queryResult.first?.identifier.value.remoteValue, 0)
            XCTAssertEqual(queryResult.array.last?.identifier.value.remoteValue, 9)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_all_entities_ordered_by_title_asc_identifier_asc() {
        let expectation = self.expectation(description: "entities")

        let entities: [EntitySpy] = [
            EntitySpy(idValue: .remote(0, nil), title: "book_one"),
            EntitySpy(idValue: .remote(1, nil), title: "book_two"),
            EntitySpy(idValue: .remote(2, nil), title: "book_one"),
            EntitySpy(idValue: .remote(3, nil), title: "book_two")
        ]

        write(entities) {
            self.entityStore.search(withQuery: .order([.asc(by: .index(.title)),
                                                       .asc(by: .identifier)]),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    guard queryResult.count == 4 else {
                        XCTFail("Unexpected result count")
                        return
                    }
                    XCTAssertEqual(queryResult.array[0].identifier, EntitySpyIdentifier(value: .remote(0, nil)))
                    XCTAssertEqual(queryResult.array[1].identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                    XCTAssertEqual(queryResult.array[2].identifier, EntitySpyIdentifier(value: .remote(1, nil)))
                    XCTAssertEqual(queryResult.array[3].identifier, EntitySpyIdentifier(value: .remote(3, nil)))

                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_all_entities_ordered_by_title_asc_identifier_asc_async() async {
        let entities: [EntitySpy] = [
            EntitySpy(idValue: .remote(0, nil), title: "book_one"),
            EntitySpy(idValue: .remote(1, nil), title: "book_two"),
            EntitySpy(idValue: .remote(2, nil), title: "book_one"),
            EntitySpy(idValue: .remote(3, nil), title: "book_two")
        ]

        await write(entities)

        let result = await self.entityStore.search(withQuery: .order([.asc(by: .index(.title)), .asc(by: .identifier)]), in: self.context)
        switch result {
        case .success(let queryResult):
            guard queryResult.count == 4 else {
                XCTFail("Unexpected result count")
                return
            }
            XCTAssertEqual(queryResult.array[0].identifier, EntitySpyIdentifier(value: .remote(0, nil)))
            XCTAssertEqual(queryResult.array[1].identifier, EntitySpyIdentifier(value: .remote(2, nil)))
            XCTAssertEqual(queryResult.array[2].identifier, EntitySpyIdentifier(value: .remote(1, nil)))
            XCTAssertEqual(queryResult.array[3].identifier, EntitySpyIdentifier(value: .remote(3, nil)))

        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_all_entities_ordered_by_title_asc_identifier_desc() {
        let expectation = self.expectation(description: "entities")

        let entities: [EntitySpy] = [
            EntitySpy(idValue: .remote(0, nil), title: "book_one"),
            EntitySpy(idValue: .remote(1, nil), title: "book_two"),
            EntitySpy(idValue: .remote(2, nil), title: "book_one"),
            EntitySpy(idValue: .remote(3, nil), title: "book_two")
        ]

        write(entities) {
            self.entityStore.search(withQuery: .order([.asc(by: .index(.title)),
                                                       .desc(by: .identifier)]),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    guard queryResult.count == 4 else {
                        XCTFail("Unexpected result count")
                        return
                    }
                    XCTAssertEqual(queryResult.array[0].identifier, EntitySpyIdentifier(value: .remote(2, nil)))
                    XCTAssertEqual(queryResult.array[1].identifier, EntitySpyIdentifier(value: .remote(0, nil)))
                    XCTAssertEqual(queryResult.array[2].identifier, EntitySpyIdentifier(value: .remote(3, nil)))
                    XCTAssertEqual(queryResult.array[3].identifier, EntitySpyIdentifier(value: .remote(1, nil)))

                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_all_entities_ordered_by_title_asc_identifier_desc_async() async {
        let entities: [EntitySpy] = [
            EntitySpy(idValue: .remote(0, nil), title: "book_one"),
            EntitySpy(idValue: .remote(1, nil), title: "book_two"),
            EntitySpy(idValue: .remote(2, nil), title: "book_one"),
            EntitySpy(idValue: .remote(3, nil), title: "book_two")
        ]

        await write(entities)
        let result = await self.entityStore.search(withQuery: .order([.asc(by: .index(.title)), .desc(by: .identifier)]), in: self.context)
        switch result {
        case .success(let queryResult):
            guard queryResult.count == 4 else {
                XCTFail("Unexpected result count")
                return
            }
            XCTAssertEqual(queryResult.array[0].identifier, EntitySpyIdentifier(value: .remote(2, nil)))
            XCTAssertEqual(queryResult.array[1].identifier, EntitySpyIdentifier(value: .remote(0, nil)))
            XCTAssertEqual(queryResult.array[2].identifier, EntitySpyIdentifier(value: .remote(3, nil)))
            XCTAssertEqual(queryResult.array[3].identifier, EntitySpyIdentifier(value: .remote(1, nil)))

        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_all_entities_ordered_by_array_of_identifiers() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .order([.identifiers([EntitySpyIdentifier(value: .remote(5, nil)), EntitySpyIdentifier(value: .remote(1, nil))].any)]),
                              in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 10)
                    XCTAssertEqual(queryResult.first?.identifier.value.remoteValue, 5)
                    if queryResult.count > 1 {
                        XCTAssertEqual(queryResult.array[1].identifier.value.remoteValue, 1)
                    }
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_all_entities_ordered_by_array_of_identifiers_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .order([.identifiers([EntitySpyIdentifier(value: .remote(5, nil)), EntitySpyIdentifier(value: .remote(1, nil))].any)]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 10)
            XCTAssertEqual(queryResult.first?.identifier.value.remoteValue, 5)
            if queryResult.count > 1 {
                XCTAssertEqual(queryResult.array[1].identifier.value.remoteValue, 1)
            }
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_all_entities_ordered_by_title_asc() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .order([.asc(by: .index(.title))]),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 10)
                    XCTAssertEqual(queryResult.first?.identifier.value.remoteValue, 0)
                    XCTAssertEqual(queryResult.array.last?.identifier.value.remoteValue, 9)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_all_entities_ordered_by_title_asc_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .order([.asc(by: .index(.title))]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 10)
            XCTAssertEqual(queryResult.first?.identifier.value.remoteValue, 0)
            XCTAssertEqual(queryResult.array.last?.identifier.value.remoteValue, 9)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_all_entities_ordered_by_title_desc() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: .order([.desc(by: .index(.title))]),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 10)
                    XCTAssertEqual(queryResult.first?.identifier.value.remoteValue, 9)
                    XCTAssertEqual(queryResult.array.last?.identifier.value.remoteValue, 0)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_all_entities_ordered_by_title_desc_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })

        let result = await self.entityStore.search(withQuery: .order([.desc(by: .index(.title))]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 10)
            XCTAssertEqual(queryResult.first?.identifier.value.remoteValue, 9)
            XCTAssertEqual(queryResult.array.last?.identifier.value.remoteValue, 0)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_return_a_signal_when_searching_for_an_empty_array_of_identifiers() {
        let expectation = self.expectation(description: "entities")

        write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) }) {
            self.entityStore.search(withQuery: Query(filter: .identifier >> [EntitySpyIdentifier]()),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.count, 0)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_return_a_signal_when_searching_for_an_empty_array_of_identifiers_async() async {
        await write((0..<10).map { EntitySpy(idValue: .remote($0, nil)) })
        let result = await self.entityStore.search(withQuery: Query(filter: .identifier >> [EntitySpyIdentifier]()), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.count, 0)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    // MARK: - Relationship

    func test_store_should_retrieve_one_entity_through_a_one_to_one_relationship_identifier() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, nil))
        let relationship = EntityRelationshipSpy(idValue: .remote(24, nil))

        write(entities: [entity, relationship]) {
            self.entityStore.search(withQuery: .filter(.oneRelationship == relationship.identifier),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.entity, entity)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_one_entity_through_a_one_to_one_relationship_identifier_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, nil))
        let relationship = EntityRelationshipSpy(idValue: .remote(24, nil))

        await write(entities: [entity, relationship])

        let result = await self.entityStore.search(withQuery: .filter(.oneRelationship == relationship.identifier), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.entity, entity)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_one_entity_through_a_one_to_one_relationship_with_a_local_and_remote_identifier() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, "local_id"))
        let relationship = EntityRelationshipSpy(idValue: .local("local_id"))

        write(entities: [entity, relationship]) {
            self.entityStore.search(withQuery: .filter(.oneRelationship == relationship.identifier),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.entity, entity)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_one_entity_through_a_one_to_one_relationship_with_a_local_and_remote_identifier_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, "local_id"))
        let relationship = EntityRelationshipSpy(idValue: .local("local_id"))

        await write(entities: [entity, relationship])

        let result = await self.entityStore.search(withQuery: .filter(.oneRelationship == relationship.identifier), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.entity, entity)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_one_entity_through_a_one_to_one_relationship_with_two_local_identifiers() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .local("local_id"))
        let relationship = EntityRelationshipSpy(idValue: .local("local_id"))

        write(entities: [entity, relationship]) {
            self.entityStore.search(withQuery: .filter(.oneRelationship == relationship.identifier),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.entity, entity)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_one_entity_through_a_one_to_one_relationship_with_two_local_identifiers_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .local("local_id"))
        let relationship = EntityRelationshipSpy(idValue: .local("local_id"))

        await write(entities: [entity, relationship])

        let result = await self.entityStore.search(withQuery: .filter(.oneRelationship == relationship.identifier), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.entity, entity)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_one_entity_through_a_one_to_one_relationship_with_two_full_identifiers() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, "local_id"))
        let relationship = EntityRelationshipSpy(idValue: .remote(24, "local_id"))

        write(entities: [entity, relationship]) {
            self.entityStore.search(withQuery: .filter(.oneRelationship == relationship.identifier),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.entity, entity)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_one_entity_through_a_one_to_one_relationship_with_two_full_identifiers_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, "local_id"))
        let relationship = EntityRelationshipSpy(idValue: .remote(24, "local_id"))

        await write(entities: [entity, relationship])

        let result = await self.entityStore.search(withQuery: .filter(.oneRelationship == relationship.identifier), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.entity, entity)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_several_entities_through_a_many_to_many_relationship() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), manyRelationshipsIdValues: [.remote(1, nil), .remote(2, nil)])
        let relationshipOne = EntityRelationshipSpy(idValue: .remote(1, nil))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(2, nil))

        write(entities: [entity, relationshipOne, relationshipTwo]) {
            self.entityRelationshipStore.search(withQuery: .filter(.identifier >> [relationshipOne.identifier, relationshipTwo.identifier]),
                                                in: ReadContext<EntityRelationshipSpy>()) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.first, relationshipOne)
                    XCTAssertEqual(queryResult.array.last, relationshipTwo)
                    XCTAssertEqual(queryResult.count, 2)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_several_entities_through_a_many_to_many_relationship_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), manyRelationshipsIdValues: [.remote(1, nil), .remote(2, nil)])
        let relationshipOne = EntityRelationshipSpy(idValue: .remote(1, nil))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(2, nil))

        await write(entities: [entity, relationshipOne, relationshipTwo])

        let result = await self.entityRelationshipStore.search(withQuery: .filter(.identifier >> [relationshipOne.identifier, relationshipTwo.identifier]), in: ReadContext<EntityRelationshipSpy>())
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.first, relationshipOne)
            XCTAssertEqual(queryResult.array.last, relationshipTwo)
            XCTAssertEqual(queryResult.count, 2)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_several_entities_through_a_many_to_many_relationship_with_local_and_remote_identifiers() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), manyRelationshipsIdValues: [.remote(24, "local_id_1"), .remote(25, "local_id_2")])
        let relationshipOne = EntityRelationshipSpy(idValue: .local("local_id_1"))
        let relationshipTwo = EntityRelationshipSpy(idValue: .local("local_id_2"))

        write(entities: [entity, relationshipOne, relationshipTwo]) {
            self.entityRelationshipStore.search(withQuery: .filter(.identifier >> [relationshipOne.identifier, relationshipTwo.identifier]),
                                                in: ReadContext<EntityRelationshipSpy>()) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.first, relationshipOne)
                    XCTAssertEqual(queryResult.array.last, relationshipTwo)
                    XCTAssertEqual(queryResult.count, 2)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_several_entities_through_a_many_to_many_relationship_with_local_and_remote_identifiers_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), manyRelationshipsIdValues: [.remote(24, "local_id_1"), .remote(25, "local_id_2")])
        let relationshipOne = EntityRelationshipSpy(idValue: .local("local_id_1"))
        let relationshipTwo = EntityRelationshipSpy(idValue: .local("local_id_2"))

        await write(entities: [entity, relationshipOne, relationshipTwo])

        let result = await self.entityRelationshipStore.search(withQuery: .filter(.identifier >> [relationshipOne.identifier, relationshipTwo.identifier]), in: ReadContext<EntityRelationshipSpy>())
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.first, relationshipOne)
            XCTAssertEqual(queryResult.array.last, relationshipTwo)
            XCTAssertEqual(queryResult.count, 2)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_several_entities_through_a_many_to_many_relationship_with_local_identifiers() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), manyRelationshipsIdValues: [.local("local_id_1"), .local("local_id_2")])
        let relationshipOne = EntitySpy(idValue: .local("local_id_1"))
        let relationshipTwo = EntitySpy(idValue: .local("local_id_2"))

        write(entities: [entity, relationshipOne, relationshipTwo]) {
            self.entityStore.search(withQuery: .filter(.identifier >> [relationshipOne.identifier, relationshipTwo.identifier]),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.first, relationshipOne)
                    XCTAssertEqual(queryResult.array.last, relationshipTwo)
                    XCTAssertEqual(queryResult.count, 2)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_several_entities_through_a_many_to_many_relationship_with_local_identifiers_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), manyRelationshipsIdValues: [.local("local_id_1"), .local("local_id_2")])
        let relationshipOne = EntitySpy(idValue: .local("local_id_1"))
        let relationshipTwo = EntitySpy(idValue: .local("local_id_2"))

        await write(entities: [entity, relationshipOne, relationshipTwo])

        let result = await self.entityStore.search(withQuery: .filter(.identifier >> [relationshipOne.identifier, relationshipTwo.identifier]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.first, relationshipOne)
            XCTAssertEqual(queryResult.array.last, relationshipTwo)
            XCTAssertEqual(queryResult.count, 2)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_several_entities_through_a_many_to_many_relationship_with_only_full_identifiers() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), manyRelationshipsIdValues: [.remote(24, "local_id_1"), .remote(25, "local_id_2")])
        let relationshipOne = EntityRelationshipSpy(idValue: .remote(24, "local_id_1"))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(25, "local_id_2"))

        write(entities: [entity, relationshipOne, relationshipTwo]) {
            self.entityRelationshipStore.search(withQuery: .filter(.identifier >> entity.manyRelationships),
                                                in: ReadContext<EntityRelationshipSpy>()) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.first, relationshipOne)
                    XCTAssertEqual(queryResult.array.last, relationshipTwo)
                    XCTAssertEqual(queryResult.count, 2)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_several_entities_through_a_many_to_many_relationship_with_only_full_identifiers_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), manyRelationshipsIdValues: [.remote(24, "local_id_1"), .remote(25, "local_id_2")])
        let relationshipOne = EntityRelationshipSpy(idValue: .remote(24, "local_id_1"))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(25, "local_id_2"))

        await write(entities: [entity, relationshipOne, relationshipTwo])

        let result = await self.entityRelationshipStore.search(withQuery: .filter(.identifier >> entity.manyRelationships), in: ReadContext<EntityRelationshipSpy>())
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.first, relationshipOne)
            XCTAssertEqual(queryResult.array.last, relationshipTwo)
            XCTAssertEqual(queryResult.count, 2)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_an_entity_for_which_a_relationship_identifier_is_contained_in_an_array_of_full_identifiers() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, "local_id_1"))
        let relationshipOne = EntityRelationshipSpy(idValue: .remote(24, "local_id_1"))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(25, "local_id_2"))

        write(entities: [entity, relationshipOne, relationshipTwo]) {
            self.entityStore.search(withQuery: .filter(.oneRelationship >> [relationshipOne.identifier, relationshipTwo.identifier]),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.entity, entity)
                    XCTAssertEqual(queryResult.count, 1)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_an_entity_for_which_a_relationship_identifier_is_contained_in_an_array_of_full_identifiers_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, "local_id_1"))
        let relationshipOne = EntityRelationshipSpy(idValue: .remote(24, "local_id_1"))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(25, "local_id_2"))

        await write(entities: [entity, relationshipOne, relationshipTwo])

        let result = await self.entityStore.search(withQuery: .filter(.oneRelationship >> [relationshipOne.identifier, relationshipTwo.identifier]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.entity, entity)
            XCTAssertEqual(queryResult.count, 1)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_an_entity_for_which_a_relationship_identifier_is_contained_in_an_array_of_local_identifiers() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, "local_id_1"))
        let relationshipOne = EntityRelationshipSpy(idValue: .local("local_id_1"))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(25, "local_id_2"))

        write(entities: [entity, relationshipOne, relationshipTwo]) {
            self.entityStore.search(withQuery: .filter(.oneRelationship >> [relationshipOne.identifier, relationshipTwo.identifier]),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.entity, entity)
                    XCTAssertEqual(queryResult.count, 1)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_an_entity_for_which_a_relationship_identifier_is_contained_in_an_array_of_local_identifiers_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, "local_id_1"))
        let relationshipOne = EntityRelationshipSpy(idValue: .local("local_id_1"))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(25, "local_id_2"))

        await write(entities: [entity, relationshipOne, relationshipTwo])

        let result = await self.entityStore.search(withQuery: .filter(.oneRelationship >> [relationshipOne.identifier, relationshipTwo.identifier]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.entity, entity)
            XCTAssertEqual(queryResult.count, 1)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_retrieve_an_entity_for_which_a_relationship_identifier_is_contained_in_an_array_of_remote_identifiers() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, "local_id_1"))
        let relationshipOne = EntityRelationshipSpy(idValue: .remote(24, nil))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(25, "local_id_2"))

        write(entities: [entity, relationshipOne, relationshipTwo]) {
            self.entityStore.search(withQuery: .filter(.oneRelationship >> [relationshipOne.identifier, relationshipTwo.identifier]),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertEqual(queryResult.entity, entity)
                    XCTAssertEqual(queryResult.count, 1)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_retrieve_an_entity_for_which_a_relationship_identifier_is_contained_in_an_array_of_remote_identifiers_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(24, "local_id_1"))
        let relationshipOne = EntityRelationshipSpy(idValue: .remote(24, nil))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(25, "local_id_2"))

        await write(entities: [entity, relationshipOne, relationshipTwo])

        let result = await self.entityStore.search(withQuery: .filter(.oneRelationship >> [relationshipOne.identifier, relationshipTwo.identifier]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.entity, entity)
            XCTAssertEqual(queryResult.count, 1)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    func test_store_should_not_retrieve_an_entity_for_which_a_relationship_identifier_is_not_contained_in_an_array_of_identifiers() {
        let expectation = self.expectation(description: "relationship")

        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(1, "local_id_1"))
        let relationshipOne = EntityRelationshipSpy(idValue: .remote(24, nil))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(25, "local_id_2"))

        write(entities: [entity, relationshipOne, relationshipTwo]) {
            self.entityStore.search(withQuery: .filter(.oneRelationship >> [relationshipOne.identifier, relationshipTwo.identifier]),
                                    in: self.context) { result in
                switch result {
                case .success(let queryResult):
                    XCTAssertNil(queryResult.entity)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                }
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_store_should_not_retrieve_an_entity_for_which_a_relationship_identifier_is_not_contained_in_an_array_of_identifiers_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(1, "local_id_1"))
        let relationshipOne = EntityRelationshipSpy(idValue: .remote(24, nil))
        let relationshipTwo = EntityRelationshipSpy(idValue: .remote(25, "local_id_2"))

        await write(entities: [entity, relationshipOne, relationshipTwo])

        let result = await self.entityStore.search(withQuery: .filter(.oneRelationship >> [relationshipOne.identifier, relationshipTwo.identifier]), in: self.context)
        switch result {
        case .success(let queryResult):
            XCTAssertNil(queryResult.entity)
        case .failure(let error):
            XCTFail("Unexpected error: \(error).")
        }
    }

    // MARK: - Merging

    func test_that_merging_function_is_called_when_a_matching_record_exists() {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(1, "local_id_1"))
        let updatedEntity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(2, "local_id_2"))
        let expectation = self.expectation(description: "merging")

        write(entity) {
            XCTAssertTrue(EntitySpy.mergingRecords.isEmpty)

            self.write(updatedEntity) {
                XCTAssertFalse(EntitySpy.mergingRecords.isEmpty)
                expectation.fulfill()
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_that_merging_function_is_called_when_a_matching_record_exists_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(1, "local_id_1"))
        let updatedEntity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(2, "local_id_2"))

        await write(entity)
        XCTAssertTrue(EntitySpy.mergingRecords.isEmpty)

        await self.write(updatedEntity)
        XCTAssertFalse(EntitySpy.mergingRecords.isEmpty)
    }

    func test_that_merging_entities_contains_updated_data() {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(1, "local_id_1"))
        let updatedEntity = EntitySpy(identifier: EntitySpyIdentifier(value: .remote(42, nil)),
                                      title: "another_title",
                                      subtitle: "another_subtitle",
                                      lazy: .unrequested,
                                      oneRelationship: EntityRelationshipSpyIdentifier(value: .remote(2, nil)),
                                      manyRelationships: [EntityRelationshipSpyIdentifier(value: .remote(3, nil))])

        let expectation = self.expectation(description: "merging")

        write(entity) {
            self.write(updatedEntity) {
                self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.context) { result in
                    switch result {
                    case .success(let queryResult):
                        if let resultEntity = queryResult.entity {
                            XCTAssertEqual(resultEntity, updatedEntity)
                            expectation.fulfill()
                        }
                    case .failure(let error):
                        XCTFail("could not fetch entity: \(error)")
                    }
                }
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_that_merging_entities_contains_updated_data_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(1, "local_id_1"))
        let updatedEntity = EntitySpy(identifier: EntitySpyIdentifier(value: .remote(42, nil)),
                                      title: "another_title",
                                      subtitle: "another_subtitle",
                                      lazy: .unrequested,
                                      oneRelationship: EntityRelationshipSpyIdentifier(value: .remote(2, nil)),
                                      manyRelationships: [EntityRelationshipSpyIdentifier(value: .remote(3, nil))])

        await write(entity)
        await self.write(updatedEntity)

        let result = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.context)
        switch result {
        case .success(let queryResult):
            if let resultEntity = queryResult.entity {
                XCTAssertEqual(resultEntity, updatedEntity)
            }
        case .failure(let error):
            XCTFail("could not fetch entity: \(error)")
        }
    }

    func test_that_merging_entities_updates_unrequested_lazy_value_with_requested_lazy_value() {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(1, "local_id_1"))

        let updatedEntity = EntitySpy(idValue: .remote(42, nil),
                                      title: "another_title",
                                      lazy: .requested(7))

        let expectation = self.expectation(description: "merging")

        write(entity) {
            self.write(updatedEntity) {
                self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.context) { result in
                    switch result {
                    case .success(let queryResult):
                        if let resultEntity = queryResult.entity {
                            XCTAssertEqual(resultEntity.lazy, .requested(7))
                            expectation.fulfill()
                        }
                    case .failure(let error):
                        XCTFail("could not fetch entity: \(error)")
                    }
                }
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_that_merging_entities_updates_unrequested_lazy_value_with_requested_lazy_value_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil), oneRelationshipIdValue: .remote(1, "local_id_1"))

        let updatedEntity = EntitySpy(idValue: .remote(42, nil),
                                      title: "another_title",
                                      lazy: .requested(7))

        await write(entity)
        await write(updatedEntity)

        let result = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.context)
        switch result {
        case .success(let queryResult):
            if let resultEntity = queryResult.entity {
                XCTAssertEqual(resultEntity.lazy, .requested(7))
            }
        case .failure(let error):
            XCTFail("could not fetch entity: \(error)")
        }
    }

    func test_that_merging_entities_updates_requested_lazy_value_with_requested_lazy_value() {
        let entity = EntitySpy(idValue: .remote(42, nil),
                               title: "another_title",
                               lazy: .requested(4))

        let updatedEntity = EntitySpy(idValue: .remote(42, nil),
                                      title: "another_title",
                                      lazy: .requested(7))

        let expectation = self.expectation(description: "merging")

        write(entity) {
            self.write(updatedEntity) {
                self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.context) { result in
                    switch result {
                    case .success(let queryResult):
                        if let resultEntity = queryResult.entity {
                            XCTAssertEqual(resultEntity.lazy, .requested(7))
                            expectation.fulfill()
                        }
                    case .failure(let error):
                        XCTFail("could not fetch entity: \(error)")
                    }
                }
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_that_merging_entities_updates_requested_lazy_value_with_requested_lazy_value_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil),
                               title: "another_title",
                               lazy: .requested(4))

        let updatedEntity = EntitySpy(idValue: .remote(42, nil),
                                      title: "another_title",
                                      lazy: .requested(7))

        await write(entity)
        await write(updatedEntity)

        let result = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.context)
        switch result {
        case .success(let queryResult):
            if let resultEntity = queryResult.entity {
                XCTAssertEqual(resultEntity.lazy, .requested(7))
            }
        case .failure(let error):
            XCTFail("could not fetch entity: \(error)")
        }
    }

    func test_that_merging_entities_does_not_replace_requested_lazy_value_with_unrequested_lazy_value() {
        let entity = EntitySpy(idValue: .remote(42, nil),
                               title: "another_title",
                               lazy: .requested(4))

        let updatedEntity = EntitySpy(idValue: .remote(42, nil),
                                      title: "another_title",
                                      lazy: .unrequested)

        let expectation = self.expectation(description: "merging")

        write(entity) {
            self.write(updatedEntity) {
                self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.context) { result in
                    switch result {
                    case .success(let queryResult):
                        if let resultEntity = queryResult.entity {
                            XCTAssertEqual(resultEntity.lazy, .requested(4))
                            expectation.fulfill()
                        }
                    case .failure(let error):
                        XCTFail("could not fetch entity: \(error)")
                    }
                }
            }
        }

        _wait(for: [expectation], timeout: 1)
    }

    func test_that_merging_entities_does_not_replace_requested_lazy_value_with_unrequested_lazy_value_async() async {
        let entity = EntitySpy(idValue: .remote(42, nil),
                               title: "another_title",
                               lazy: .requested(4))

        let updatedEntity = EntitySpy(idValue: .remote(42, nil),
                                      title: "another_title",
                                      lazy: .unrequested)

        await write(entity)
        await write(updatedEntity)

        let result = await self.entityStore.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.context)
        switch result {
        case .success(let queryResult):
            if let resultEntity = queryResult.entity {
                XCTAssertEqual(resultEntity.lazy, .requested(4))
            }
        case .failure(let error):
            XCTFail("could not fetch entity: \(error)")
        }
    }
}

// MARK: - Utils

extension StoreTests {

    func write(_ entities: [EntitySpy], completion: @escaping () -> Void) {
        write(entities: entities as [AnyObject], completion: completion)
    }

    func write(_ entities: [EntityRelationshipSpy], completion: @escaping () -> Void) {
        write(entities: entities as [AnyObject], completion: completion)
    }

    func write(_ entity: EntitySpy, completion: @escaping () -> Void) {
        write(entities: [entity as AnyObject], completion: completion)
    }

    func write(_ entity: EntityRelationshipSpyIdentifier, completion: @escaping () -> Void) {
        write(entities: [entity as AnyObject], completion: completion)
    }

    func write(_ entities: [EntitySpy]) async {
        await write(entities: entities as [AnyObject])
    }

    func write(_ entities: [EntityRelationshipSpy]) async {
        await write(entities: entities as [AnyObject])
    }

    func write(_ entity: EntitySpy) async {
        await write(entities: [entity as AnyObject])
    }

    func write(_ entity: EntityRelationshipSpyIdentifier) async {
        await write(entities: [entity as AnyObject])
    }

    private func write(entities: [AnyObject], completion: @escaping () -> Void) {

        let relationships = entities.lazy.compactMap { $0 as? EntityRelationshipSpy }
        let entities = entities.lazy.compactMap { $0 as? EntitySpy }

        entityStore.set(entities, in: WriteContext(dataTarget: .local)) { result in
            guard let result = result else {
                XCTFail("Unexpectedly received nil.")
                return
            }

            if let error = result.error {
                XCTFail("Unexpected error: \(error).")
            }

            self.entityRelationshipStore.set(relationships, in: WriteContext(dataTarget: .local)) { result in
                guard let result = result else {
                    XCTFail("Unexpectedly received nil.")
                    return
                }

                if let error = result.error {
                    XCTFail("Unexpected error: \(error).")
                }

                completion()
            }
        }
    }

    private func write(entities: [AnyObject]) async {

        let relationships = entities.lazy.compactMap { $0 as? EntityRelationshipSpy }
        let entities = entities.lazy.compactMap { $0 as? EntitySpy }

        let result = await entityStore.set(entities, in: WriteContext(dataTarget: .local))
        guard let result = result else {
            XCTFail("Unexpectedly received nil.")
            return
        }

        if let error = result.error {
            XCTFail("Unexpected error: \(error).")
        }

        let relationshipResult = await self.entityRelationshipStore.set(relationships, in: WriteContext(dataTarget: .local))
        guard let relationshipResult = relationshipResult else {
            XCTFail("Unexpectedly received nil.")
            return
        }

        if let error = relationshipResult.error {
            XCTFail("Unexpected error: \(error).")
        }
    }

    func _wait(for expectations: [XCTestExpectation], timeout: TimeInterval) {

        if let additionalWaitTime = additionalWaitTime {
            let additionalExpectation = self.expectation(description: "additional time")
            DispatchQueue.main.asyncAfter(deadline: .now() + additionalWaitTime) {
                additionalExpectation.fulfill()
            }
            wait(for: expectations + [additionalExpectation], timeout: timeout)
        } else {
            wait(for: expectations, timeout: timeout)
        }
    }
}
