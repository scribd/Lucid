//
//  RemoteStoreTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 12/10/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import XCTest

@testable import Lucid_ReactiveKit
@testable import LucidTestKit_ReactiveKit

final class RemoteStoreTests: XCTestCase {

    private var requestConfig: APIRequestConfig!

    private var clientSpy: APIClientSpy!

    private var clientQueueSpy: APIClientQueueSpy!

    private var stubEntities: [EntitySpy]!

    private var requestContext: ReadContext<EntitySpy>!

    private var derivedFromEntityTypeContext: ReadContext<EntitySpy>!

    private var store: RemoteStore<EntitySpy>!

    override func setUp() {
        super.setUp()

        Logger.shared = LoggerMock()

        requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity") / "42")

        stubEntities = [
            EntitySpy(identifier: EntitySpyIdentifier(value: .remote(42, nil)),
                      title: "fake_title",
                      subtitle: "fake_subtitle",
                      extra: .unrequested,
                      oneRelationship: EntityRelationshipSpyIdentifier(value: .remote(24, "24")),
                      manyRelationships: []
            ),
            EntitySpy(identifier: EntitySpyIdentifier(value: .remote(24, nil)),
                      title: "fake_title",
                      subtitle: "fake_subtitle",
                      extra: .unrequested,
                      oneRelationship: EntityRelationshipSpyIdentifier(value: .remote(42, "42")),
                      manyRelationships: []
            )
        ]

        requestContext = ReadContext<EntitySpy>(dataSource: .remoteOrLocal(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: stubEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        EntitySpy.stubEndpointData = EndpointStubData(stubEntities: stubEntities,
                                                      stubEntityMetadata: nil,
                                                      stubEndpointMetadata: nil)
        derivedFromEntityTypeContext = ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))

        clientSpy = APIClientSpy()
        clientQueueSpy = APIClientQueueSpy()
        store = RemoteStore(client: clientSpy, clientQueue: clientQueueSpy)
    }

    override func tearDown() {
        defer { super.tearDown() }

        requestContext = nil
        derivedFromEntityTypeContext = nil
        clientSpy = nil
        clientQueueSpy = nil
        store = nil

        EntitySpy.resetRecords()
    }

    private var payloadStubData: Data {
        return (try? JSONEncoder().encode(String())) ?? Data()
    }

    // MARK: - Endpoint.derivedFromEntityType

    // MARK: get(byID:in:completion:)

    func test_should_request_an_entity_from_the_client_using_endpoint_derived_from_entity_type() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation = self.expectation(description: "entity")
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let result):
                guard let entity = result.entity else {
                    XCTFail("Did not receive valid entity")
                    return
                }
                XCTAssertEqual(entity.identifier.value.remoteValue, 42)
                XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
                XCTAssertEqual(EntitySpy.remotePathRecords.first, .get(EntitySpyIdentifier(value: .remote(42, nil)), extras: nil))
                XCTAssertEqual(EntitySpy.endpointInvocationCount, 1)

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_gets_should_only_send_one_request_to_the_client_using_endpoint_derived_from_entity_type() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 1)
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.first?.wrapped.config, self.requestConfig)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_different_gets_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let requestConfig2 = APIRequestConfig(method: .get, path: .path("fake_entity") / "24")
        clientQueueSpy.responseStubs[requestConfig2] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(24, nil)), in: ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 24)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 2)
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.first?.wrapped.config, self.requestConfig)
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.last?.wrapped.config, requestConfig2)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_gets_in_two_different_contexts_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 2)
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.first?.wrapped.config, self.requestConfig)
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.last?.wrapped.config, self.requestConfig)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_fail_to_request_an_entity_from_the_client_using_endpoint_derived_from_entity_type() {

        Logger.shared = LoggerMock(shouldCauseFailures: false)

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.failure(.api(httpStatusCode: 400, errorPayload: nil))

        let expectation = self.expectation(description: "entity")
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .failure(.api(.api(httpStatusCode: 400, errorPayload: nil))):
                XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
                XCTAssertEqual(EntitySpy.remotePathRecords.first, .get(EntitySpyIdentifier(value: .remote(42, nil)), extras: nil))
                XCTAssertEqual(EntitySpy.endpointInvocationCount, 0)

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success:
                XCTFail("Unexpected success.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: set(_:in:completion:)

    func test_should_post_a_request_to_the_client_queue_using_endpoint_derived_from_entity_type() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation = self.expectation(description: "entity")
        let entity = EntitySpy(idValue: .remote(42, nil), title: "fake_title")

        store.set(entity, in: WriteContext(dataTarget: .localAndRemote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .some(.success(let entity)):
                XCTAssertNotEqual(self.store.level, .remote)
                XCTAssertEqual(entity.identifier.value.remoteValue, 42)
                XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
                XCTAssertEqual(EntitySpy.remotePathRecords.first, .set(.create(entity)))
                XCTAssertEqual(self.clientQueueSpy.appendInvocations.first?.wrapped.config.path, .path("fake_entity") / "42")
            case .some(.failure(let error)):
                XCTFail("Unexpected error: \(error)")
            case .none:
                XCTAssertEqual(self.store.level, .remote)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: remove(atID:in:completion:)

    func test_should_post_a_delete_request_to_the_client_queue_using_endpoint_derived_from_entity_type() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation = self.expectation(description: "entity")

        store.remove(atID: EntitySpyIdentifier(value: .remote(42, nil)), in: WriteContext(dataTarget: .localAndRemote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .some(.success):
                XCTAssertNotEqual(self.store.level, .remote)
                XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
                XCTAssertEqual(EntitySpy.remotePathRecords.first, .remove(EntitySpyIdentifier(value: .remote(42, nil))))
                XCTAssertEqual(self.clientQueueSpy.appendInvocations.first?.wrapped.config.path, .path("fake_entity") / "42")
            case .some(.failure(let error)):
                XCTFail("Unexpected error: \(error)")
            case .none:
                XCTAssertEqual(self.store.level, .remote)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: search(withQuery:in:completion:)

    func test_should_request_entities_from_the_client_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: .filter(.title == .string("fake_title")), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.entity?.identifier.value, .remote(24, nil))
                XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
                XCTAssertEqual(EntitySpy.remotePathRecords.first, .search(Query(filter: .title == .string("fake_title"))))
                XCTAssertEqual(EntitySpy.endpointInvocationCount, 1)

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_request_entities_from_the_client_and_order_them_by_id_asc_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let query = Query<EntitySpy>
            .filter(.title == .string("fake_title"))
            .order([.asc(by: .identifier)])

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: query, in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.first?.identifier.value.remoteValue, 24)
                XCTAssertEqual(entities.array.last?.identifier.value.remoteValue, 42)

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_request_entities_from_the_client_and_order_them_by_id_desc_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let query = Query<EntitySpy>
            .filter(.title == .string("fake_title"))
            .order([.desc(by: .identifier)])

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: query, in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.first?.identifier.value.remoteValue, 42)
                XCTAssertEqual(entities.array.last?.identifier.value.remoteValue, 24)

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_searches_should_only_send_one_request_to_the_client_by_inferring_the_same_api_request_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        store.search(withQuery: .filter(.title == .string("fake_title")), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        store.search(withQuery: .filter(.title == .string("fake_title")), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_searches_should_only_send_one_request_to_the_client_by_passing_in_the_request_token_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation1 = self.expectation(description: "search_1")
        let expectation2 = self.expectation(description: "search_2")

        store.search(withQuery: .filter(.title == .string("fake_title")), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let queryResult):
                XCTAssertEqual(queryResult.isEmpty, false)

                let query = Query<EntitySpy>(filter: .title == .string("fake_title"))
                self.store.search(withQuery: query, in: self.derivedFromEntityTypeContext) { result in
                    switch result {
                    case .success(let entities):
                        XCTAssertEqual(entities.isEmpty, false)
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                    expectation2.fulfill()
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation1.fulfill()
        }

        wait(for: [expectation1, expectation2], timeout: 1)
    }

    func test_two_searches_in_two_different_contexts_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        store.search(withQuery: .filter(.title == .string("fake_title")), in: ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        store.search(withQuery: .filter(.title == .string("fake_title")), in: ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 2)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_different_searches_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        store.search(withQuery: .filter(.title == .string("fake_title")), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        store.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(24, nil)))), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_setting_an_entity_should_flip_synchronized_flag_using_endpoint_derived_from_entity_type() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation = self.expectation(description: "entity")
        let entity = EntitySpy(idValue: .remote(42, nil), title: "fake_title")
        XCTAssertEqual(entity.identifier._remoteSynchronizationState.value, .outOfSync)

        store.set(entity, in: WriteContext(dataTarget: .localAndRemote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .some(.success(let entity)):
                XCTAssertEqual(entity.identifier._remoteSynchronizationState.value, .synced)
            case .some(.failure(let error)):
                XCTFail("Unexpected error: \(error)")
            case .none:
                XCTAssertEqual(self.store.level, .remote)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_fail_to_search_using_an_entity_from_the_client_when_query_contains_local_identifiers_using_endpoint_derived_from_entity_type() {

        Logger.shared = LoggerMock(shouldCauseFailures: false)

        let localIdentifier = EntitySpyIdentifier(value: .local("local_identifier"))
        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42"), query: [("object_id", localIdentifier.queryValue)]), resultPayload: .empty),
            persistenceStrategy: .doNotPersist
        ))

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: .filter(.identifier == .identifier(localIdentifier)), in: requestContext) { result in
            switch result {
            case .failure(.identifierNotSynced):
                break
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success:
                XCTFail("Unexpected success.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: - Endpoint.request

    // MARK: get(byID:in:completion:)

    func test_should_request_an_entity_from_the_client_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation = self.expectation(description: "entity")
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext) { result in
            switch result {
            case .success(let result):
                guard let entity = result.entity else {
                    XCTFail("Did not receive valid entity")
                    return
                }
                XCTAssertEqual(entity.identifier.value.remoteValue, 42)

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_gets_should_only_send_one_request_to_the_client_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_different_gets_should_send_two_requests_to_the_client_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let requestConfig2 = APIRequestConfig(method: .get, path: .path("fake_entity") / "24")
        clientQueueSpy.responseStubs[requestConfig2] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(24, nil)), in: requestContext) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 24)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_gets_in_two_different_contexts_should_send_two_requests_to_the_client_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        let requestContext1 = ReadContext<EntitySpy>(dataSource: .remoteOrLocal(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: stubEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext1) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let requestContext2 = ReadContext<EntitySpy>(dataSource: .remoteOrLocal(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: stubEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        dispatchGroup.enter()
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext2) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 2)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_fail_to_request_an_entity_from_the_client_using_request_endpoint() {

        Logger.shared = LoggerMock(shouldCauseFailures: false)

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.failure(.api(httpStatusCode: 400, errorPayload: nil))

        let expectation = self.expectation(description: "entity")
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext) { result in
            switch result {
            case .failure(.api(.api(httpStatusCode: 400, errorPayload: nil))):
                break
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success:
                XCTFail("Unexpected success.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_fail_to_get_an_entity_from_the_client_when_query_contains_local_identifiers_using_request_endpoint() {

        Logger.shared = LoggerMock(shouldCauseFailures: false)

        let localIdentifier = EntitySpyIdentifier(value: .local("local_identifier"))
        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42"), query: [("object_id", localIdentifier.queryValue)]), resultPayload: .empty),
            persistenceStrategy: .doNotPersist
        ))

        let expectation = self.expectation(description: "entity")
        store.get(byID: localIdentifier, in: requestContext) { result in
            switch result {
            case .failure(.identifierNotSynced):
                break
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success:
                XCTFail("Unexpected success.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: set(_:in:completion:)

    func test_should_post_a_request_to_the_client_queue_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation = self.expectation(description: "entity")
        let entity = EntitySpy(idValue: .remote(42, nil), title: "fake_title")

        let writeContext = WriteContext<EntitySpy>(dataTarget:
            .localAndRemote(endpoint: .request(requestConfig))
        )

        store.set(entity, in: writeContext) { result in
            switch result {
            case .some(.success(let entity)):
                XCTAssertNotEqual(self.store.level, .remote)
                XCTAssertEqual(entity.identifier.value.remoteValue, 42)
                XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
                XCTAssertEqual(EntitySpy.remotePathRecords.first, .set(.create(entity)))
                XCTAssertEqual(self.clientQueueSpy.appendInvocations.first?.wrapped.config.path, .path("fake_entity") / "42")
            case .some(.failure(let error)):
                XCTFail("Unexpected error: \(error)")
            case .none:
                XCTAssertEqual(self.store.level, .remote)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: remove(atID:in:completion:)

    func test_should_post_a_delete_request_to_the_client_queue_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation = self.expectation(description: "entity")

        let writeContext = WriteContext<EntitySpy>(dataTarget:
            .localAndRemote(endpoint: .request(requestConfig))
        )

        store.remove(atID: EntitySpyIdentifier(value: .remote(42, nil)), in: writeContext) { result in
            switch result {
            case .some(.success):
                XCTAssertNotEqual(self.store.level, .remote)
                XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
                XCTAssertEqual(EntitySpy.remotePathRecords.first, .remove(EntitySpyIdentifier(value: .remote(42, nil))))
                XCTAssertEqual(self.clientQueueSpy.appendInvocations.first?.wrapped.config.path, .path("fake_entity") / "42")
            case .some(.failure(let error)):
                XCTFail("Unexpected error: \(error)")
            case .none:
                XCTAssertEqual(self.store.level, .remote)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: search(withQuery:in:completion:)

    func test_should_request_entities_from_the_client_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.entity?.identifier.value, .remote(24, nil))

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_request_entities_from_the_client_and_order_them_by_id_asc_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let query = Query<EntitySpy>
            .filter(.title == .string("fake_title"))
            .order([.asc(by: .identifier)])

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: query, in: requestContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.first?.identifier.value.remoteValue, 24)
                XCTAssertEqual(entities.array.last?.identifier.value.remoteValue, 42)

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_request_entities_from_the_client_and_order_them_by_id_desc_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let query = Query<EntitySpy>
            .filter(.title == .string("fake_title"))
            .order([.desc(by: .identifier)])

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: query, in: requestContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.first?.identifier.value.remoteValue, 42)
                XCTAssertEqual(entities.array.last?.identifier.value.remoteValue, 24)

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_searches_should_only_send_one_request_to_the_client_by_inferring_the_same_api_request_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_searches_should_only_send_one_request_to_the_client_by_passing_in_the_request_token_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation1 = self.expectation(description: "search_1")
        let expectation2 = self.expectation(description: "search_2")

        store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext) { result in
            switch result {
            case .success(let queryResult):
                XCTAssertEqual(queryResult.isEmpty, false)

                let query = Query<EntitySpy>(filter: .title == .string("fake_title"))
                self.store.search(withQuery: query, in: self.requestContext) { result in
                    switch result {
                    case .success(let entities):
                        XCTAssertEqual(entities.isEmpty, false)
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                    expectation2.fulfill()
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation1.fulfill()
        }

        wait(for: [expectation1, expectation2], timeout: 1)
    }

    func test_two_searches_in_two_different_contexts_should_send_two_requests_to_the_client_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        let requestContext1 = ReadContext<EntitySpy>(dataSource: .remoteOrLocal(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: stubEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        dispatchGroup.enter()
        store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext1) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let requestContext2 = ReadContext<EntitySpy>(dataSource: .remoteOrLocal(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: stubEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        dispatchGroup.enter()
        store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext2) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 2)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_different_searches_should_send_two_requests_to_the_client_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        store.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(24, nil)))), in: requestContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            dispatchGroup.leave()
        }

        let expectation = self.expectation(description: "entity")
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(self.clientQueueSpy.appendInvocations.count, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_setting_an_entity_should_flip_synchronized_flag_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let expectation = self.expectation(description: "entity")
        let entity = EntitySpy(idValue: .remote(42, nil), title: "fake_title")
        XCTAssertEqual(entity.identifier._remoteSynchronizationState.value, .outOfSync)

        store.set(entity, in: WriteContext(dataTarget: .localAndRemote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .some(.success(let entity)):
                XCTAssertEqual(entity.identifier._remoteSynchronizationState.value, .synced)
            case .some(.failure(let error)):
                XCTFail("Unexpected error: \(error)")
            case .none:
                XCTAssertEqual(self.store.level, .remote)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_fail_to_search_for_an_entity_from_the_client_when_query_contains_local_identifiers_using_request_endpoint() {

        Logger.shared = LoggerMock(shouldCauseFailures: false)

        let localIdentifier = EntitySpyIdentifier(value: .local("local_identifier"))
        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42"), query: [("object_id", localIdentifier.queryValue)]), resultPayload: .empty),
            persistenceStrategy: .doNotPersist
        ))

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: .filter(.identifier == .identifier(localIdentifier)), in: requestContext) { result in
            switch result {
            case .failure(.identifierNotSynced):
                break
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success:
                XCTFail("Unexpected success.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: search(withQuery:in:completion:) with root entities in metadata and trustRemoteFiltering flag

    func test_should_request_entities_from_the_client_and_not_filter_if_there_are_no_root_entities_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let allEntities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: allEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: .all, in: requestContext) { result in
            switch result {
            case .success(let result):
                let entities = result.array
                guard entities.count == 3 else {
                    XCTFail("Incorrect number of entities. Expected 3 but found \(entities.count)")
                    return
                }
                XCTAssertEqual(entities[0].identifier.value, .remote(1, nil))
                XCTAssertEqual(entities[1].identifier.value, .remote(2, nil))
                XCTAssertEqual(entities[2].identifier.value, .remote(3, nil))

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_request_entities_from_the_client_and_filter_for_root_entities_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let allEntities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }
        let rootEntities = (1...2).map { EntitySpyMetadata(remoteID: $0) }

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: allEntities,
                                                               stubEntityMetadata: rootEntities,
                                                               stubEndpointMetadata: nil)))
        )

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: .all, in: requestContext) { result in
            switch result {
            case .success(let result):
                let entities = result.array
                guard entities.count == 2 else {
                    XCTFail("Incorrect number of entities. Expected 2 but found \(entities.count)")
                    return
                }
                XCTAssertEqual(entities[0].identifier.value, .remote(1, nil))
                XCTAssertEqual(entities[1].identifier.value, .remote(2, nil))

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_request_entities_from_the_client_and_filter_on_query_when_trust_remote_filtering_is_false_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let allEntities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: allEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)),
            trustRemoteFiltering: false)
        )

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(1, nil)))), in: requestContext) { result in
            switch result {
            case .success(let result):
                let entities = result.array
                guard entities.count == 1 else {
                    XCTFail("Incorrect number of entities. Expected 1 but found \(entities.count)")
                    return
                }
                XCTAssertEqual(entities[0].identifier.value, .remote(1, nil))

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_request_entities_from_the_client_and_not_filter_on_query_when_trust_remote_filtering_is_true_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let allEntities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: allEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)),
            trustRemoteFiltering: true)
        )

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(1, nil)))), in: requestContext) { result in
            switch result {
            case .success(let result):
                let entities = result.array
                guard entities.count == 3 else {
                    XCTFail("Incorrect number of entities. Expected 3 but found \(entities.count)")
                    return
                }
                XCTAssertEqual(entities[0].identifier.value, .remote(1, nil))
                XCTAssertEqual(entities[1].identifier.value, .remote(2, nil))
                XCTAssertEqual(entities[2].identifier.value, .remote(3, nil))

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_request_entities_from_the_client_and_filter_on_query_when_trust_remote_filtering_is_true_but_response_is_from_cache_using_request_endpoint() {

        clientQueueSpy.responseStubs[requestConfig] = APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))

        let allEntities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }
        let rootEntities = (1...2).map { EntitySpyMetadata(remoteID: $0) }

        let config = APIRequestConfig(method: .get, path: .component("fake_entity"))
        let endpointData = EndpointStubData(stubEntities: allEntities,
                                            stubEntityMetadata: rootEntities,
                                            stubEndpointMetadata: nil)

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(config,
                               resultPayload: endpointData),
            trustRemoteFiltering: true)
        )

        let payloadResult = EntityEndpointResultPayloadSpy(stubEntities: allEntities,
                                                           stubEntityMetadata: rootEntities,
                                                           stubEndpointMetadata: nil)

        requestContext.set(payloadResult: .success(payloadResult),
                    source: .server(.empty),
                    for: config)

        let expectation = self.expectation(description: "entity")
        store.search(withQuery: .all, in: requestContext) { result in
            switch result {
            case .success(let result):
                let entities = result.array
                guard entities.count == 3 else {
                    XCTFail("Incorrect number of entities. Expected 3 but found \(entities.count)")
                    return
                }
                XCTAssertEqual(entities[0].identifier.value, .remote(1, nil))
                XCTAssertEqual(entities[1].identifier.value, .remote(2, nil))
                XCTAssertEqual(entities[2].identifier.value, .remote(3, nil))

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}
