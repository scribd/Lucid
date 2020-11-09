//
//  InMemoryStoreTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 12/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Lucid
@testable import LucidTestKit

final class InMemoryStoreTests: StoreTests {

    override func setUp() {
        super.setUp()
        entityStore = InMemoryStore<EntitySpy>().storing
        entityRelationshipStore = InMemoryStore<EntityRelationshipSpy>().storing
    }

    override func tearDown() {
        super.tearDown()
    }

    override class var defaultTestSuite: XCTestSuite {
        return XCTestSuite(forTestCaseClass: InMemoryStoreTests.self)
    }
}
