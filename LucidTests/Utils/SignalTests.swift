//
//  Signal.swift
//  LucidTests
//
//  Created by Théophane Rupin on 4/7/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

@testable import Lucid
@testable import LucidTestKit
import XCTest
import ReactiveKit

final class SignalTests: XCTestCase {

    func test_when_should_filter_entity_updates_on_index() {
        let initialEntities = (0...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        let newEntities =
            (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "new_\($0)", subtitle: "new_\($0)") } +
            (5...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "new_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")

        subject
            .toSignal()
            .when(updatingOneOf: [.title])
            .observe { event in
                switch event {
                case .next(let update):
                    XCTAssertEqual(update.compactMap { $0.old?.title }, ["initial_0", "initial_1", "initial_2", "initial_3", "initial_4"])
                    XCTAssertEqual(update.map { $0.new?.title }, ["new_0", "new_1", "new_2", "new_3", "new_4"])
                    expectation.fulfill()

                case .completed:
                    XCTFail("Unexpected completed event")

                case .failed:
                    XCTFail("Unexpected failed event")
                }
            }
            .dispose(in: bag)

        subject.send(initialEntities)
        subject.send(newEntities)

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_when_should_filter_entity_updates_on_indices() {
        let initialEntities = (0...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        let newEntities =
            (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "new_\($0)", subtitle: "initial_\($0)") } +
            (5..<8).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") } +
            (8...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "new_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")
        let invertedExpectation = self.expectation(description: "completed")
        invertedExpectation.isInverted = true

        subject
            .toSignal()
            .when(updatingOneOf: [.title, .subtitle])
            .observe { event in
                switch event {
                case .next(let update):
                    XCTAssertEqual(update.compactMap { $0.old?.title }, ["initial_0", "initial_1", "initial_2", "initial_3", "initial_4", "initial_8", "initial_9", "initial_10"])
                    XCTAssertEqual(update.map { $0.new?.title }, ["new_0", "new_1", "new_2", "new_3", "new_4", "initial_8", "initial_9", "initial_10"])
                    expectation.fulfill()

                case .completed:
                    invertedExpectation.fulfill()

                case .failed:
                    invertedExpectation.fulfill()
                }
            }
            .dispose(in: bag)

        subject.send(initialEntities)
        subject.send(newEntities)

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_whenUpdatingAnything_should_not_filter_entity_updates() {
        let initialEntities = (0...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        let newEntities =
            (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "new_\($0)", subtitle: "initial_\($0)") } +
            (5..<8).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") } +
            (8...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "new_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")
        let invertedExpectation = self.expectation(description: "completed")
        invertedExpectation.isInverted = true

        subject
            .toSignal()
            .whenUpdatingAnything
            .observe { event in
                switch event {
                case .next(let update):
                    XCTAssertEqual(update.compactMap { $0.old }, initialEntities)
                    XCTAssertEqual(update.map { $0.new }, newEntities)
                    expectation.fulfill()

                case .completed:
                    invertedExpectation.fulfill()

                case .failed:
                    invertedExpectation.fulfill()
                }
            }
            .dispose(in: bag)

        subject.send(initialEntities)
        subject.send(newEntities)

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_when_should_not_fire_an_event_when_no_update_is_detected() {
        let initialEntities = (0...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial", subtitle: "initial") }
        let newEntities = (0...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial", subtitle: "new") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")
        expectation.isInverted = true

        subject
            .toSignal()
            .when(updatingOneOf: [.title])
            .observe { _ in
                expectation.fulfill()
            }
            .dispose(in: bag)

        subject.send(initialEntities)
        subject.send(newEntities)

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    // Insertions

    func test_no_event_should_fire_for_initial_data_when_insertions_are_included() {
        let initialEntities = (0...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        let newEntities =
            (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "new_\($0)", subtitle: "new_\($0)") } +
            (5...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "new_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")

        subject
            .toSignal()
            .when(updatingOneOf: [.title], entityRules: [.insertions])
            .observe { event in
                switch event {
                case .next(let update):
                    // only the second send event triggers a response
                    XCTAssertEqual(update.compactMap { $0.old?.title }, ["initial_0", "initial_1", "initial_2", "initial_3", "initial_4"])
                    XCTAssertEqual(update.map { $0.new?.title }, ["new_0", "new_1", "new_2", "new_3", "new_4"])
                    expectation.fulfill()

                case .completed:
                    XCTFail("Unexpected completed event")

                case .failed:
                    XCTFail("Unexpected failed event")
                }
            }
            .dispose(in: bag)

        subject.send(initialEntities)
        subject.send(newEntities)

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_an_event_should_fire_only_for_data_changes_when_insertions_are_not_included() {
        let initialEntities = (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        let secondEntities = (0..<10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        var thirdEntities = [EntitySpy(idValue: .remote(0, nil), title: "renamed_0", subtitle: "initial_0")]
        thirdEntities.append(contentsOf: (1...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") })

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "insert")

        subject
            .toSignal()
            .when(updatingOneOf: [.title], entityRules: [])
            .observe { event in
                switch event {
                case .next(let update):
                    XCTAssertEqual(update.compactMap { $0.old?.title }, ["initial_0"])
                    XCTAssertEqual(update.map { $0.new?.title }, ["renamed_0"])
                    expectation.fulfill()
    
                case .completed:
                    XCTFail("Unexpected completed event")

                case .failed:
                    XCTFail("Unexpected failed event")
                }
            }
            .dispose(in: bag)

        subject.send(initialEntities)
        subject.send(secondEntities)
        subject.send(thirdEntities)

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    // Deletions

    func test_second_event_should_only_include_mutated_entities_when_deletions_are_not_included() {
        let initialEntities = (0...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        let newEntities =
            (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "new_\($0)", subtitle: "new_\($0)") } +
            (5...8).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "new_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")

        subject
            .toSignal()
            .when(updatingOneOf: [.title], entityRules: [])
            .observe { event in
                switch event {
                case .next(let update):
                    XCTAssertEqual(update.compactMap { $0.old?.title }, ["initial_0", "initial_1", "initial_2", "initial_3", "initial_4"])
                    XCTAssertEqual(update.map { $0.new?.title }, ["new_0", "new_1", "new_2", "new_3", "new_4"])
                    expectation.fulfill()

                case .completed:
                    XCTFail("Unexpected completed event")

                case .failed:
                    XCTFail("Unexpected failed event")
                }
            }
            .dispose(in: bag)

        subject.send(initialEntities)
        subject.send(newEntities)

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_second_event_should_include_mutated_entities_and_deletions_when_deletions_are_included() {
        let initialEntities = (0...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        let newEntities =
            (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "new_\($0)", subtitle: "new_\($0)") } +
            (5...8).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "new_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")

        subject
            .toSignal()
            .when(updatingOneOf: [.title], entityRules: [.deletions])
            .observe { event in
                switch event {
                case .next(let update):
                    let oldItems = update.compactMap { $0.old?.title }
                    // matching items will always be in order at the front of the list, but
                    // deleted items have no guarantee of ordering
                    XCTAssertEqual(oldItems.prefix(5), ["initial_0", "initial_1", "initial_2", "initial_3", "initial_4"])
                    XCTAssertTrue(oldItems.contains("initial_9"))
                    XCTAssertTrue(oldItems.contains("initial_10"))
                    XCTAssertEqual(oldItems.count, 7)
                    XCTAssertEqual(update.map { $0.new?.title }, ["new_0", "new_1", "new_2", "new_3", "new_4", nil, nil])
                    expectation.fulfill()

                case .completed:
                    XCTFail("Unexpected completed event")

                case .failed:
                    XCTFail("Unexpected failed event")
                }
            }
            .dispose(in: bag)

        subject.send(initialEntities)
        subject.send(newEntities)

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_should_send_event_when_all_entities_are_deleted_when_deletions_are_included() {
        let initialEntities = (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")

        subject
            .toSignal()
            .when(updatingOneOf: [.title], entityRules: [.deletions])
            .observe { event in
                switch event {
                case .next(let update):
                    let oldItems = update.compactMap { $0.old?.title }
                    // deleted items have no guarantee of ordering
                    XCTAssertTrue(oldItems.contains("initial_0"))
                    XCTAssertTrue(oldItems.contains("initial_1"))
                    XCTAssertTrue(oldItems.contains("initial_2"))
                    XCTAssertTrue(oldItems.contains("initial_3"))
                    XCTAssertTrue(oldItems.contains("initial_4"))
                    XCTAssertEqual(oldItems.count, 5)
                    XCTAssertEqual(update.map { $0.new?.title }, [nil, nil, nil, nil, nil])
                    expectation.fulfill()

                case .completed:
                    XCTFail("Unexpected completed event")

                case .failed:
                    XCTFail("Unexpected failed event")
                }
            }
            .dispose(in: bag)

        subject.send(initialEntities)
        subject.send([])

        waitForExpectations(timeout: 0.2, handler: nil)
    }
}
