//
//  RelationshipControllerTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 2/4/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import ReactiveKit
import XCTest

@testable import Lucid
@testable import LucidTestKit

final class RelationshipControllerTests: XCTestCase {
    
    private var coreManager: RelationshipCoreManagerSpy!
    
    private var relationshipController: RelationshipController<RelationshipCoreManagerSpy, GraphStub>!
        
    override func setUp() {
        super.setUp()
        
        coreManager = RelationshipCoreManagerSpy()
    }
    
    override func tearDown() {
        defer { super.tearDown() }
        
        coreManager = nil
        relationshipController = nil
    }
    
    func test_relationship_controller_should_insert_root_entities_in_graph() {

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        entity(EntitySpy())
            .relationships(from: coreManager)
            .perform(GraphStub.self)
            .once
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 1)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 0)
                    expectation.fulfill()
                case .completed:
                    expectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
            .dispose(in: bag)
        
        waitForExpectations(timeout: 1)
    }
    
    func test_relationship_controller_should_continuously_send_events_when_first_event_comes_from_continuous_signal() {

        coreManager.getByIDsStubs = [
            Signal(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))]),
            Signal(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))])
        ]

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2
        
        let noCompletionExpectation = self.expectation(description: "no_completion")
        noCompletionExpectation.isInverted = true
        
        let onceSubject = PassthroughSubject<QueryResult<EntitySpy>, ManagerError>()
        let continuousSubject = PassthroughSubject<QueryResult<EntitySpy>, Never>()
        
        RelationshipController.RelationshipQuery(
            rootEntities: (once: onceSubject.toSignal(), continuous: continuousSubject.toSignal()),
            in: _ReadContext(),
            relationshipManager: coreManager
        )
            .includingAllRelationships(recursive: .none)
            .perform(GraphStub.self)
            .continuous
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 1)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
                    expectation.fulfill()
                case .completed:
                    noCompletionExpectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
            .dispose(in: bag)
        
        let result = QueryResult(data: .entitiesArray([EntitySpy()]))
        continuousSubject.send(result)
        continuousSubject.send(result)

        waitForExpectations(timeout: 0.5)
    }
    
    func test_relationship_controller_should_continuously_send_events_when_first_event_comes_from_once_signal() {

        coreManager.getByIDsStubs = [
            Signal(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))]),
            Signal(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))])
        ]

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 4
        
        let noCompletionExpectation = self.expectation(description: "no_completion")
        noCompletionExpectation.isInverted = true
        
        let onceSubject = PassthroughSubject<QueryResult<EntitySpy>, ManagerError>()
        let continuousSubject = PassthroughSubject<QueryResult<EntitySpy>, Never>()
        
        let signals = RelationshipController.RelationshipQuery(
            rootEntities: (once: onceSubject.toSignal(), continuous: continuousSubject.toSignal()),
            in: _ReadContext(),
            relationshipManager: coreManager
        )
            .includingAllRelationships(recursive: .none)
            .perform(GraphStub.self)
        
        signals.once
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 1)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
                    expectation.fulfill()
                case .completed:
                    expectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
            .dispose(in: bag)
        
        signals.continuous
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 1)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
                    expectation.fulfill()
                case .completed:
                    noCompletionExpectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
            .dispose(in: bag)
        
        let result = QueryResult(data: .entitiesArray([EntitySpy()]))
        
        onceSubject.send(lastElement: result)
        continuousSubject.send(result)
        continuousSubject.send(result)

        waitForExpectations(timeout: 0.2)
    }
    
    func test_relationship_controller_should_insert_one_relationship_entity_in_graph() {

        coreManager.getByIDsStubs = [Signal(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])]

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2
        
        entity(EntitySpy())
            .relationships(from: coreManager)
            .includingAllRelationships(recursive: .none)
            .perform(GraphStub.self)
            .once
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 1)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
                    expectation.fulfill()
                case .completed:
                    expectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }.dispose(in: bag)
        
        waitForExpectations(timeout: 1)
    }
    
    func test_relationship_controller_should_insert_many_relationship_entities_in_graph() {

        coreManager.getByIDsStubs = [Signal(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3"))
        ])]

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2
        
        entity(EntitySpy(oneRelationshipIdValue: .remote(1, nil),
                         manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]))
            .relationships(from: coreManager)
            .includingAllRelationships(recursive: .none)
            .perform(GraphStub.self)
            .once
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 1)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 3)
                    
                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.count, 1)
                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.first?.identifiers.count, 3)
                    expectation.fulfill()
                case .completed:
                    expectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }.dispose(in: bag)
        
        waitForExpectations(timeout: 1)
    }
    
    func test_relationship_controller_should_insert_many_root_entities_with_many_relationship_entities_in_graph() {

        coreManager.getByIDsStubs = [Signal(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3")),
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
        ])]
        
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
            .observe { event in
                    switch event {
                    case .next(let graph):
                        XCTAssertEqual(graph.entitySpies.count, 2)
                        XCTAssertEqual(graph.entityRelationshipSpies.count, 5)
                        
                        XCTAssertEqual(self.coreManager.getByIDsInstanciations.count, 1)
                        XCTAssertEqual(self.coreManager.getByIDsInstanciations.first?.identifiers.count, 6)
                        expectation.fulfill()
                    case .completed:
                        expectation.fulfill()
                    case .failed(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
            }.dispose(in: bag)
        
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
                    XCTAssertEqual(path.first, "entity_relationship_spy")

                    graph.insert([
                        .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
                        .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
                        .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3")),
                        .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
                        .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
                    ])
                    
                    return .custom(Signal(just: ()))
                },
                forPath: EntityRelationshipSpy.self
            )
            .perform(GraphStub.self)
            .once
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 2)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 5)
                    
                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.count, 0)
                    expectation.fulfill()
                case .completed:
                    expectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }.dispose(in: bag)
        
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

        coreManager.getByIDsStubs = [Signal(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])]
        
        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 3

        entities
            .relationships(from: coreManager)
            .with(
                fetcher: .fetcher { path, ids, _ in
                    expectation.fulfill()
                    XCTAssertEqual(path.first, "entity_relationship_spy")
                    return .filtered(ids.filter {
                        guard let id: EntityRelationshipSpyIdentifier = $0.toRelationshipID() else { return false }
                        return id.value.remoteValue == 2
                    }.any, recursive: .none, context: nil)
                },
                forPath: EntityRelationshipSpy.self
            )
            .perform(GraphStub.self)
            .once
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 2)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
                    
                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.count, 1)
                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.first?.identifiers.count, 1)
                    expectation.fulfill()
                case .completed:
                    expectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }.dispose(in: bag)
        
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

        coreManager.getByIDsStubs = [Signal(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])]
        
        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 3
        
        entities
            .relationships(from: coreManager)
            .with(
                fetcher: .fetcher { path, _, _ in
                    expectation.fulfill()
                    XCTAssertEqual(path.first, "entity_relationship_spy")
                    return .none
                },
                forPath: EntityRelationshipSpy.self
            )
            .perform(GraphStub.self)
            .once
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 2)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 0)
                    
                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.count, 0)
                    expectation.fulfill()
                case .completed:
                    expectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }.dispose(in: bag)
        
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

        coreManager.getByIDsStubs = [Signal(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])]
        
        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        entities
            .relationships(from: coreManager)
            .excluding(path: EntityRelationshipSpy.self)
            .perform(GraphStub.self)
            .once
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 2)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 0)
                    
                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.count, 0)
                    expectation.fulfill()
                case .completed:
                    expectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }.dispose(in: bag)
        
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

        coreManager.getByIDsStubs = [Signal(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3")),
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
        ])]
        
        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2
        
        entities
            .relationships(from: coreManager)
            .includingAllRelationships(recursive: .none)
            .perform(GraphStub.self)
            .once
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 2)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 5)

                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.count, 1)
                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.first?.identifiers.count, 6)
                    
                    let givenIDs: [EntityRelationshipSpyIdentifier] = self.coreManager
                        .getByIDsInstanciations
                        .first?
                        .identifiers
                        .compactMap { $0.toRelationshipID() } ?? []
                    
                    XCTAssertEqual(givenIDs.compactMap { $0.value.remoteValue }, [1, 2, 3, 1, 4, 5])
                    expectation.fulfill()
                case .completed:
                    expectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }.dispose(in: bag)
        
        waitForExpectations(timeout: 1)
    }
    
    func test_relationship_controller_should_include_all_relationships_recursively() {

        let entity = self.entity(EntitySpy(idValue: .remote(1, nil),
                                           oneRelationshipIdValue: .remote(1, nil)))

        coreManager.getByIDsStubs = [
            Signal(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(1, nil),
                title: "fake_relationship_1",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(2, nil))]
            ))]),
            Signal(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(2, nil),
                title: "fake_relationship_2",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(3, nil))]
            ))]),
            Signal(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(3, nil),
                title: "fake_relationship_3",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(4, nil))]
            ))]),
            Signal(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(4, nil),
                title: "fake_relationship_4",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(5, nil))]
            ))]),
            Signal(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(5, nil),
                title: "fake_relationship_5"
            ))])
        ]
        
        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2
        
        entity
            .relationships(from: coreManager)
            .includingAllRelationships(recursive: .full)
            .perform(GraphStub.self)
            .once
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 1)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 5)

                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.count, 5)
                    
                    let givenIDs: [EntityRelationshipSpyIdentifier] = self
                        .coreManager
                        .getByIDsInstanciations
                        .flatMap { $0.identifiers }
                        .compactMap { $0.toRelationshipID() }
                    
                    XCTAssertEqual(givenIDs.compactMap { $0.value.remoteValue }, [1, 2, 3, 4, 5])
                    
                    expectation.fulfill()
                case .completed:
                    expectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }.dispose(in: bag)
        
        waitForExpectations(timeout: 1)
    }
    
    func test_relationship_controller_should_include_all_relationships_recursively_and_avoid_cycles() {

        let entity = self.entity(EntitySpy(idValue: .remote(1, nil),
                                           oneRelationshipIdValue: .remote(1, nil),
                                           manyRelationshipsIdValues: [.remote(2, nil)]))

        coreManager.getByIDsStubs = [Signal(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(1, nil),
                title: "fake_relationship_1",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(2, nil))]
            )),
            .entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(2, nil),
                title: "fake_relationship_2",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(1, nil))]
            ))
        ])]
        
        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2
        
        entity
            .relationships(from: coreManager)
            .includingAllRelationships(recursive: .full)
            .perform(GraphStub.self)
            .once
            .observe { event in
                switch event {
                case .next(let graph):
                    XCTAssertEqual(graph.entitySpies.count, 1)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 2)

                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.count, 1)
                    XCTAssertEqual(self.coreManager.getByIDsInstanciations.first?.identifiers.count, 2)
                    
                    let givenIDs: [EntityRelationshipSpyIdentifier] = self.coreManager
                        .getByIDsInstanciations
                        .first?
                        .identifiers
                        .compactMap { $0.toRelationshipID() } ?? []
                    
                    XCTAssertEqual(givenIDs.compactMap { $0.value.remoteValue }, [1, 2])
                    expectation.fulfill()
                case .completed:
                    expectation.fulfill()
                case .failed(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }.dispose(in: bag)
        
        waitForExpectations(timeout: 1)
    }
}

// MARK: - Utils

private extension RelationshipControllerTests {
    
    func entities<E>(_ entities: [E]) -> Signal<QueryResult<E>, ManagerError> where E: Entity {
        return Signal<QueryResult<E>, ManagerError>(just: QueryResult(data: .entitiesArray(entities)))
    }
    
    func entity<E>(_ entity: E) -> Signal<QueryResult<E>, ManagerError> where E: Entity {
        return entities([entity])
    }
}
