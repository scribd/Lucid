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

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery<EntitySpy>(rootEntities: (once: .entity(EntitySpy()), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                                          in: _ReadContext(),
                                          relationshipManager: coreManager)

        query
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

    func test_relationship_controller_should_insert_root_entities_in_graph_async() async {
        let entity = EntitySpy()
        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery<EntitySpy>(rootEntities: (once: .entity(entity), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                                          in: _ReadContext(),
                                          relationshipManager: coreManager)

        do {
            let graph = try await query.perform(GraphStub.self).once
            XCTAssertEqual(graph.entitySpies.count, 1)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_relationship_controller_should_continuously_send_events_when_first_event_comes_from_continuous_signal() {

        coreManager.getByIDsStubs = [
            Publishers.ReplayOnce(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))]),
            Publishers.ReplayOnce(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let noCompletionExpectation = self.expectation(description: "no_completion")
        noCompletionExpectation.isInverted = true

        var streamContinuation: AsyncStream<QueryResult<EntitySpy>>.Continuation?
        let continuous = AsyncStream<QueryResult<EntitySpy>>() { continuation in
            streamContinuation = continuation
        }

        RelationshipController.RelationshipQuery(
            rootEntities: (once: QueryResult.empty(), continuous: continuous),
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
        streamContinuation?.yield(result)
        streamContinuation?.yield(result)

        waitForExpectations(timeout: 0.5)
    }

    func test_relationship_controller_should_continuously_send_events_when_first_event_comes_from_continuous_signal_async() async {

        coreManager.getByIDsAsyncStubs = [
            1: AnyEntitySpy.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ]

        let expectation = self.expectation(description: "continuous stream")
        expectation.expectedFulfillmentCount = 1

        var streamContinuation: AsyncStream<QueryResult<EntitySpy>>.Continuation?
        let stream = AsyncStream<QueryResult<EntitySpy>>() { continuation in
            streamContinuation = continuation
        }

        let result = QueryResult(data: .entitiesArray([EntitySpy()]))

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>.RelationshipQuery(
            rootEntities: (once: result, continuous: stream),
            in: _ReadContext(),
            relationshipManager: coreManager
        )

        do {
            let stream = try await query.includingAllRelationships(recursive: .none).perform(GraphStub.self).continuous

            Task {
                var callCount = 0
                for await graph in stream {
                    XCTAssertEqual(graph.entitySpies.count, 1)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
                    expectation.fulfill()

                    callCount += 1

                    if callCount == expectation.expectedFulfillmentCount {
                        return
                    }
                }
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        streamContinuation?.yield(result)
        streamContinuation?.yield(result)

        await fulfillment(of: [expectation], timeout: 0.5)
    }

    func test_relationship_controller_should_continuously_send_events_when_first_event_comes_from_once_signal() {

        coreManager.getByIDsStubs = [
            Publishers.ReplayOnce(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))]),
            Publishers.ReplayOnce(just: [.entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 4

        let noCompletionExpectation = self.expectation(description: "no_completion")
        noCompletionExpectation.isInverted = true

        let result = QueryResult(data: .entitiesArray([EntitySpy()]))

        var streamContinuation: AsyncStream<QueryResult<EntitySpy>>.Continuation?
        let continuous = AsyncStream<QueryResult<EntitySpy>>() { continuation in
            streamContinuation = continuation
        }

        let signals = RelationshipController.RelationshipQuery(
            rootEntities: (once: result, continuous: continuous),
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

        streamContinuation?.yield(result)
        streamContinuation?.yield(result)

        waitForExpectations(timeout: 0.2)
    }

    func test_relationship_controller_should_continuously_send_events_when_first_event_comes_from_once_signal_async() async {
        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ]

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let result = QueryResult(data: .entitiesArray([EntitySpy()]))

        var streamContinuation: AsyncStream<QueryResult<EntitySpy>>.Continuation?
        let continuous = AsyncStream<QueryResult<EntitySpy>>() { continuation in
            streamContinuation = continuation
        }

        let query =  RelationshipController<RelationshipCoreManagerSpy, GraphStub>.RelationshipQuery(
            rootEntities: (once: result, continuous: continuous),
            in: _ReadContext(),
            relationshipManager: coreManager
        )
        
        do {
            let queryResult = try await query
                .includingAllRelationships(recursive: .none)
                .perform(GraphStub.self)

            let graph = queryResult.once

            XCTAssertEqual(graph.entitySpies.count, 1)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 1)

            Task {
                var callCount = 0
                for await graph in queryResult.continuous {
                    defer { callCount += 1 }

                    XCTAssertEqual(graph.entitySpies.count, 1)
                    XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
                    expectation.fulfill()

                    if callCount == expectation.expectedFulfillmentCount {
                        return
                    }
                }
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        streamContinuation?.yield(result)
        streamContinuation?.yield(result)

        await fulfillment(of: [expectation], timeout: 0.5)
    }

    func test_relationship_controller_should_insert_one_relationship_entity_in_graph() {

        coreManager.getByIDsStubs = [Publishers.ReplayOnce(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(EntitySpy()), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        query
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

    func test_relationship_controller_should_insert_one_relationship_entity_in_graph_async() async {

        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ]

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(EntitySpy()), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        do {
            let graph = try await query.includingAllRelationships(recursive: .none).perform(GraphStub.self).once

            XCTAssertEqual(graph.entitySpies.count, 1)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_relationship_controller_should_insert_many_relationship_entities_in_graph() {

        coreManager.getByIDsStubs = [
            Publishers.ReplayOnce(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2"))
            ]),
            Publishers.ReplayOnce(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3"))
            ])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let entity = EntitySpy(
            oneRelationshipIdValue: .remote(1, nil),
            manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]
        )

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(entity), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)
        query
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

    func test_relationship_controller_should_insert_many_relationship_entities_in_graph_async() async {

        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
            2: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
            3: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3"))
        ]

        let entity = EntitySpy(
            oneRelationshipIdValue: .remote(1, nil),
            manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]
        )

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(entity), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        do {
            let graph = try await query.includingAllRelationships(recursive: .none).perform(GraphStub.self).once

            XCTAssertEqual(graph.entitySpies.count, 1)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 3)

            let spyIdentifiers = graph.entitySpies.keys.compactMap { $0.value.remoteValue }
            XCTAssertTrue(spyIdentifiers.contains(1))

            let relationshipSpyIdentifiers = graph.entityRelationshipSpies.keys.compactMap { $0.value.remoteValue }
            XCTAssertTrue(relationshipSpyIdentifiers.contains(1))
            XCTAssertTrue(relationshipSpyIdentifiers.contains(2))
            XCTAssertTrue(relationshipSpyIdentifiers.contains(3))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_relationship_controller_should_insert_many_root_entities_with_many_relationship_entities_in_graph() {

        coreManager.getByIDsStubs = [
            Publishers.ReplayOnce(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3"))
            ]),
            Publishers.ReplayOnce(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
            ])
        ].map { $0.eraseToAnyPublisher() }

        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ]

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)
        query
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

    func test_relationship_controller_should_insert_many_root_entities_with_many_relationship_entities_in_graph_async() async {

        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
            2: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
            3: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3")),
            4: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
            5: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
        ]

        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ]

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        do {
            let graph = try await query.includingAllRelationships(recursive: .none).perform(GraphStub.self).once

            XCTAssertEqual(graph.entitySpies.count, 2)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 5)

            XCTAssertEqual(self.coreManager.getByIDsAsyncInvocations.count, 2)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_relationship_controller_should_use_fetcher_before_inserting_in_graph() {

        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ]

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 3

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)
        query
            .with(
                fetcher: .fetcher { path, _, graph in
                    expectation.fulfill()
                    XCTAssertEqual(path.first, .entitySpy(.manyRelationships))

                    let fetch: () async throws -> Void = {
                        await graph.insert([
                            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
                            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
                            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3")),
                            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
                            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
                        ])
                    }

                    return .custom(fetch)
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

    func test_relationship_controller_should_use_fetcher_before_inserting_in_graph_async() async {

        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ]

        let expectation = self.expectation(description: "graph")

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        do {
            let graph = try await query
                .with(
                    fetcher: .fetcher { path, _, graph in
                        expectation.fulfill()
                        XCTAssertEqual(path.first, .entitySpy(.manyRelationships))

                        let customFetch: () async throws -> Void = {
                            await graph.insert([
                                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
                                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
                                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3")),
                                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
                                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
                            ])
                        }

                        return .custom(customFetch)
                    },
                    forPath: [.entitySpy(.manyRelationships)]
                )
                .perform(GraphStub.self)
                .once

            XCTAssertEqual(graph.entitySpies.count, 2)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 5)

            XCTAssertEqual(self.coreManager.getByIDsInvocations.count, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 2)
    }

    func test_relationship_controller_should_use_filter_before_inserting_in_graph() {

        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)])
        ]

        coreManager.getByIDsStubs = [Publishers.ReplayOnce(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 3

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)
        query
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

    func test_relationship_controller_should_use_filter_before_inserting_in_graph_async() async {
        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)])
        ]

        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
            2: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_1"))
        ]

        let expectation = self.expectation(description: "graph")

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        do {
            let graph = try await query
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

            XCTAssertEqual(graph.entitySpies.count, 2)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 1)

            XCTAssertEqual(self.coreManager.getByIDsAsyncInvocations.count, 1)
            XCTAssertEqual(self.coreManager.getByIDsAsyncInvocations.first?.identifiers.count, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_relationship_controller_should_ignore_relationship_with_fetcher() {

        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ]

        coreManager.getByIDsStubs = [Publishers.ReplayOnce(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 3

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        query
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

    func test_relationship_controller_should_ignore_relationship_with_fetcher_async() async {
        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ]

        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ]

        let expectation = self.expectation(description: "graph")

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        do {
            let graph = try await query
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

            XCTAssertEqual(graph.entitySpies.count, 2)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 0)

            XCTAssertEqual(self.coreManager.getByIDsAsyncInvocations.count, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_relationship_controller_should_exclude_relationship_type() {

        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ]

        coreManager.getByIDsStubs = [Publishers.ReplayOnce(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        query
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

    func test_relationship_controller_should_exclude_relationship_type_async() async {
        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ]

        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ]

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        do {
            let graph = try await query
                .excluding(path: [.entityRelationshipSpy(.relationships)])
                .perform(GraphStub.self)
                .once

            XCTAssertEqual(graph.entitySpies.count, 2)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 0)

            XCTAssertEqual(self.coreManager.getByIDsAsyncInvocations.count, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_relationship_controller_should_include_all_relationships() {

        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ]

        coreManager.getByIDsStubs = [
            Publishers.ReplayOnce(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3"))
            ]),
            Publishers.ReplayOnce(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
                .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
            ])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        query
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
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_include_all_relationships_async() async {
        let entities = [
            EntitySpy(idValue: .remote(1, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(2, nil), .remote(3, nil)]),
            EntitySpy(idValue: .remote(2, nil),
                      oneRelationshipIdValue: .remote(1, nil),
                      manyRelationshipsIdValues: [.remote(4, nil), .remote(5, nil)]),
        ]

        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
            2: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
            3: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3")),
            4: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
            5: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
        ]

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entities(entities), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        do {
            let graph = try await  query
                .includingAllRelationships(recursive: .none)
                .perform(GraphStub.self)
                .once

            XCTAssertEqual(graph.entitySpies.count, 2)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 5)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_relationship_controller_should_include_all_relationships_recursively() {

        let entity = EntitySpy(idValue: .remote(1, nil), oneRelationshipIdValue: .remote(1, nil))

        coreManager.getByIDsStubs = [
            Publishers.ReplayOnce(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(1, nil),
                title: "fake_relationship_1",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(2, nil))]
            ))]),
            Publishers.ReplayOnce(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(2, nil),
                title: "fake_relationship_2",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(3, nil))]
            ))]),
            Publishers.ReplayOnce(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(3, nil),
                title: "fake_relationship_3",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(4, nil))]
            ))]),
            Publishers.ReplayOnce(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(4, nil),
                title: "fake_relationship_4",
                relationships: [EntityRelationshipSpyIdentifier(value: .remote(5, nil))]
            ))]),
            Publishers.ReplayOnce(just: [.entityRelationshipSpy(EntityRelationshipSpy(
                idValue: .remote(5, nil),
                title: "fake_relationship_5"
            ))])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(entity), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        query
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

                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_include_all_relationships_recursively_async() async {

        let entity = EntitySpy(
            idValue: .remote(1, nil),
            oneRelationshipIdValue: .remote(1, nil)
        )

        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
            2: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2")),
            3: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(3, nil), title: "fake_relationship_3")),
            4: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(4, nil), title: "fake_relationship_4")),
            5: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(5, nil), title: "fake_relationship_5"))
        ]

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(entity), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        do {
            let graph = try await query
                .includingAllRelationships(recursive: .full)
                .perform(GraphStub.self)
                .once

            XCTAssertEqual(graph.entitySpies.count, 1)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_relationship_controller_should_include_all_relationships_recursively_and_avoid_cycles() {

        let entity = EntitySpy(idValue: .remote(1, nil),
                               oneRelationshipIdValue: .remote(1, nil),
                               manyRelationshipsIdValues: [.remote(2, nil)])

        coreManager.getByIDsStubs = [
            Publishers.ReplayOnce(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(
                    idValue: .remote(1, nil),
                    title: "fake_relationship_1",
                    relationships: [EntityRelationshipSpyIdentifier(value: .remote(2, nil))]
                ))
            ]),
            Publishers.ReplayOnce(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(
                    idValue: .remote(2, nil),
                    title: "fake_relationship_2",
                    relationships: [EntityRelationshipSpyIdentifier(value: .remote(1, nil))]
                ))
            ]),
            Publishers.ReplayOnce(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(
                    idValue: .remote(1, nil),
                    title: "fake_relationship_1",
                    relationships: [EntityRelationshipSpyIdentifier(value: .remote(2, nil))]
                ))
            ]),
            Publishers.ReplayOnce(just: [
                .entityRelationshipSpy(EntityRelationshipSpy(
                    idValue: .remote(2, nil),
                    title: "fake_relationship_2",
                    relationships: [EntityRelationshipSpyIdentifier(value: .remote(1, nil))]
                ))
            ])
        ].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(entity), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        query
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
                expectation.fulfill()
            })
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_include_all_relationships_recursively_and_avoid_cycles_async() async {

        let entity = EntitySpy(idValue: .remote(1, nil),
                               oneRelationshipIdValue: .remote(1, nil),
                               manyRelationshipsIdValues: [.remote(2, nil)])

        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1")),
            2: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(2, nil), title: "fake_relationship_2"))
        ]

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(entity), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: _ReadContext(),
                               relationshipManager: coreManager)

        do {
            let graph = try await query
                .includingAllRelationships(recursive: .full)
                .perform(GraphStub.self)
                .once

            XCTAssertEqual(graph.entitySpies.count, 1)
            XCTAssertEqual(graph.entityRelationshipSpies.count, 2)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: Contracts

    func test_relationship_controller_should_pass_down_relationship_contract_to_relationship_calls() {

        coreManager.getByIDsStubs = [Publishers.ReplayOnce(just: [
            .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ])].map { $0.eraseToAnyPublisher() }

        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let contract = RootControllerContract(isValid: false)
        let context = RelationshipController<RelationshipCoreManagerSpy, GraphStub>.ReadContext(dataSource: .local, contract: contract)

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(EntitySpy()), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: context,
                               relationshipManager: coreManager)

        query
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

    func test_relationship_controller_should_pass_down_relationship_contract_to_relationship_calls_async() async {

        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ]

        let contract = RootControllerContract(isValid: false)
        let context = RelationshipController<RelationshipCoreManagerSpy, GraphStub>.ReadContext(dataSource: .local, contract: contract)

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(EntitySpy()), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: context,
                               relationshipManager: coreManager)

        do {
            _ = try await query
                .includingAllRelationships(recursive: .full)
                .perform(GraphStub.self)
                .once

            XCTAssertEqual(self.coreManager.getByIDsAsyncInvocations.count, 1)
            guard let relationshipContract = self.coreManager.getByIDsAsyncInvocations.first?.context.contract as? RelationshipControllerContract<GraphStub> else {
                XCTFail("Received unexpected contract type.")
                return
            }
            XCTAssertEqual(relationshipContract.path, [.entitySpy(.oneRelationship)])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: Identifying Local vs Remote Data

    func _testRelationshipControllerShouldIdentifyDataSource(asRemote: Bool, responseSource: RemoteResponseSource?) {

        let entitySpy = EntitySpy(idValue: .remote(1, nil),
                                  remoteSynchronizationState: .synced,
                                  title: "test",
                                  oneRelationshipIdValue: .remote(1, nil),
                                  manyRelationshipsIdValues: [])

        coreManager.getByIDsStubs = [Publishers.ReplayOnce(just: [
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

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(entitySpy), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: context,
                               relationshipManager: coreManager)

        query
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

    func _testRelationshipControllerShouldIdentifyDataSourceAsync(asRemote: Bool, responseSource: RemoteResponseSource?) async {

        let entitySpy = EntitySpy(idValue: .remote(1, nil),
                                  remoteSynchronizationState: .synced,
                                  title: "test",
                                  oneRelationshipIdValue: .remote(1, nil),
                                  manyRelationshipsIdValues: [])

        coreManager.getByIDsAsyncStubs = [
            1: .entityRelationshipSpy(EntityRelationshipSpy(idValue: .remote(1, nil), title: "fake_relationship_1"))
        ]

        let context = RelationshipController<RelationshipCoreManagerSpy, GraphStub>.ReadContext(dataSource: .local)
        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity") / "42")

        let payloadResult = EntityEndpointResultPayloadSpy(stubEntities: [entitySpy],
                                                           stubEntityMetadata: nil,
                                                           stubEndpointMetadata: nil)

        context.set(payloadResult: .success(payloadResult),
                    source: responseSource,
                    for: requestConfig)

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(entitySpy), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: context,
                               relationshipManager: coreManager)

        do {
            let graph = try await query
                .includingAllRelationships(recursive: .full)
                .perform(GraphStub.self)
                .once

            XCTAssertEqual(self.coreManager.getByIDsAsyncInvocations.count, 1)
            XCTAssertEqual(graph.isDataRemote, asRemote)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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

    func test_relationship_controller_should_create_graph_and_identify_local_data_from_context_async() async {
        await _testRelationshipControllerShouldIdentifyDataSourceAsync(asRemote: false, responseSource: nil)
    }

    func test_relationship_controller_should_create_graph_and_identify_remote_data_from_context_with_server_response_async() async {
        await _testRelationshipControllerShouldIdentifyDataSourceAsync(asRemote: true, responseSource: .server(.empty))
    }

    func test_relationship_controller_should_create_graph_and_identify_remote_data_from_context_with_url_cache_response_async() async {
        await _testRelationshipControllerShouldIdentifyDataSourceAsync(asRemote: true, responseSource: .urlCache(.empty))
    }

    // MARK: - Metadata Handling -

    func test_relationship_controller_should_add_metadata_to_graph() {
        let expectation = self.expectation(description: "graph")
        expectation.expectedFulfillmentCount = 2

        let entitySpy = EntitySpy()

        let contract = RootControllerContract(isValid: false)
        let context = RelationshipController<RelationshipCoreManagerSpy, GraphStub>.ReadContext(dataSource: .local, contract: contract)
        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity") / "42")
        let stubEntityMetadata = EntitySpyMetadata(remoteID: 42)
        let stubEndpointMetadata = VoidMetadata()
        let resultPayload = EntityEndpointResultPayloadSpy(stubEntities: [entitySpy],
                                                           stubEntityMetadata: [stubEntityMetadata],
                                                           stubEndpointMetadata: stubEndpointMetadata)
        context.set(payloadResult: .success(resultPayload), source: nil, for: requestConfig)

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(entitySpy), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: context,
                               relationshipManager: coreManager)

        query
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
                XCTAssertTrue(graph._metadata != nil)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        waitForExpectations(timeout: 1)
    }

    func test_relationship_controller_should_add_metadata_to_graph_async() async {
        let entitySpy = EntitySpy()

        let contract = RootControllerContract(isValid: false)
        let context = RelationshipController<RelationshipCoreManagerSpy, GraphStub>.ReadContext(dataSource: .local, contract: contract)
        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity") / "42")
        let stubEntityMetadata = EntitySpyMetadata(remoteID: 42)
        let stubEndpointMetadata = VoidMetadata()
        let resultPayload = EntityEndpointResultPayloadSpy(stubEntities: [entitySpy],
                                                           stubEntityMetadata: [stubEntityMetadata],
                                                           stubEndpointMetadata: stubEndpointMetadata)
        context.set(payloadResult: .success(resultPayload), source: nil, for: requestConfig)

        let query = RelationshipController<RelationshipCoreManagerSpy, GraphStub>
            .RelationshipQuery(rootEntities: (once: .entity(entitySpy), continuous: AsyncStream<QueryResult<EntitySpy>>() { _ in }),
                               in: context,
                               relationshipManager: coreManager)

        do {
            let graph = try await query.perform(GraphStub.self).once

            XCTAssertTrue(graph._metadata != nil)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Utils

private extension RelationshipControllerTests {

    func entities<E>(_ entities: [E]) -> AnyPublisher<QueryResult<E>, ManagerError> where E: Entity {
        return Publishers.ReplayOnce { fulfill in
            fulfill(.success(QueryResult(data: .entitiesArray(entities))))
        }.eraseToAnyPublisher()
    }

    func entity<E>(_ entity: E) -> AnyPublisher<QueryResult<E>, ManagerError> where E: Entity {
        return entities([entity])
    }

    func emptyPublishers() -> (once: AnyPublisher<QueryResult<EntitySpy>, ManagerError>, continuous: AnySafePublisher<QueryResult<EntitySpy>>) {
        return (
            once: PassthroughSubject().eraseToAnyPublisher(),
            continuous: PassthroughSubject().eraseToAnyPublisher()
        )
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
