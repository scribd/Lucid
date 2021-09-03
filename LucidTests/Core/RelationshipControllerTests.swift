//
//  RelationshipControllerTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 2/4/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import XCTest
import Combine

@testable import Lucid
@testable import LucidTestKit

final class RelationshipControllerTests: XCTestCase {

    private var coreManager: RelationshipCoreManagerSpy!

    private var relationshipController: RelationshipController<RelationshipCoreManagerSpy, GraphStub>!

    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()

        cancellables = Set()
        coreManager = RelationshipCoreManagerSpy()
    }

    override func tearDown() {
        defer { super.tearDown() }

        coreManager = nil
        relationshipController = nil
        cancellables = nil
    }

    func test_relationship_controller_should_insert_root_entities_in_graph() {

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        entity(EntitySpy())
            .relationships(from: coreManager)
            .perform(GraphStub.self)
            .once
            .sink { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            } receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 1)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 0)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_continuously_send_events_when_first_event_comes_from_continuous_signal() {

        coreManager.getByIDsStubs = [
            Future(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))]),
            Future(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let noCompletionExpectation = self.expectation(description: "no_completion")
        noCompletionExpectation.isInverted = true

        let onceSubject = PassthroughSubject<QueryResult<EntitySpy>, ManagerError>()
        let continuousSubject = PassthroughSubject<QueryResult<EntitySpy>, Never>()

        RelationshipController.RelationshipQuery(
            rootEntities: (once: onceSubject.eraseToAnyPublisher(), continuous: continuousSubject.eraseToAnyPublisher()),
            in: _ReadContext(),
            relationshipManager: coreManager
        )
            .includingAllRelationships(recursive: .none)
            .perform(GraphStub.self)
            .continuous
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    noCompletionExpectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 1)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        let result = QueryResult(data: .entitiesArray([EntitySpy()]))
        continuousSubject.send(result)
        continuousSubject.send(result)

        waitForExpectations(timeout: 0.5)
    }

    func test_relationship_controller_should_continuously_send_events_when_first_event_comes_from_once_signal() {

        coreManager.getByIDsStubs = [
            Future(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))]),
            Future(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 4

        let noCompletionExpectation = self.expectation(description: "no_completion")
        noCompletionExpectation.isInverted = true

        let onceSubject = PassthroughSubject<QueryResult<EntitySpy>, ManagerError>()
        let continuousSubject = PassthroughSubject<QueryResult<EntitySpy>, Never>()

        let signals = RelationshipController.RelationshipQuery(
            rootEntities: (once: onceSubject.eraseToAnyPublisher(), continuous: continuousSubject.eraseToAnyPublisher()),
            in: _ReadContext(),
            relationshipManager: coreManager
        )
            .includingAllRelationships(recursive: .none)
            .perform(GraphStub.self)

        signals.once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 1)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        signals.continuous
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    noCompletionExpectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 1)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        let result = QueryResult(data: .entitiesArray([EntitySpy()]))

        onceSubject.send(result)
        onceSubject.send(completion: .finished)
        continuousSubject.send(result)
        continuousSubject.send(result)

        waitForExpectations(timeout: 0.2)
    }

    func test_relationship_controller_should_insert_one_relationship_entity_in_graph() {

        coreManager.getByIDsStubs = [Future(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        entity(EntitySpy())
            .relationships(from: coreManager)
            .includingAllRelationships(recursive: .none)
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 1)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_insert_many_relationship_entities_in_graph() {

        coreManager.getByIDsStubs = [
            Future(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2"))
            ]),
            Future(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3"))
            ])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        entity(EntitySpy(
            oneRelationshipIdValue: .remote(1, nil),
            manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]
        ))
            .relationships(from: coreManager)
            .includingAllRelationships(recursive: .none)
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 1)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 3)

                XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 2)
                XCTAssertEqual(self.coreManager.getByIDsInvocations.first?.identifiers.count, 2)
                XCTAssertEqual(self.coreManager.getByIDsInvocations.last?.identifiers.count, 1)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_insert_many_root_entities_with_many_relationship_entities_in_graph() {

        coreManager.getByIDsStubs = [
            Future(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3"))
            ]),
            Future(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
            ])
        ].map { $0.eraseToAnyPublisher() }

        let entities = self.entities([
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ])

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        entities
            .relationships(from: coreManager)
            .includingAllRelationships(recursive: .none)
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 2)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 5)

                XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 2)
                XCTAssertEqual(self.coreManager.getByIDsInvocations.first?.identifiers.count, 4)
                XCTAssertEqual(self.coreManager.getByIDsInvocations.last?.identifiers.count, 2)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_use_fetcher_before_inserting_in_graph() {

        let entities = self.entities([
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ])

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 3

        entities
            .relationships(from: coreManager)
            .with(
                fetcher: .fetcher { path, _, graph in
                    expectation.fulfill()
                    XCTAssertEqual(path.first, .entitySpy(.manyRelationships))

                    graph.insert([
                        .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
                        .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
                        .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3")),
                        .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
                        .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
                    ])

                    return .custom(Future(just: ()).eraseToAnyPublisher())
                },
                forPath: [.entitySpy(.manyRelationships)]
            )
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 2)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 5)

                XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 0)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_use_filter_before_inserting_in_graph() {

        let entities = self.entities([
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)])
        ])

        coreManager.getByIDsStubs = [Future(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 3

        entities
            .relationships(from: coreManager)
            .with(
                fetcher: .fetcher { path, ids, _ in
                    expectation.fulfill()
                    XCTAssertEqual(path.first, .entitySpy(.manyRelationships))
                    return .filtered(ids.filter {
                        guard let id: EntityRelationshipSpyIdentifier = $0.toRelationshipID() else { return false }
                        return id.value.remoteValue == 2
                    }.any, recursive: .none, context: nil)
                },
                forPath: [.entitySpy(.manyRelationships)]
            )
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 2)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 1)

                XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 1)
                XCTAssertEqual(self.coreManager.getByIDsInvocations.first?.identifiers.count, 1)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_ignore_relationship_with_fetcher() {

        let entities = self.entities([
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ])

        coreManager.getByIDsStubs = [Future(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 3

        entities
            .relationships(from: coreManager)
            .with(
                fetcher: .fetcher { path, _, _ in
                    expectation.fulfill()
                    XCTAssertEqual(path.first, .entitySpy(.manyRelationships))
                    return .none
                },
                forPath: [.entitySpy(.manyRelationships)]
            )
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 2)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 0)

                XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 0)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_exclude_relationship_type() {

        let entities = self.entities([
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ])

        coreManager.getByIDsStubs = [Future(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        entities
            .relationships(from: coreManager)
            .excluding(path: [.entityRelationshipSpy(.relationships)])
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 2)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 0)

                XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 0)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_include_all_relationships() {

        let entities = self.entities([
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ])

        coreManager.getByIDsStubs = [
            Future(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3"))
            ]),
            Future(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
            ])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        entities
            .relationships(from: coreManager)
            .includingAllRelationships(recursive: .none)
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 2)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 5)

                XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 2)
                XCTAssertEqual(self.coreManager.getByIDsInvocations.first?.identifiers.count, 4)
                XCTAssertEqual(self.coreManager.getByIDsInvocations.last?.identifiers.count, 2)

                let givenIDs: [EntityRelationshipSpyIdentifier] = self.coreManager
                    .getByIDsInvocations
                    .flatMap { $0.identifiers }
                    .compactMap { $0.toRelationshipID() }

                XCTAssertEqual(givenIDs.compactMap { $0.value.remoteValue }, [2, 3, 4, 5, 1, 1])
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_include_all_relationships_recursively() {

        let entity = self.entity(EntitySpy(idValue: .remote(1, nil),
                                           oneRelationshipIdValue: .remote(1, nil)))

        coreManager.getByIDsStubs = [
            Future(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(1, nil),
                title: "fake_relationship_1",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(2, nil))]
            ))]),
            Future(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(2, nil),
                title: "fake_relationship_2",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(3, nil))]
            ))]),
            Future(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(3, nil),
                title: "fake_relationship_3",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(4, nil))]
            ))]),
            Future(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(4, nil),
                title: "fake_relationship_4",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(5, nil))]
            ))]),
            Future(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(5, nil),
                title: "fake_relationship_5"
            ))])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        entity
            .relationships(from: coreManager)
            .includingAllRelationships(recursive: .full)
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 1)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 5)

                XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 5)

                let givenIDs: [EntityRelationshipSpyIdentifier] = self
                    .coreManager
                    .getByIDsInvocations
                    .flatMap { $0.identifiers }
                    .compactMap { $0.toRelationshipID() }

                XCTAssertEqual(givenIDs.compactMap { $0.value.remoteValue }, [1, 2, 3, 4, 5])

                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_include_all_relationships_recursively_and_avoid_cycles() {

        let entity = self.entity(EntitySpy(idValue: .remote(1, nil),
                                           oneRelationshipIdValue: .remote(1, nil),
                                           manyRelationshipsIdValues: [.remote(2, nil)]))

        coreManager.getByIDsStubs = [
            Future(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(
                    idValue: .remote(1, nil),
                    title: "fake_relationship_1",
                    relationships: [EntityRelationshipSpyIdentifier(value: .remote(2, nil))]
                ))
            ]),
            Future(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(
                    idValue: .remote(2, nil),
                    title: "fake_relationship_2",
                    relationships: [EntityRelationshipSpyIdentifier(value: .remote(1, nil))]
                ))
            ]),
            Future(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(
                    idValue: .remote(1, nil),
                    title: "fake_relationship_1",
                    relationships: [EntityRelationshipSpyIdentifier(value: .remote(2, nil))]
                ))
            ]),
            Future(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(
                    idValue: .remote(2, nil),
                    title: "fake_relationship_2",
                    relationships: [EntityRelationshipSpyIdentifier(value: .remote(1, nil))]
                ))
            ])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        entity
            .relationships(from: coreManager)
            .includingAllRelationships(recursive: .full)
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(graph.entitySpies.count, 1)
                XCTAssertEqual(graph.entityRelationshipSpies.count, 2)

                XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 4)
                XCTAssertEqual(self.coreManager.getByIDsInvocations.first?.identifiers.count, 1)
                XCTAssertEqual(self.coreManager.getByIDsInvocations.last?.identifiers.count, 1)

                let givenIDs: [EntityRelationshipSpyIdentifier] = self.coreManager
                    .getByIDsInvocations
                    .flatMap { $0.identifiers }
                    .compactMap { $0.toRelationshipID() }

                XCTAssertEqual(givenIDs.compactMap { $0.value.remoteValue }, [2, 1, 2, 2])
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    // MARK: Contracts

    func test_relationship_controller_should_pass_down_relationship_contract_to_relationship_calls() {

        coreManager.getByIDsStubs = [Future(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let contract = RootControllerContract(isValid: false)
        let context = RelationshipController<RelationshipCoreManagerSpy, GraphStub>.ReadContext(dataSource: .local, contract: contract)

        entity(EntitySpy())
            .relationships(from: coreManager, in: context)
            .includingAllRelationships(recursive: .full)
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 1)
                guard let relationshipContract = self.coreManager.getByIDsInvocations.first?.context.contract as? RelationshipControllerContract<GraphStub> else {
                    XCTFail("Received unexpected contract type.")
                    return
                }
                XCTAssertEqual(relationshipContract.path, [.entitySpy(.oneRelationship)])
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    // MARK: Identifying Local vs Remote Data

    func _testRelationshipControllerShouldIdentifyDataSource(asRemote: Bool, responseSource: RemoteResponseSource?) {

        let entitySpy = EntitySpy(idValue: .remote(1, nil),
                                  remoteSynchronizationState: .synced,
                                  title: "test",
                                  oneRelationshipIdValue: .remote(1, nil),
                                  manyRelationshipsIdValues: [])

        coreManager.getByIDsStubs = [Future(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let context = RelationshipController<RelationshipCoreManagerSpy, GraphStub>.ReadContext(dataSource: .local)
        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity") / "42")

        let payloadResult = EntityEndpointResultPayloadSpy(stubEntities: [entitySpy],
                                                           stubEntityMetadata: nil,
                                                           stubEndpointMetadata: nil)

        context.set(payloadResult: .success(payloadResult),
                    source: responseSource,
                    for: requestConfig)

        entity(entitySpy)
            .relationships(from: coreManager, in: context)
            .includingAllRelationships(recursive: .full)
            .perform(GraphStub.self)
            .once
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    expectation.fulfill()
                }
            }, receiveValue: { graph in
                XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 1)
                XCTAssertEqual(graph.isDataRemote, asRemote)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_create_graph_and_identify_local_data_from_context() {
        _testRelationshipControllerShouldIdentifyDataSource(asRemote: false, responseSource: nil)
    }

    func test_relationship_controller_should_create_graph_and_identify_remote_data_from_context_with_server_response() {
        _testRelationshipControllerShouldIdentifyDataSource(asRemote: true, responseSource: .server(.empty))
    }

    func test_relationship_controller_should_create_graph_and_identify_remote_data_from_context_with_url_cache_response() {
        _testRelationshipControllerShouldIdentifyDataSource(asRemote: true, responseSource: .urlCache(.empty))
    }
}

// MARK: - Utils

private extension RelationshipControllerTests {

    func entities<E>(_ entities: [E]) -> AnyPublisher<QueryResult<E>, ManagerError> where E: Entity {
        return Future { fulfill in
            fulfill(.success(QueryResult(data: .entitiesArray(entities))))
        }.eraseToAnyPublisher()
    }

    func entity<E>(_ entity: E) -> AnyPublisher<QueryResult<E>, ManagerError> where E: Entity {
        return entities([entity])
    }
}

// MARK: - Contract Helpers

private struct RootControllerContract: EntityGraphContract {

    let isValid: Bool

    func shouldValidate<E>(_ entityType: E.Type) -> Bool where E : Entity {
        return true
    }

    func isEntityValid<E>(_ entity: E, for query: Query<E>) -> Bool where E : Entity {
        return isValid
    }

    func contract<Graph>(at path: [Graph.AnyEntity.IndexName], for graph: Graph) -> EntityGraphContract where Graph: MutableGraph {
        return RelationshipControllerContract<Graph>(path: path, isValid: isValid)
    }
}

private struct RelationshipControllerContract<Graph>: EntityGraphContract where Graph: MutableGraph {

    let path: [Graph.AnyEntity.IndexName]

    let isValid: Bool

    func shouldValidate<E>(_ entityType: E.Type) -> Bool where E : Entity {
        return true
    }

    func isEntityValid<E>(_ entity: E, for query: Query<E>) -> Bool where E : Entity {
        return isValid
    }

    func contract<Graph>(at path: [Graph.AnyEntity.IndexName], for graph: Graph) -> EntityGraphContract where Graph: MutableGraph {
        return self
    }
}
