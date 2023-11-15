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

    private var optionalTest: Int?

    private var arrayTest: [Int]!

    override func setUp() {
        super.setUp()
        cancellables = Set()
    }

    override func tearDown() {
        defer { super.tearDown() }
        cancellables = nil
        optionalTest = nil
        arrayTest = nil
    }

    func test_when_should_filter_entity_updates_on_index() {
        let initialEntities = (0...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        let newEntities =
        (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "new_\($0)", subtitle: "new_\($0)") } +
        (5...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "new_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")
        let dispatchQueue = DispatchQueue(label: "test_queue")

        subject
            .when(updatingOneOf: [.title], on: dispatchQueue)
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

        dispatchQueue.sync { }

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
        let dispatchQueue = DispatchQueue(label: "test_queue")

        subject
            .when(updatingOneOf: [.title, .subtitle], on: dispatchQueue)
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

        dispatchQueue.sync { }

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
        let dispatchQueue = DispatchQueue(label: "test_queue")

        subject
            .when(updatingOneOf: [.title], on: dispatchQueue)
            .sink(receiveCompletion: { completion in
                expectation.fulfill()
            }, receiveValue: { update in
                expectation.fulfill()
            })
            .store(in: &cancellables)

        subject.send(initialEntities)
        subject.send(newEntities)

        dispatchQueue.sync { }

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
        let dispatchQueue = DispatchQueue(label: "test_queue")

        subject
            .when(updatingOneOf: [.title], entityRules: [.insertions], on: dispatchQueue)
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

        dispatchQueue.sync { }

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_an_event_should_fire_only_for_data_changes_when_insertions_are_not_included() {
        let initialEntities = (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        let secondEntities = (0..<10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        var thirdEntities = [EntitySpy(idValue: .remote(0, nil), title: "renamed_0", subtitle: "initial_0")]
        thirdEntities.append(contentsOf: (1...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") })

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "insert")
        let dispatchQueue = DispatchQueue(label: "test_queue")

        subject
            .when(updatingOneOf: [.title], entityRules: [], on: dispatchQueue)
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

        dispatchQueue.sync { }

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
        let dispatchQueue = DispatchQueue(label: "test_queue")

        subject
            .when(updatingOneOf: [.title], entityRules: [], on: dispatchQueue)
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

        dispatchQueue.sync { }

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_second_event_should_include_mutated_entities_and_deletions_when_deletions_are_included() {
        let initialEntities = (0...10).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }
        let newEntities = (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "new_\($0)", subtitle: "new_\($0)") } +
                          (5...8).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "new_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")
        let dispatchQueue = DispatchQueue(label: "test_queue")

        subject
            .when(updatingOneOf: [.title], entityRules: [.deletions], on: dispatchQueue)
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

        dispatchQueue.sync { }

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_should_send_event_when_all_entities_are_deleted_when_deletions_are_included() {
        let initialEntities = (0..<5).map { EntitySpy(idValue: .remote($0, nil), title: "initial_\($0)", subtitle: "initial_\($0)") }

        let subject = PassthroughSubject<[EntitySpy], Never>()
        let expectation = self.expectation(description: "update")
        let dispatchQueue = DispatchQueue(label: "test_queue")

        subject
            .when(updatingOneOf: [.title], entityRules: [.deletions], on: dispatchQueue)
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

        dispatchQueue.sync { }

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    // MARK: - Flat Map Errors

    func test_flat_map_error_can_convert_error_to_alternate_publisher_type() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let alternatePublisher1 = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let alternatePublisher2 = PassthroughSubject<[EntitySpy], FirstErrorType>()

        let outputExpectation = self.expectation(description: "output")

        subject
            .flatMapError { error -> AnyPublisher<[EntitySpy], FirstErrorType> in
                switch error {
                case .one: return alternatePublisher1.eraseToAnyPublisher()
                case .two: return alternatePublisher2.eraseToAnyPublisher()
                }
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected failure: \(error)")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { entities in
                XCTAssertEqual(entities, [EntitySpy(idValue: .remote(1, nil), title: "name", subtitle: "name")])
                outputExpectation.fulfill()
            })
            .store(in: &cancellables)

        subject.send(completion: .failure(.one))
        alternatePublisher1.send([EntitySpy(idValue: .remote(1, nil), title: "name", subtitle: "name")])
        alternatePublisher2.send([EntitySpy(idValue: .remote(2, nil), title: "name", subtitle: "name")])

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_flat_map_error_passes_through_value_when_mapping_to_alternate_publisher_type() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let alternatePublisher1 = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let alternatePublisher2 = PassthroughSubject<[EntitySpy], FirstErrorType>()

        let outputExpectation = self.expectation(description: "output")

        subject
            .flatMapError { error -> AnyPublisher<[EntitySpy], FirstErrorType> in
                switch error {
                case .one: return alternatePublisher1.eraseToAnyPublisher()
                case .two: return alternatePublisher2.eraseToAnyPublisher()
                }
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected failure: \(error)")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { entities in
                XCTAssertEqual(entities, [EntitySpy(idValue: .remote(9, nil), title: "value", subtitle: "value")])
                outputExpectation.fulfill()
            })
            .store(in: &cancellables)

        subject.send([EntitySpy(idValue: .remote(9, nil), title: "value", subtitle: "value")])
        alternatePublisher1.send([EntitySpy(idValue: .remote(1, nil), title: "name", subtitle: "name")])

        waitForExpectations(timeout: 0.2, handler: nil)
    }

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

    func test_flat_map_error_passes_through_value_when_converting_error_to_alternate_error_type() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let outputExpectation = self.expectation(description: "output")

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
                    XCTFail("Unexpected failure: \(error)")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { entities in
                XCTAssertEqual(entities, [EntitySpy(idValue: .remote(9, nil), title: "value", subtitle: "value")])
                outputExpectation.fulfill()
            })
            .store(in: &cancellables)

        subject.send([EntitySpy(idValue: .remote(9, nil), title: "value", subtitle: "value")])

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_flat_map_error_can_convert_error_to_output_value() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let outputExpectation = self.expectation(description: "output")
        outputExpectation.expectedFulfillmentCount = 2

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
                    outputExpectation.fulfill()
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

    func test_flat_map_error_passes_through_value_when_converting_error_to_output_value() {

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
                case .failure(let error):
                    XCTFail("Unexpected failure: \(error)")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { entities in
                XCTAssertEqual(entities, [EntitySpy(idValue: .remote(9, nil), title: "value", subtitle: "value")])
                outputExpectation.fulfill()
            })
            .store(in: &cancellables)

        subject.send([EntitySpy(idValue: .remote(9, nil), title: "value", subtitle: "value")])

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

    func test_flat_map_error_passes_through_value_when_converting_error_to_same_error_type() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let outputExpectation = self.expectation(description: "output")

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
                    XCTFail("Unexpected failure: \(error)")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { entities in
                XCTAssertEqual(entities, [EntitySpy(idValue: .remote(9, nil), title: "value", subtitle: "value")])
                outputExpectation.fulfill()
            })
            .store(in: &cancellables)

        subject.send([EntitySpy(idValue: .remote(9, nil), title: "value", subtitle: "value")])

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_flat_map_error_can_convert_error_only_output_values() {

        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let outputExpectation = self.expectation(description: "output")
        outputExpectation.expectedFulfillmentCount = 2

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
                    outputExpectation.fulfill()
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

    func test_flat_map_error_passes_through_value_when_converting_error_only_output_values() {

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
                case .failure(let error):
                    XCTFail("Unexpected failure: \(error)")
                case .finished:
                    XCTFail("Unexpected finished event")
                }
            }, receiveValue: { entities in
                XCTAssertEqual(entities, [EntitySpy(idValue: .remote(9, nil), title: "value", subtitle: "value")])
                outputExpectation.fulfill()
            })
            .store(in: &cancellables)

        subject.send([EntitySpy(idValue: .remote(9, nil), title: "value", subtitle: "value")])

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    // MARK: - Suppress Error

    func test_that_suppress_error_returns_error_as_finished() {
        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let outputExpectation = self.expectation(description: "output")

        subject
            .suppressError()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    outputExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTFail("Unexpected value: \(value)")
            })
            .store(in: &cancellables)

        subject.send(completion: .failure(.two))

        waitForExpectations(timeout: 0.2, handler: nil)
    }

    func test_that_suppress_error_returns_value_and_finished_untouched() {
        let subject = PassthroughSubject<[EntitySpy], FirstErrorType>()
        let outputExpectation = self.expectation(description: "output")
        outputExpectation.expectedFulfillmentCount = 2

        subject
            .suppressError()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    outputExpectation.fulfill()
                }
            }, receiveValue: { update in
                XCTAssertEqual(update.count, 1)
                XCTAssertEqual(update.first, EntitySpy(idValue: .remote(1, nil), title: "name1", subtitle: "name1"))
                outputExpectation.fulfill()
            })
            .store(in: &cancellables)

        subject.send([EntitySpy(idValue: .remote(1, nil), title: "name1", subtitle: "name1")])
        subject.send(completion: .finished)

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
        outputExpectation.expectedFulfillmentCount = 2

        subject
            .mapToResult()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    XCTFail("Unexpected failure event")
                case .finished:
                    outputExpectation.fulfill()
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

    // MARK: - Assign Output

    func test_assigning_optional_value_captures_success() {

        optionalTest = 55

        let subject = PassthroughSubject<Int?, FirstErrorType>()

        subject
            .assignOutput(to: \.optionalTest, on: self)
            .store(in: &cancellables)

        subject.send(10)

        XCTAssertEqual(optionalTest, 10)
    }

    func test_assigning_optional_value_captures_failure_as_nil() {

        optionalTest = 55

        let subject = PassthroughSubject<Int?, FirstErrorType>()

        subject
            .assignOutput(to: \.optionalTest, on: self)
            .store(in: &cancellables)

        subject.send(completion: .failure(.one))

        XCTAssertNil(optionalTest)
    }

    func test_assigning_array_value_captures_success() {

        arrayTest = [55]

        let subject = PassthroughSubject<[Int], FirstErrorType>()

        subject
            .assignOutput(to: \.arrayTest, on: self)
            .store(in: &cancellables)

        subject.send([1,2,3])

        XCTAssertEqual(arrayTest, [1,2,3])
    }

    func test_assigning_array_value_captures_failure_as_empty_array() {

        arrayTest = [55]

        let subject = PassthroughSubject<[Int], FirstErrorType>()

        subject
            .assignOutput(to: \.arrayTest, on: self)
            .store(in: &cancellables)

        subject.send(completion: .failure(.one))

        XCTAssertEqual(arrayTest, [])
    }

    // MARK: - AMB

    func test_amb_chooses_first_publisher_with_successful_value() {

        let subject1 = PassthroughSubject<Int, FirstErrorType>()
        let subject2 = PassthroughSubject<Int, FirstErrorType>()
        let subject3 = PassthroughSubject<Int, FirstErrorType>()

        let amb1Expectation = self.expectation(description: "amb_1_expectation")
        amb1Expectation.expectedFulfillmentCount = 2

        Publishers.AMB([subject1, subject2, subject3])
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    amb1Expectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                amb1Expectation.fulfill()
            })
            .store(in: &cancellables)

        subject1.send(10)
        subject2.send(20)
        subject3.send(30)

        wait(for: [amb1Expectation], timeout: 1)

        let subject4 = PassthroughSubject<Int, FirstErrorType>()
        let subject5 = PassthroughSubject<Int, FirstErrorType>()
        let subject6 = PassthroughSubject<Int, FirstErrorType>()

        let amb2Expectation = self.expectation(description: "amb_2_expectation")
        amb2Expectation.expectedFulfillmentCount = 2

        Publishers.AMB([subject4, subject5, subject6])
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    amb2Expectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 20)
                amb2Expectation.fulfill()
            })
            .store(in: &cancellables)

        subject5.send(20)
        subject4.send(10)
        subject6.send(30)

        wait(for: [amb2Expectation], timeout: 1)

        let subject7 = PassthroughSubject<Int, FirstErrorType>()
        let subject8 = PassthroughSubject<Int, FirstErrorType>()
        let subject9 = PassthroughSubject<Int, FirstErrorType>()

        let amb3Expectation = self.expectation(description: "amb_3_expectation")
        amb3Expectation.expectedFulfillmentCount = 2

        Publishers.AMB([subject7, subject8, subject9])
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    amb3Expectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 30)
                amb3Expectation.fulfill()
            })
            .store(in: &cancellables)

        subject9.send(30)
        subject8.send(20)
        subject7.send(10)

        wait(for: [amb3Expectation], timeout: 1)
    }

    func test_amb_chooses_first_publisher_with_failure() {

        let subject1 = PassthroughSubject<Int, FirstErrorType>()
        let subject2 = PassthroughSubject<Int, FirstErrorType>()
        let subject3 = PassthroughSubject<Int, FirstErrorType>()

        let amb1Expectation = self.expectation(description: "amb_1_expectation")
        amb1Expectation.expectedFulfillmentCount = 1

        Publishers.AMB([subject1, subject2, subject3])
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTAssertEqual(error, .one)
                    amb1Expectation.fulfill()
                case .finished:
                    XCTFail("unexpected finished")
                }
            }, receiveValue: { value in
                XCTFail("Unexpected value: \(value)")
            })
            .store(in: &cancellables)

        subject1.send(completion: .failure(.one))
        subject2.send(completion: .failure(.two))
        subject3.send(completion: .failure(.two))

        wait(for: [amb1Expectation], timeout: 1)

        let subject4 = PassthroughSubject<Int, FirstErrorType>()
        let subject5 = PassthroughSubject<Int, FirstErrorType>()
        let subject6 = PassthroughSubject<Int, FirstErrorType>()

        let amb2Expectation = self.expectation(description: "amb_2_expectation")
        amb2Expectation.expectedFulfillmentCount = 1

        Publishers.AMB([subject4, subject5, subject6])
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTAssertEqual(error, .two)
                    amb2Expectation.fulfill()
                case .finished:
                    XCTFail("unexpected finished")
                }
            }, receiveValue: { value in
                XCTFail("Unexpected value: \(value)")
            })
            .store(in: &cancellables)

        subject5.send(completion: .failure(.two))
        subject4.send(completion: .failure(.one))
        subject6.send(completion: .failure(.one))

        wait(for: [amb2Expectation], timeout: 1)

        let amb3Expectation = self.expectation(description: "amb_3_expectation")
        amb3Expectation.expectedFulfillmentCount = 1

        let subject7 = PassthroughSubject<Int, FirstErrorType>()
        let subject8 = PassthroughSubject<Int, FirstErrorType>()
        let subject9 = PassthroughSubject<Int, FirstErrorType>()

        Publishers.AMB([subject7, subject8, subject9])
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTAssertEqual(error, .two)
                    amb3Expectation.fulfill()
                case .finished:
                    XCTFail("unexpected finished")
                }
            }, receiveValue: { value in
                XCTFail("Unexpected value: \(value)")
            })
            .store(in: &cancellables)

        subject9.send(completion: .failure(.two))
        subject8.send(completion: .failure(.one))
        subject7.send(completion: .failure(.one))

        wait(for: [amb3Expectation], timeout: 1)
    }

    func test_amb_allows_all_publishers_to_finish() {

        let subject1 = PassthroughSubject<Int, FirstErrorType>()
        let subject2 = PassthroughSubject<Int, FirstErrorType>()
        let subject3 = PassthroughSubject<Int, FirstErrorType>()

        let amb1Expectation = self.expectation(description: "amb_1_expectation")
        amb1Expectation.expectedFulfillmentCount = 5

        let valueCheck1 = subject1
            .map { value -> Int in
                XCTAssertEqual(value, 10)
                amb1Expectation.fulfill()
                return value
            }

        let valueCheck2 = subject2
            .map { value -> Int in
                XCTAssertEqual(value, 20)
                amb1Expectation.fulfill()
                return value
            }

        let valueCheck3 = subject3
            .map { value -> Int in
                XCTAssertEqual(value, 30)
                amb1Expectation.fulfill()
                return value
            }

        Publishers.AMB([valueCheck1, valueCheck2, valueCheck3])
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    amb1Expectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                amb1Expectation.fulfill()
            })
            .store(in: &cancellables)

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
            subject1.send(10)
            subject1.send(completion: .finished)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(20)) {
            subject2.send(20)
            subject2.send(completion: .finished)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(30)) {
            subject3.send(30)
            subject3.send(completion: .finished)
        }

        waitForExpectations(timeout: 1)
    }

    func test_amb_doesnt_allow_all_publishers_to_finish() {

        let subject1 = PassthroughSubject<Int, FirstErrorType>()
        let subject2 = PassthroughSubject<Int, FirstErrorType>()
        let subject3 = PassthroughSubject<Int, FirstErrorType>()

        let errorSubject2 = subject2
            .map { value -> Int in
                XCTFail("unexpected processing on subject 2")
                return value
            }
        let errorSubject3 = subject3
            .map { value -> Int in
                XCTFail("unexpected processing on subject 3")
                return value
            }

        let amb1Expectation = self.expectation(description: "amb_1_expectation")
        amb1Expectation.expectedFulfillmentCount = 3

        Publishers.AMB([subject1.eraseToAnyPublisher(), errorSubject2.eraseToAnyPublisher(), errorSubject3.eraseToAnyPublisher()], allowAllToFinish: false)
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    amb1Expectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                amb1Expectation.fulfill()
            })
            .store(in: &cancellables)

        subject1
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    XCTFail("unexpected finished")
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                amb1Expectation.fulfill()
            })
            .store(in: &cancellables)

        subject1.send(10)
        subject2.send(20)
        subject3.send(30)

        waitForExpectations(timeout: 1)
    }

    func test_cancelling_amb_cancels_publishers() {

        let subject1 = PassthroughSubject<Int, FirstErrorType>()
        let subject2 = PassthroughSubject<Int, FirstErrorType>()
        let subject3 = PassthroughSubject<Int, FirstErrorType>()

        let errorSubject1 = subject1
            .map { value -> Int in
                XCTFail("unexpected processing on subject 1")
                return value
            }
        let errorSubject2 = subject2
            .map { value -> Int in
                XCTFail("unexpected processing on subject 2")
                return value
            }
        let errorSubject3 = subject3
            .map { value -> Int in
                XCTFail("unexpected processing on subject 3")
                return value
            }

        var testCancellables = Set<AnyCancellable>()

        Publishers.AMB([errorSubject1, errorSubject2, errorSubject3], allowAllToFinish: true)
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    XCTFail("unexpected finished")
                }
            }, receiveValue: { value in
                XCTFail("Unexpected value: \(value)")
            })
            .store(in: &testCancellables)

        testCancellables.forEach { $0.cancel() }

        subject1.send(10)
        subject2.send(20)
        subject3.send(30)
    }

    // MARK: ReplayOnce

    func test_replay_once_passes_through_value_and_completion() {
        var valueEmitter: ((Int) -> Void)?

        let replayOnce = Publishers.ReplayOnce<Int, FirstErrorType> { promise in
            valueEmitter = { value in
                promise(.success(value))
            }
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        valueEmitter?(10)

        waitForExpectations(timeout: 1)
    }

    func test_replay_once_passes_through_value_and_completion_if_it_fires_before_subscriber() {

        var valueEmitter: ((Int) -> Void)?

        let replayOnce = Publishers.ReplayOnce<Int, FirstErrorType> { promise in
            valueEmitter = { value in
                promise(.success(value))
            }
        }

        valueEmitter?(10)

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_replay_once_passes_through_failure() {
        var failureEmitter: ((FirstErrorType) -> Void)?

        let replayOnce = Publishers.ReplayOnce<Int, FirstErrorType> { promise in
            failureEmitter = { error in
                promise(.failure(error))
            }
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 1

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTAssertEqual(error, .one)
                    replayExpectation.fulfill()
                case .finished:
                    XCTFail("unexpected finished")
                }
            }, receiveValue: { value in
                XCTFail("unexpected value: \(value)")
            })
            .store(in: &cancellables)

        failureEmitter?(.one)

        waitForExpectations(timeout: 1)
    }

    func test_replay_once_passes_through_failure_if_it_fires_before_subscriber() {

        var failureEmitter: ((FirstErrorType) -> Void)?

        let replayOnce = Publishers.ReplayOnce<Int, FirstErrorType> { promise in
            failureEmitter = { error in
                promise(.failure(error))
            }
        }

        failureEmitter?(.one)

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 1

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTAssertEqual(error, .one)
                    replayExpectation.fulfill()
                case .finished:
                    XCTFail("unexpected finished")
                }
            }, receiveValue: { value in
                XCTFail("unexpected value: \(value)")
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_replay_once_passes_through_value_and_completion_for_optional_data_returning_actual_value() {
        var valueEmitter: ((Int?) -> Void)?

        let replayOnce = Publishers.ReplayOnce<Int?, FirstErrorType> { promise in
            valueEmitter = { value in
                promise(.success(value))
            }
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        valueEmitter?(10)

        waitForExpectations(timeout: 1)
    }

    func test_replay_once_passes_through_value_and_completion_for_optional_data_returning_nil_value() {
        var valueEmitter: ((Int?) -> Void)?

        let replayOnce = Publishers.ReplayOnce<Int?, FirstErrorType> { promise in
            valueEmitter = { value in
                promise(.success(value))
            }
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertNil(value)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        valueEmitter?(nil)

        waitForExpectations(timeout: 1)
    }

    func test_replay_once_passes_through_value_and_completion_for_optional_data_returning_actual_value_if_it_fires_before_subscriber() {
        var valueEmitter: ((Int?) -> Void)?

        let replayOnce = Publishers.ReplayOnce<Int?, FirstErrorType> { promise in
            valueEmitter = { value in
                promise(.success(value))
            }
        }

        valueEmitter?(10)

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_replay_once_passes_through_value_and_completion_for_optional_data_returning_nil_value_if_it_fires_before_subscriber() {
        var valueEmitter: ((Int?) -> Void)?

        let replayOnce = Publishers.ReplayOnce<Int?, FirstErrorType> { promise in
            valueEmitter = { value in
                promise(.success(value))
            }
        }

        valueEmitter?(nil)

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertNil(value)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    // MARK: QueuedReplayOnce

    func test_queued_replay_once_passes_through_value_and_completion() {
        var valueEmitter: ((Int) -> Void)?

        let operationQueue = AsyncOperationQueue()
        let replayOnce = Publishers.QueuedReplayOnce<Int, FirstErrorType>(operationQueue) { promise, completion in
            valueEmitter = { value in
                promise(.success(value))
            }
            completion()
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        operationQueue.run(title: "emit_value") { completion in
            valueEmitter?(10)
            completion()
        }

        waitForExpectations(timeout: 1)
    }

    func test_queued_replay_once_passes_through_value_and_completion_if_it_fires_before_subscriber() {

        var valueEmitter: ((Int) -> Void)?

        let operationQueue = AsyncOperationQueue()
        let replayOnce = Publishers.QueuedReplayOnce<Int, FirstErrorType>(operationQueue) { promise, completion in
            valueEmitter = { value in
                promise(.success(value))
            }
            completion()
        }

        operationQueue.run(title: "emit_value") { completion in
            valueEmitter?(10)
            completion()
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_queued_replay_once_passes_through_failure() {
        var failureEmitter: ((FirstErrorType) -> Void)?

        let operationQueue = AsyncOperationQueue()
        let replayOnce = Publishers.QueuedReplayOnce<Int, FirstErrorType>(operationQueue) { promise, completion in
            failureEmitter = { error in
                promise(.failure(error))
            }
            completion()
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 1

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTAssertEqual(error, .one)
                    replayExpectation.fulfill()
                case .finished:
                    XCTFail("unexpected finished")
                }
            }, receiveValue: { value in
                XCTFail("unexpected value: \(value)")
            })
            .store(in: &cancellables)

        operationQueue.run(title: "emit_failure") { completion in
            failureEmitter?(.one)
            completion()
        }

        waitForExpectations(timeout: 1)
    }

    func test_queued_replay_once_passes_through_failure_if_it_fires_before_subscriber() {

        var failureEmitter: ((FirstErrorType) -> Void)?

        let operationQueue = AsyncOperationQueue()
        let replayOnce = Publishers.QueuedReplayOnce<Int, FirstErrorType>(operationQueue) { promise, completion in
            failureEmitter = { error in
                promise(.failure(error))
            }
            completion()
        }

        operationQueue.run(title: "emit_failure") { completion in
            failureEmitter?(.one)
            completion()
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 1

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTAssertEqual(error, .one)
                    replayExpectation.fulfill()
                case .finished:
                    XCTFail("unexpected finished")
                }
            }, receiveValue: { value in
                XCTFail("unexpected value: \(value)")
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_queued_replay_once_passes_through_value_and_completion_for_optional_data_returning_actual_value() {
        var valueEmitter: ((Int?) -> Void)?

        let operationQueue = AsyncOperationQueue()
        let replayOnce = Publishers.QueuedReplayOnce<Int?, FirstErrorType>(operationQueue) { promise, completion in
            valueEmitter = { value in
                promise(.success(value))
            }
            completion()
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        operationQueue.run(title: "emit_value") { completion in
            valueEmitter?(10)
            completion()
        }

        waitForExpectations(timeout: 1)
    }

    func test_queued_replay_once_passes_through_value_and_completion_for_optional_data_returning_nil_value() {
        var valueEmitter: ((Int?) -> Void)?

        let operationQueue = AsyncOperationQueue()
        let replayOnce = Publishers.QueuedReplayOnce<Int?, FirstErrorType>(operationQueue) { promise, completion in
            valueEmitter = { value in
                promise(.success(value))
            }
            completion()
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertNil(value)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        operationQueue.run(title: "emit_value") { completion in
            valueEmitter?(nil)
            completion()
        }

        waitForExpectations(timeout: 1)
    }

    func test_queued_replay_once_passes_through_value_and_completion_for_optional_data_returning_actual_value_if_it_fires_before_subscriber() {
        var valueEmitter: ((Int?) -> Void)?

        let operationQueue = AsyncOperationQueue()
        let replayOnce = Publishers.QueuedReplayOnce<Int?, FirstErrorType>(operationQueue) { promise, completion in
            valueEmitter = { value in
                promise(.success(value))
            }
            completion()
        }

        operationQueue.run(title: "emit_value") { completion in
            valueEmitter?(10)
            completion()
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertEqual(value, 10)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_queued_replay_once_passes_through_value_and_completion_for_optional_data_returning_nil_value_if_it_fires_before_subscriber() {
        var valueEmitter: ((Int?) -> Void)?

        let operationQueue = AsyncOperationQueue()
        let replayOnce = Publishers.QueuedReplayOnce<Int?, FirstErrorType>(operationQueue) { promise, completion in
            valueEmitter = { value in
                promise(.success(value))
            }
            completion()
        }

        operationQueue.run(title: "emit_value") { completion in
            valueEmitter?(nil)
            completion()
        }

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 2

        replayOnce
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                XCTAssertNil(value)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_queued_replay_once_performs_operations_in_order() {

        let testQueue = DispatchQueue(label: "test_queue")

        var completion1: (() -> Void)?
        var completion2: (() -> Void)?
        var completion3: (() -> Void)?

        let operationQueue = AsyncOperationQueue(dispatchQueue: testQueue)
        let replayOnce1 = Publishers.QueuedReplayOnce<Int?, FirstErrorType>(operationQueue) { promise, completion in
            promise(.success(5))
            completion1 = completion
        }

        let replayOnce2 = Publishers.QueuedReplayOnce<Int?, FirstErrorType>(operationQueue) { promise, completion in
            promise(.success(10))
            completion2 = completion
        }

        let replayOnce3 = Publishers.QueuedReplayOnce<Int?, FirstErrorType>(operationQueue) { promise, completion in
            promise(.success(15))
            completion3 = completion
        }

        let completionExpectation = self.expectation(description: "replay_expectation")

        let waitForQueues: (@escaping () -> Void) -> Void = { handler in
            testQueue.asyncAfter(deadline: .now() + .milliseconds(1)) {
                testQueue.asyncAfter(deadline: .now() + .milliseconds(1)) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1)) {
                        handler()
                    }
                }
            }
        }

        waitForQueues {
            XCTAssertNotNil(completion1)
            XCTAssertNil(completion2)
            XCTAssertNil(completion3)
            completion1?()

            waitForQueues {
                XCTAssertNotNil(completion2)
                XCTAssertNil(completion3)
                completion2?()

                waitForQueues {
                    XCTAssertNotNil(completion3)
                    completion3?()
                    completionExpectation.fulfill()
                }
            }
        }

        wait(for: [completionExpectation], timeout: 1)

        let replayExpectation = self.expectation(description: "replay_expectation")
        replayExpectation.expectedFulfillmentCount = 6

        var receivedValues: [Int?] = []

        replayOnce1
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                receivedValues.append(value)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        replayOnce2
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                receivedValues.append(value)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        replayOnce3
            .sink(receiveCompletion: { terminal in
                switch terminal {
                case .failure(let error):
                    XCTFail("unexpected failure: \(error)")
                case .finished:
                    replayExpectation.fulfill()
                }
            }, receiveValue: { value in
                receivedValues.append(value)
                replayExpectation.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [replayExpectation], timeout: 1)

        XCTAssertEqual(receivedValues, [5, 10, 15])
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
