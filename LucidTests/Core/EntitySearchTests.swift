//
//  EntitySearchTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 12/7/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Lucid_ReactiveKit
@testable import LucidTestKit_ReactiveKit

final class EntitySearchTests: XCTestCase {

    // MARK: - Filtering

    func test_filter_should_filter_by_identifier() {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        let results = entities.filter(with: .identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))))

        XCTAssertEqual(results.array.count, 1)
        XCTAssertEqual(results.first?.identifier.value.remoteValue, 5)
    }

    func test_filter_should_filter_by_identifiers_with_ors() {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        let results = entities.filter(with:
            .identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))) || .identifier == .identifier(EntitySpyIdentifier(value: .remote(8, nil)))
        )

        XCTAssertEqual(results.array.count, 2)
        XCTAssertEqual(results.first?.identifier.value.remoteValue, 5)
        XCTAssertEqual(results.array.last?.identifier.value.remoteValue, 8)
    }

    func test_filter_should_filter_by_identifiers_with_containedIn() {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        let results = entities.filter(with:
            .identifier >> [EntitySpyIdentifier(value: .remote(5, nil)), EntitySpyIdentifier(value: .remote(8, nil))]
        )

        XCTAssertEqual(results.array.count, 2)
        XCTAssertEqual(results.first?.identifier.value.remoteValue, 5)
        XCTAssertEqual(results.array.last?.identifier.value.remoteValue, 8)
    }

    func test_filter_should_match_by_identifier_and_title() {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        let results = entities.filter(with:
            .identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))) && .title == .string("fake_title_5")
        )

        XCTAssertEqual(results.array.count, 1)
        XCTAssertEqual(results.first?.identifier.value.remoteValue, 5)
        XCTAssertEqual(results.first?.title, "fake_title_5")
    }

    func test_filter_should_not_match_by_identifier_and_title() {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil), title: "fake_title") }
        let results = entities.filter(with:
            .identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))) && .title == .string("fake_title_5")
        )

        XCTAssertEqual(results.array.count, 0)
    }

    func test_filter_should_match_by_identifier_or_title() {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil), title: "fake_title") }
        let results = entities.filter(with:
            .identifier == .identifier(EntitySpyIdentifier(value: .remote(5, nil))) || .title == .string("fake_title_5")
        )

        XCTAssertEqual(results.array.count, 1)
        XCTAssertEqual(results.first?.identifier.value.remoteValue, 5)
        XCTAssertEqual(results.first?.title, "fake_title")
    }

    func test_filter_should_filter_by_relationship_identifier() {

        let entities = (0..<10).map {
            EntitySpy(idValue: .remote($0, nil), oneRelationshipIdValue: .remote($0, nil))
        }
        let results = entities.filter(with: .oneRelationship == EntityRelationshipSpyIdentifier(value: .remote(5, nil)))

        XCTAssertEqual(results.array.count, 1)
        XCTAssertEqual(results.first?.identifier.value.remoteValue, 5)
    }

    func test_filter_should_filter_by_relationship_identifiers() {

        let entities = (0..<10).map {
            EntitySpy(idValue: .remote($0, nil), oneRelationshipIdValue: .remote($0, nil))
        }
        let results = entities.filter(with:
            .oneRelationship >> [EntityRelationshipSpyIdentifier(value: .remote(5, nil)),
                                 EntityRelationshipSpyIdentifier(value: .remote(6, nil))]
        )

        XCTAssertEqual(results.array.count, 2)
        XCTAssertEqual(results.first?.identifier.value.remoteValue, 5)
        XCTAssertEqual(results.array.last?.identifier.value.remoteValue, 6)
    }

    func test_filter_should_filter_by_matching_titles() {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        let results = entities.filter(with: .title ~= .string("title_[56]"))

        XCTAssertEqual(results.array.count, 2)
        XCTAssertEqual(results.first?.identifier.value.remoteValue, 5)
        XCTAssertEqual(results.array.last?.identifier.value.remoteValue, 6)
    }

    func test_filter_should_filter_by_matching_titles_with_regex() throws {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        let regex = try NSRegularExpression(pattern: "title_[56]", options: .caseInsensitive)
        let results = entities.filter(with: .title ~= .regex(regex))

        XCTAssertEqual(results.array.count, 2)
        XCTAssertEqual(results.first?.identifier.value.remoteValue, 5)
        XCTAssertEqual(results.array.last?.identifier.value.remoteValue, 6)
    }

    // MARK: - Ordering

    func test_order_should_order_by_identifier_desc() {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        let results = entities.order(with: [.desc(by: .identifier)])

        XCTAssertEqual(results.first?.identifier.value.remoteValue, 9)
        XCTAssertEqual(results.last?.identifier.value.remoteValue, 0)
    }

    func test_order_should_order_by_identifier_asc() {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }.reversed()
        let results = entities.order(with: [.asc(by: .identifier)])

        XCTAssertEqual(results.first?.identifier.value.remoteValue, 0)
        XCTAssertEqual(results.last?.identifier.value.remoteValue, 9)
    }

    func test_order_should_order_by_title_desc() {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }
        let results = entities.order(with: [.desc(by: .index(.title))])

        XCTAssertEqual(results.first?.identifier.value.remoteValue, 9)
        XCTAssertEqual(results.last?.identifier.value.remoteValue, 0)
    }

    func test_order_should_order_by_title_asc() {

        let entities = (0..<10).map { EntitySpy(idValue: .remote($0, nil)) }.reversed()
        let results = entities.order(with: [.asc(by: .index(.title))])

        XCTAssertEqual(results.first?.identifier.value.remoteValue, 0)
        XCTAssertEqual(results.last?.identifier.value.remoteValue, 9)
    }
}
