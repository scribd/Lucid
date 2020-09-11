//
//  CoreDataStoreTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 12/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Lucid_ReactiveKit
@testable import LucidTestKit_ReactiveKit

final class CoreDataStoreTests: StoreTests {

    override func setUp() {
        super.setUp()

        entityStore = CoreDataStore<EntitySpy>(coreDataManager: StubCoreDataManagerFactory.shared).storing
        entityRelationshipStore = CoreDataStore<EntityRelationshipSpy>(coreDataManager: StubCoreDataManagerFactory.shared).storing
    }

    override func asyncTearDown(_ completion: @escaping () -> Void) {
        StubCoreDataManagerFactory.shared.clearDatabase { success in
            if success == false {
                XCTFail("Did not clear database successfully.")
            }
            completion()
        }
    }

    override static var defaultTestSuite: XCTestSuite {
        return XCTestSuite(forTestCaseClass: CoreDataStoreTests.self)
    }

    func test_store_should_not_retrieve_documents_with_an_invalid_expression_equal_to_another_expression() {
        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let expectation = self.expectation(description: "documents")

        let documents = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        write(documents) {
            self.entityStore.search(withQuery: .filter((.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil)))) == (.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))))),
                                    in: self.context) { result in
                switch result {
                case .failure(.notSupported):
                    break
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                case .success:
                    XCTFail("Unexpected success.")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_store_should_not_retrieve_documents_with_an_invalid_expression_contained_in_another_expression() {
        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let expectation = self.expectation(description: "documents")

        let documents = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        write(documents) {
            let filter: Query<EntitySpy>.Filter = .binary(.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))),
                                                          .containedIn,
                                                          .identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))))

            self.entityStore.search(withQuery: .filter(filter), in: self.context) { result in
                switch result {
                case .failure(.notSupported):
                    break
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                case .success:
                    XCTFail("Unexpected success.")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_store_should_not_retrieve_documents_with_an_invalid_expression_matched_against_another_expression() {
        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let expectation = self.expectation(description: "documents")

        let documents = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        write(documents) {
            self.entityStore.search(withQuery: .filter((.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil)))) ~= (.identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))))),
                                    in: self.context) { result in
                switch result {
                case .failure(.notSupported):
                    break
                case .failure(let error):
                    XCTFail("Unexpected error: \(error).")
                case .success:
                    XCTFail("Unexpected success.")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }
}
