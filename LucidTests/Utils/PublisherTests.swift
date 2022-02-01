//
//  PublisherTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 4/7/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

@testable import Lucid
@testable import LucidTestKit
import XCTest
import Combine

final class PublisherTests: XCTestCase {

    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = Set()
    }

    override func tearDown() {
        defer { super.tearDown() }
        cancellables = nil
    }

    func test_when_should_filter_entity_updates_on_index() {
        let initialEntities = (0...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        let newEntities =
            (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "new_\($0)", subtitle: "new_\($0)") } +
            (5...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "new_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")

        subject
            .when(updatingOneOf: [.title])
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { update in
                XCTAssertEqual(update.compactMap { $0.old?.title }, ["initial_0", "initial_1", "initial_2", "initial_3", "initial_4"])
                XCTAssertEqual(update.map { $0.new?.title }, ["new_0", "new_1", "new_2", "new_3", "new_4"])
                expectation.fulfill()
            })
            .store(in: &cancellables)

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
            .when(updatingOneOf: [.title, .subtitle])
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    invertedExpectation.fulfill()
                case .finished:
                    invertedExpectation.fulfill()
                }
            }, receiveValue: { update in
                XCTAssertEqual(update.compactMap { $0.old?.title }, ["initial_0", "initial_1", "initial_2", "initial_3", "initial_4", "initial_8", "initial_9", "initial_10"])
                XCTAssertEqual(update.map { $0.new?.title }, ["new_0", "new_1", "new_2", "new_3", "new_4", "initial_8", "initial_9", "initial_10"])
                expectation.fulfill()
            })
            .store(in: &cancellables)

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
            .whenUpdatingAnything
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    invertedExpectation.fulfill()
                case .finished:
                    invertedExpectation.fulfill()
                }
            }, receiveValue: { update in
                XCTAssertEqual(update.compactMap { $0.old }, initialEntities)
                XCTAssertEqual(update.map { $0.new }, newEntities)
                expectation.fulfill()
            })
            .store(in: &cancellables)

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
            .when(updatingOneOf: [.title])
            .sink(receiveCompletion: { completion in
                expectation.fulfill()
            }, receiveValue: { update in
                expectation.fulfill()
            })
            .store(in: &cancellables)

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
            .when(updatingOneOf: [.title], entityRules: [.insertions])
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { update in
                // only the second send event triggers a response
                XCTAssertEqual(update.compactMap { $0.old?.title }, ["initial_0", "initial_1", "initial_2", "initial_3", "initial_4"])
                XCTAssertEqual(update.map { $0.new?.title }, ["new_0", "new_1", "new_2", "new_3", "new_4"])
                expectation.fulfill()
            })
            .store(in: &cancellables)

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
            .when(updatingOneOf: [.title], entityRules: [])
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { update in
                XCTAssertEqual(update.compactMap { $0.old?.title }, ["initial_0"])
                XCTAssertEqual(update.map { $0.new?.title }, ["renamed_0"])
                expectation.fulfill()
            })
            .store(in: &cancellables)

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
            .when(updatingOneOf: [.title], entityRules: [])
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { update in
                XCTAssertEqual(update.compactMap { $0.old?.title }, ["initial_0", "initial_1", "initial_2", "initial_3", "initial_4"])
                XCTAssertEqual(update.map { $0.new?.title }, ["new_0", "new_1", "new_2", "new_3", "new_4"])
                expectation.fulfill()
            })
            .store(in: &cancellables)

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
            .when(updatingOneOf: [.title], entityRules: [.deletions])
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { update in
                let oldItems = update.compactMap { $0.old?.title }
                // matching items will always be in order at the front of the list, but
                // deleted items have no guarantee of ordering
                XCTAssertEqual(oldItems.prefix(5), ["initial_0", "initial_1", "initial_2", "initial_3", "initial_4"])
                XCTAssertTrue(oldItems.contains("initial_9"))
                XCTAssertTrue(oldItems.contains("initial_10"))
                XCTAssertEqual(oldItems.count, 7)
                XCTAssertEqual(update.map { $0.new?.title }, ["new_0", "new_1", "new_2", "new_3", "new_4", nil, nil])
                expectation.fulfill()
            })
            .store(in: &cancellables)

        subject.send(initialEntities)
        subject.send(newEntities)

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_should_send_event_when_all_entities_are_deleted_when_deletions_are_included() {
        let initialEntities = (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")

        subject
            .when(updatingOneOf: [.title], entityRules: [.deletions])
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { update in
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
            })
            .store(in: &cancellables)

        subject.send(initialEntities)
        subject.send([])

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    // MARK: - Flat Map Errors

    func test_flat_map_error_can_convert_error_to_alternate_error_type() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let failureExpectation = self.expectation(description: "failure")

        subject
            .flatMapError { error -> Result<[EntitySpy], SecondErrorType> in
                switch error {
                case .one: return .failure(.user)
                case .two: return .failure(.network)
                }
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTAssertEqual(error, SecondErrorType.user)
                    failureExpectation.fulfill()
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { update in
                XCTFail("Unexpected value event")
            })
            .store(in: &cancellables)

        subject.send(completion: .failure(.one))

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_flat_map_error_can_convert_error_to_output_value() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let outputExpectation = self.expectation(description: "output")

        subject
            .flatMapError { error -> Result<[EntitySpy], SecondErrorType> in
                switch error {
                case .one: return .failure(.user)
                case .two: return .success([EntitySpy(idValue: .remote(2, nil), title: "name", subtitle: "name")])
                }
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { update in
                XCTAssertEqual(update.count, 1)
                XCTAssertEqual(update.first, EntitySpy(idValue: .remote(2, nil), title: "name", subtitle: "name"))
                outputExpectation.fulfill()
            })
            .store(in: &cancellables)

        subject.send(completion: .failure(.two))

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_flat_map_error_can_convert_error_to_same_error_type() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let failureExpectation = self.expectation(description: "failure")

        subject
            .flatMapError { error -> FirstErrorType in
                switch error {
                case .one: return .two
                case .two: return .one
                }
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTAssertEqual(error, FirstErrorType.two)
                    failureExpectation.fulfill()
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { update in
                XCTFail("Unexpected value event")
            })
            .store(in: &cancellables)

        subject.send(completion: .failure(.one))

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_flat_map_error_can_convert_error_only_output_values() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let outputExpectation = self.expectation(description: "output")

        subject
            .flatMapError { error -> [EntitySpy] in
                switch error {
                case .one: return [EntitySpy(idValue: .remote(1, nil), title: "name1", subtitle: "name1")]
                case .two: return [EntitySpy(idValue: .remote(1, nil), title: "name1", subtitle: "name1"), EntitySpy(idValue: .remote(2, nil), title: "name2", subtitle: "name2")]
                }
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { update in
                XCTAssertEqual(update.count, 2)
                XCTAssertEqual(update.first, EntitySpy(idValue: .remote(1, nil), title: "name1", subtitle: "name1"))
                XCTAssertEqual(update.last, EntitySpy(idValue: .remote(2, nil), title: "name2", subtitle: "name2"))
                outputExpectation.fulfill()
            })
            .store(in: &cancellables)

        subject.send(completion: .failure(.two))

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    // MARK: - Map To Result

    func test_that_map_to_result_successfully_maps_output() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let outputExpectation = self.expectation(description: "output")

        subject
            .mapToResult()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { result in
                switch result {
                case .success(let update):
                    XCTAssertEqual(update.count, 1)
                    XCTAssertEqual(update.first, EntitySpy(idValue: .remote(1, nil), title: "name1", subtitle: "name1"))
                    outputExpectation.fulfill()
                case .failure:
                    XCTFail("Unexpected failure result")
                }
            })
            .store(in: &cancellables)

        subject.send([EntitySpy(idValue: .remote(1, nil), title: "name1", subtitle: "name1")])

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_that_map_to_result_successfully_maps_failure() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let outputExpectation = self.expectation(description: "output")

        subject
            .mapToResult()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { result in
                switch result {
                case .success:
                    XCTFail("Unexpected success result")
                case .failure(let error):
                    XCTAssertEqual(error, FirstErrorType.two)
                    outputExpectation.fulfill()
                }
            })
            .store(in: &cancellables)

        subject.send(completion: .failure(.two))

        waitForExpectations(timeout: 0.2, handler: nil)
    }
}

// MARK: - Error Types

private enum FirstErrorType: Error {
    case one
    case two
}

private enum SecondErrorType: Error {
    case user
    case network
}
