//
//  RemoteStoreTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 12/10/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import XCTest

@testable import Lucid
@testable import LucidTestKit

final class RemoteStoreTests: XCTestCase {

    private var requestConfig: APIRequestConfig!

    private var clientQueueSpy: APIClientQueueSpy!

    private var stubEntities: [EntitySpy]!

    private var requestContext: ReadContext<EntitySpy>!

    private var derivedFromEntityTypeContext: ReadContext<EntitySpy>!

    private var store: RemoteStore<EntitySpy>!

    override func setUp() {
        super.setUp()

        LucidConfiguration.logger = LoggerMock()

        requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity") / "42")

        stubEntities = [
            EntitySpy(identifier: EntitySpyIdentifier(value: .remote(42, nil)),
                      title: "fake_title",
                      subtitle: "fake_subtitle",
                      lazy: .unrequested,
                      oneRelationship: EntityRelationshipSpyIdentifier(value: .remote(24, "24")),
                      manyRelationships: []
            ),
            EntitySpy(identifier: EntitySpyIdentifier(value: .remote(24, nil)),
                      title: "fake_title",
                      subtitle: "fake_subtitle",
                      lazy: .unrequested,
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

        clientQueueSpy = APIClientQueueSpy()
        store = RemoteStore(clientQueue: clientQueueSpy)
    }

    override func tearDown() {
        defer { super.tearDown() }

        requestContext = nil
        derivedFromEntityTypeContext = nil
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

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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
                XCTAssertEqual(EntitySpy.remotePathRecords.first, .get(EntitySpyIdentifier(value: .remote(42, nil))))
                XCTAssertEqual(EntitySpy.endpointInvocationCount, 1)

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_request_an_entity_from_the_client_using_endpoint_derived_from_entity_type_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: derivedFromEntityTypeContext)
        switch result {
        case .success(let result):
            guard let entity = result.entity else {
                XCTFail("Did not receive valid entity")
                return
            }
            XCTAssertEqual(entity.identifier.value.remoteValue, 42)
            XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
            XCTAssertEqual(EntitySpy.remotePathRecords.first, .get(EntitySpyIdentifier(value: .remote(42, nil))))
            XCTAssertEqual(EntitySpy.endpointInvocationCount, 1)

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_two_gets_should_only_send_one_request_to_the_client_using_endpoint_derived_from_entity_type() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")

        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)

                self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.derivedFromEntityTypeContext) { result in
                    switch result {
                    case .success(let result):
                        XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 1)

        let appendExpectation = self.expectation(description: "append_invocations")

        Task {
            let appendInvocations = await self.clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.count, 1)
            XCTAssertEqual(appendInvocations.first?.wrapped.config, self.requestConfig)
            appendExpectation.fulfill()
        }

        wait(for: [appendExpectation], timeout: 1)
    }

    func test_two_gets_should_only_send_one_request_to_the_client_using_endpoint_derived_from_entity_type_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.derivedFromEntityTypeContext)
        switch result {
        case .success(let result):
            XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)

            let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.derivedFromEntityTypeContext)
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }

        let appendInvocations = await clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 1)
        XCTAssertEqual(appendInvocations.first?.wrapped.config, self.requestConfig)
    }

    func test_two_different_gets_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type() {

        let requestConfig2 = APIRequestConfig(method: .get, path: .path("fake_entity") / "24")
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [
            requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false)),
            requestConfig2: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))
        ]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")

        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)

                self.store.get(byID: EntitySpyIdentifier(value: .remote(24, nil)), in: ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))) { result in
                    switch result {
                    case .success(let result):
                        XCTAssertEqual(result.entity?.identifier.value.remoteValue, 24)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 1)

        let appendExpectation = self.expectation(description: "append_invocations")

        Task {
            let appendInvocations = await self.clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.count, 2)
            XCTAssertEqual(appendInvocations.first?.wrapped.config, self.requestConfig)
            XCTAssertEqual(appendInvocations.last?.wrapped.config, requestConfig2)
            appendExpectation.fulfill()
        }

        wait(for: [appendExpectation], timeout: 1)
    }

    func test_two_different_gets_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type_async() async {

        let requestConfig2 = APIRequestConfig(method: .get, path: .path("fake_entity") / "24")
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [
            requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false)),
            requestConfig2: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))
        ]
        await clientQueueSpy.setResponseStubs(responseStub)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let context = ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))
                let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: context)
                switch result {
                case .success(let result):
                    XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }

            group.addTask {
                let context = ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))
                let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(24, nil)), in: context)
                switch result {
                case .success(let result):
                    XCTAssertEqual(result.entity?.identifier.value.remoteValue, 24)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }

        let appendInvocations = await clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 2)
        let configInvocations = appendInvocations.map { $0.wrapped.config }
        XCTAssertTrue(configInvocations.contains(self.requestConfig))
        XCTAssertTrue(configInvocations.contains(requestConfig2))
    }

    func test_two_gets_in_two_different_contexts_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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
            Task {
                let appendInvocations = await self.clientQueueSpy.appendInvocations
                XCTAssertEqual(appendInvocations.count, 2)
                XCTAssertEqual(appendInvocations.first?.wrapped.config, self.requestConfig)
                XCTAssertEqual(appendInvocations.last?.wrapped.config, self.requestConfig)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_gets_in_two_different_contexts_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let context = ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))
                let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: context)
                switch result {
                case .success(let result):
                    XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }

            group.addTask {
                let context = ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))
                let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: context)
                switch result {
                case .success(let result):
                    XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }

        let appendInvocations = await clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 2)
        XCTAssertEqual(appendInvocations.first?.wrapped.config, self.requestConfig)
        XCTAssertEqual(appendInvocations.last?.wrapped.config, self.requestConfig)
    }

    func test_should_fail_to_request_an_entity_from_the_client_using_endpoint_derived_from_entity_type() {

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [
            requestConfig: APIClientQueueResult<Data, APIError>.failure(.api(httpStatusCode: 400, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)))
        ]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .failure(.api(.api(httpStatusCode: 400, errorPayload: nil, _))):
                XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
                XCTAssertEqual(EntitySpy.remotePathRecords.first, .get(EntitySpyIdentifier(value: .remote(42, nil))))
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

    func test_should_fail_to_request_an_entity_from_the_client_using_endpoint_derived_from_entity_type_async() async {

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [
            requestConfig: APIClientQueueResult<Data, APIError>.failure(.api(httpStatusCode: 400, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)))
        ]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: derivedFromEntityTypeContext)
        switch result {
        case .failure(.api(.api(httpStatusCode: 400, errorPayload: nil, _))):
            XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
            XCTAssertEqual(EntitySpy.remotePathRecords.first, .get(EntitySpyIdentifier(value: .remote(42, nil))))
            XCTAssertEqual(EntitySpy.endpointInvocationCount, 0)

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        case .success:
            XCTFail("Unexpected success.")
        }
    }

    // MARK: set(_:in:completion:)

    func test_should_post_a_request_to_the_client_queue_using_endpoint_derived_from_entity_type() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")
        let entity = EntitySpy(idValue: .remote(42, nil), title: "fake_title")

        store.set(entity, in: WriteContext(dataTarget: .localAndRemote(endpoint: .derivedFromEntityType))) { result in
            Task {
                switch result {
                case .some(.success(let entity)):
                    XCTAssertNotEqual(self.store.level, .remote)
                    XCTAssertEqual(entity.identifier.value.remoteValue, 42)
                    XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
                    XCTAssertEqual(EntitySpy.remotePathRecords.first, .set(.create(entity)))
                    let appendInvocations = await self.clientQueueSpy.appendInvocations
                    XCTAssertEqual(appendInvocations.first?.wrapped.config.path, .path("fake_entity") / "42")
                case .some(.failure(let error)):
                    XCTFail("Unexpected error: \(error)")
                case .none:
                    XCTAssertEqual(self.store.level, .remote)
                }
                expectation.fulfill()
            }        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_post_a_request_to_the_client_queue_using_endpoint_derived_from_entity_type_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)
        let entity = EntitySpy(idValue: .remote(42, nil), title: "fake_title")

        let result = await store.set(entity, in: WriteContext(dataTarget: .localAndRemote(endpoint: .derivedFromEntityType)))
        switch result {
        case .some(.success(let entity)):
            XCTAssertNotEqual(self.store.level, .remote)
            XCTAssertEqual(entity.identifier.value.remoteValue, 42)
            XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
            XCTAssertEqual(EntitySpy.remotePathRecords.first, .set(.create(entity)))
            let appendInvocations = await clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.first?.wrapped.config.path, .path("fake_entity") / "42")
        case .some(.failure(let error)):
            XCTFail("Unexpected error: \(error)")
        case .none:
            XCTAssertEqual(self.store.level, .remote)
        }
    }

    // MARK: remove(atID:in:completion:)

    func test_should_post_a_delete_request_to_the_client_queue_using_endpoint_derived_from_entity_type() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")

        store.remove(atID: EntitySpyIdentifier(value: .remote(42, nil)), in: WriteContext(dataTarget: .localAndRemote(endpoint: .derivedFromEntityType))) { result in
            switch result {
            case .some(.success):
                XCTFail("Unexpected value")
            case .some(.failure(let error)):
                XCTFail("Unexpected error: \(error)")
            case .none:
                XCTAssertEqual(self.store.level, .remote)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_post_a_delete_request_to_the_client_queue_using_endpoint_derived_from_entity_type_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await store.remove(atID: EntitySpyIdentifier(value: .remote(42, nil)), in: WriteContext(dataTarget: .localAndRemote(endpoint: .derivedFromEntityType)))
        switch result {
        case .some(.success):
            XCTAssertNotEqual(self.store.level, .remote)
            XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
            XCTAssertEqual(EntitySpy.remotePathRecords.first, .remove(EntitySpyIdentifier(value: .remote(42, nil))))
            let appendInvocations = await clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.first?.wrapped.config.path, .path("fake_entity") / "42")
        case .some(.failure(let error)):
            XCTFail("Unexpected error: \(error)")
        case .none:
            XCTAssertEqual(self.store.level, .remote)
        }
    }

    // MARK: search(withQuery:in:completion:)

    func test_should_request_entities_from_the_client_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_entities_from_the_client_using_endpoint_derived_from_entity_type_async() async {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await store.search(withQuery: .filter(.title == .string("fake_title")), in: derivedFromEntityTypeContext)
        switch result {
        case .success(let entities):
            XCTAssertEqual(entities.entity?.identifier.value, .remote(24, nil))
            XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
            XCTAssertEqual(EntitySpy.remotePathRecords.first, .search(Query(filter: .title == .string("fake_title"))))
            XCTAssertEqual(EntitySpy.endpointInvocationCount, 1)

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_should_request_entities_from_the_client_and_order_them_by_id_asc_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_entities_from_the_client_and_order_them_by_id_asc_using_endpoint_derived_from_entity_type_async() async {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let query = Query<EntitySpy>
            .filter(.title == .string("fake_title"))
            .order([.asc(by: .identifier)])

        let result = await store.search(withQuery: query, in: derivedFromEntityTypeContext)
        switch result {
        case .success(let entities):
            XCTAssertEqual(entities.first?.identifier.value.remoteValue, 24)
            XCTAssertEqual(entities.array.last?.identifier.value.remoteValue, 42)

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_should_request_entities_from_the_client_and_order_them_by_id_desc_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_entities_from_the_client_and_order_them_by_id_desc_using_endpoint_derived_from_entity_type_async() async {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let query = Query<EntitySpy>
            .filter(.title == .string("fake_title"))
            .order([.desc(by: .identifier)])

        let result = await store.search(withQuery: query, in: derivedFromEntityTypeContext)
        switch result {
        case .success(let entities):
            XCTAssertEqual(entities.first?.identifier.value.remoteValue, 42)
            XCTAssertEqual(entities.array.last?.identifier.value.remoteValue, 24)

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_two_searches_should_only_send_one_request_to_the_client_by_inferring_the_same_api_request_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")

        store.search(withQuery: .filter(.title == .string("fake_title")), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)

                self.store.search(withQuery: .filter(.title == .string("fake_title")), in: self.derivedFromEntityTypeContext) { result in
                    switch result {
                    case .success(let entities):
                        XCTAssertEqual(entities.isEmpty, false)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 1)

        let appendExpectation = self.expectation(description: "append_invocations")

        Task {
            let appendInvocations = await self.clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.count, 1)
            appendExpectation.fulfill()
        }

        wait(for: [appendExpectation], timeout: 1)
    }

    func test_two_searches_should_only_send_one_request_to_the_client_by_inferring_the_same_api_request_using_endpoint_derived_from_entity_type_async() async {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await self.store.search(withQuery: .filter(.title == .string("fake_title")), in: self.derivedFromEntityTypeContext)
        switch result {
        case .success(let entities):
            XCTAssertEqual(entities.isEmpty, false)

            let result = await self.store.search(withQuery: .filter(.title == .string("fake_title")), in: self.derivedFromEntityTypeContext)
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }

        let appendInvocations = await clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 1)
    }

    func test_two_searches_should_only_send_one_request_to_the_client_by_passing_in_the_request_token_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_two_searches_should_only_send_one_request_to_the_client_by_passing_in_the_request_token_using_endpoint_derived_from_entity_type_async() async {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await store.search(withQuery: .filter(.title == .string("fake_title")), in: derivedFromEntityTypeContext)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.isEmpty, false)

            let query = Query<EntitySpy>(filter: .title == .string("fake_title"))
            let secondResult = await store.search(withQuery: query, in: self.derivedFromEntityTypeContext)
            switch secondResult {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_two_searches_in_two_different_contexts_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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
            Task {
                let appendInvocations = await self.clientQueueSpy.appendInvocations
                XCTAssertEqual(appendInvocations.count, 2)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_searches_in_two_different_contexts_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type_async() async {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let context = ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))
                let result = await self.store.search(withQuery: .filter(.title == .string("fake_title")), in: context)
                switch result {
                case .success(let entities):
                    XCTAssertEqual(entities.isEmpty, false)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }

            group.addTask {
                let context = ReadContext<EntitySpy>(dataSource: .remote(endpoint: .derivedFromEntityType))
                let result = await self.store.search(withQuery: .filter(.title == .string("fake_title")), in: context)
                switch result {
                case .success(let entities):
                    XCTAssertEqual(entities.isEmpty, false)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }

        let appendInvocations = await clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 2)
    }

    func test_two_different_searches_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type() {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")

        store.search(withQuery: .filter(.title == .string("fake_title")), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)

                self.store.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(24, nil)))), in: self.derivedFromEntityTypeContext) { result in
                    switch result {
                    case .success(let entities):
                        XCTAssertEqual(entities.isEmpty, false)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 1)

        let appendExpectation = self.expectation(description: "append_invocations")

        Task {
            let appendInvocations = await self.clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.count, 1)
            appendExpectation.fulfill()
        }

        wait(for: [appendExpectation], timeout: 1)
    }

    func test_two_different_searches_should_send_two_requests_to_the_client_using_endpoint_derived_from_entity_type_async() async {

        let requestConfig = APIRequestConfig(method: .get, path: .path("fake_entity"))
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await self.store.search(withQuery: .filter(.title == .string("fake_title")), in: self.derivedFromEntityTypeContext)
        switch result {
        case .success(let entities):
            XCTAssertEqual(entities.isEmpty, false)
            let result = await self.store.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(24, nil)))), in: self.derivedFromEntityTypeContext)
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }

        let appendInvocations = await clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 1)
    }

    func test_setting_an_entity_should_flip_synchronized_flag_using_endpoint_derived_from_entity_type() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_setting_an_entity_should_flip_synchronized_flag_using_endpoint_derived_from_entity_type_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let entity = EntitySpy(idValue: .remote(42, nil), title: "fake_title")
        XCTAssertEqual(entity.identifier._remoteSynchronizationState.value, .outOfSync)

        let result = await store.set(entity, in: WriteContext(dataTarget: .localAndRemote(endpoint: .derivedFromEntityType)))
        switch result {
        case .some(.success(let entity)):
            XCTAssertEqual(entity.identifier._remoteSynchronizationState.value, .synced)
        case .some(.failure(let error)):
            XCTFail("Unexpected error: \(error)")
        case .none:
            XCTAssertEqual(self.store.level, .remote)
        }
    }

    func test_should_fail_to_search_using_an_entity_from_the_client_when_query_contains_local_identifiers_using_endpoint_derived_from_entity_type() {

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

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

    func test_should_fail_to_search_using_an_entity_from_the_client_when_query_contains_local_identifiers_using_endpoint_derived_from_entity_type_async() async {

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let localIdentifier = EntitySpyIdentifier(value: .local("local_identifier"))
        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42"), query: [("object_id", localIdentifier.queryValue)]), resultPayload: .empty),
            persistenceStrategy: .doNotPersist
        ))

        let result = await store.search(withQuery: .filter(.identifier == .identifier(localIdentifier)), in: requestContext)
        switch result {
        case .failure(.identifierNotSynced):
            break
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        case .success:
            XCTFail("Unexpected success.")
        }
    }

    // MARK: - Endpoint.request

    // MARK: get(byID:in:completion:)

    func test_should_request_an_entity_from_the_client_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_an_entity_from_the_client_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext)
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
    }

    func test_two_gets_should_only_send_one_request_to_the_client_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")

        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)

                self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.requestContext) { result in
                    switch result {
                    case .success(let result):
                        XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 1)

        let appendExpectation = self.expectation(description: "append_invocations")
        
        Task {
            let appendInvocations = await self.clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.count, 1)
            appendExpectation.fulfill()
        }

        wait(for: [appendExpectation], timeout: 1)
    }

    func test_two_gets_should_only_send_one_request_to_the_client_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.requestContext)
        switch result {
        case .success(let result):
            XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)

            let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.requestContext)
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }

        let appendInvocations = await clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 1)
    }

    func test_two_different_gets_should_send_two_requests_to_the_client_using_request_endpoint() {

        let requestConfig2 = APIRequestConfig(method: .get, path: .path("fake_entity") / "24")
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [
            requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false)),
            requestConfig2: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))
        ]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")

        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext) { result in
            switch result {
            case .success(let result):
                XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)

                self.store.get(byID: EntitySpyIdentifier(value: .remote(24, nil)), in: self.requestContext) { result in
                    switch result {
                    case .success(let result):
                        XCTAssertEqual(result.entity?.identifier.value.remoteValue, 24)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 1)

        let appendExpectation = self.expectation(description: "append_invocations")

        Task {
            let appendInvocations = await self.clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.count, 1)
            appendExpectation.fulfill()
        }

        wait(for: [appendExpectation], timeout: 1)
    }

    func test_two_different_gets_should_send_two_requests_to_the_client_using_request_endpoint_async() async {

        let requestConfig2 = APIRequestConfig(method: .get, path: .path("fake_entity") / "24")
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [
            requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false)),
            requestConfig2: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))
        ]
        await clientQueueSpy.setResponseStubs(responseStub)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: self.requestContext)
                switch result {
                case .success(let result):
                    XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
                let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(24, nil)), in: self.requestContext)
                switch result {
                case .success(let result):
                    XCTAssertEqual(result.entity?.identifier.value.remoteValue, 24)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }

            await group.waitForAll()
        }

        let appendInvocations = await clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 1)
    }

    func test_two_gets_in_two_different_contexts_should_send_two_requests_to_the_client_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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
            Task {
                let appendInvocations = await self.clientQueueSpy.appendInvocations
                XCTAssertEqual(appendInvocations.count, 2)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_gets_in_two_different_contexts_should_send_two_requests_to_the_client_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let requestContext1 = ReadContext<EntitySpy>(dataSource: .remoteOrLocal(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: stubEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        let requestContext2 = ReadContext<EntitySpy>(dataSource: .remoteOrLocal(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: stubEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext1)
                switch result {
                case .success(let result):
                    XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }

            group.addTask {
                let result = await self.store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext2)
                switch result {
                case .success(let result):
                    XCTAssertEqual(result.entity?.identifier.value.remoteValue, 42)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }

        let appendInvocations = await clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 2)
    }

    func test_should_fail_to_request_an_entity_from_the_client_using_request_endpoint() {

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [
            requestConfig: APIClientQueueResult<Data, APIError>.failure(.api(httpStatusCode: 400, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)))
        ]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)


        let expectation = self.expectation(description: "entity")
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext) { result in
            switch result {
            case .failure(.api(.api(httpStatusCode: 400, errorPayload: nil, _))):
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

    func test_should_fail_to_request_an_entity_from_the_client_using_request_endpoint_async() async {

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [
            requestConfig: APIClientQueueResult<Data, APIError>.failure(.api(httpStatusCode: 400, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)))
        ]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext)
        switch result {
        case .failure(.api(.api(httpStatusCode: 400, errorPayload: nil, _))):
            break
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        case .success:
            XCTFail("Unexpected success.")
        }
    }

    func test_should_fail_to_get_an_entity_from_the_client_when_query_contains_local_identifiers_using_request_endpoint() {

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

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

    func test_should_fail_to_get_an_entity_from_the_client_when_query_contains_local_identifiers_using_request_endpoint_async() async {

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let localIdentifier = EntitySpyIdentifier(value: .local("local_identifier"))
        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42"), query: [("object_id", localIdentifier.queryValue)]), resultPayload: .empty),
            persistenceStrategy: .doNotPersist
        ))

        let result = await store.get(byID: localIdentifier, in: requestContext)
        switch result {
        case .failure(.identifierNotSynced):
            break
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        case .success:
            XCTFail("Unexpected success.")
        }
    }

    // MARK: set(_:in:completion:)

    func test_should_post_a_request_to_the_client_queue_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")
        let entity = EntitySpy(idValue: .remote(42, nil), title: "fake_title")

        let writeContext = WriteContext<EntitySpy>(dataTarget:
            .localAndRemote(endpoint: .request(requestConfig))
        )

        store.set(entity, in: writeContext) { result in
            Task {
                switch result {
                case .some(.success(let entity)):
                    XCTAssertNotEqual(self.store.level, .remote)
                    XCTAssertEqual(entity.identifier.value.remoteValue, 42)
                    XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
                    XCTAssertEqual(EntitySpy.remotePathRecords.first, .set(.create(entity)))
                    let appendInvocations = await self.clientQueueSpy.appendInvocations
                    XCTAssertEqual(appendInvocations.first?.wrapped.config.path, .path("fake_entity") / "42")
                case .some(.failure(let error)):
                    XCTFail("Unexpected error: \(error)")
                case .none:
                    XCTAssertEqual(self.store.level, .remote)
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_post_a_request_to_the_client_queue_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let entity = EntitySpy(idValue: .remote(42, nil), title: "fake_title")

        let writeContext = WriteContext<EntitySpy>(dataTarget:
            .localAndRemote(endpoint: .request(requestConfig))
        )

        let result = await store.set(entity, in: writeContext)
        switch result {
        case .some(.success(let entity)):
            XCTAssertNotEqual(self.store.level, .remote)
            XCTAssertEqual(entity.identifier.value.remoteValue, 42)
            XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
            XCTAssertEqual(EntitySpy.remotePathRecords.first, .set(.create(entity)))
            let appendInvocations = await clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.first?.wrapped.config.path, .path("fake_entity") / "42")
        case .some(.failure(let error)):
            XCTFail("Unexpected error: \(error)")
        case .none:
            XCTAssertEqual(self.store.level, .remote)
        }
    }

    func test_should_post_a_request_to_the_client_queue_using_request_endpoint_for_multiple_entities() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")
        let entities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }

        let writeContext = WriteContext<EntitySpy>(dataTarget:
            .remote(endpoint: .request(requestConfig))
        )

        store.set(entities, in: writeContext) { result in
            Task {
                switch result {
                case .some(.success(let resultEntities)):
                    XCTAssertEqual(resultEntities.array, entities)
                    let appendInvocations = await self.clientQueueSpy.appendInvocations
                    XCTAssertNotNil(appendInvocations.first)
                    XCTAssertEqual(appendInvocations.first?.identifiers as? [EntitySpyIdentifier], entities.map { $0.identifier })
                case .some(.failure(let error)):
                    XCTFail("Unexpected error: \(error)")
                case .none:
                    XCTAssertEqual(self.store.level, .remote)
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_post_a_request_to_the_client_queue_using_request_endpoint_for_multiple_entities_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let entities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }

        let writeContext = WriteContext<EntitySpy>(dataTarget:
            .remote(endpoint: .request(requestConfig))
        )

        let result = await store.set(entities, in: writeContext)
        switch result {
        case .some(.success(let resultEntities)):
            XCTAssertEqual(resultEntities.array, entities)
            let appendInvocations = await self.clientQueueSpy.appendInvocations
            XCTAssertNotNil(appendInvocations.first)
            XCTAssertEqual(appendInvocations.first?.identifiers as? [EntitySpyIdentifier], entities.map { $0.identifier })
        case .some(.failure(let error)):
            XCTFail("Unexpected error: \(error)")
        case .none:
            XCTAssertEqual(self.store.level, .remote)
        }
    }
    
    // MARK: remove(atID:in:completion:)

    func test_should_post_a_delete_request_to_the_client_queue_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")

        let writeContext = WriteContext<EntitySpy>(dataTarget:
            .localAndRemote(endpoint: .request(requestConfig))
        )

        store.remove(atID: EntitySpyIdentifier(value: .remote(42, nil)), in: writeContext) { result in
            switch result {
            case .some(.success):
                XCTFail("Unexpected value")
            case .some(.failure(let error)):
                XCTFail("Unexpected error: \(error)")
            case .none:
                XCTAssertEqual(self.store.level, .remote)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_should_post_a_delete_request_to_the_client_queue_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let writeContext = WriteContext<EntitySpy>(dataTarget:
            .localAndRemote(endpoint: .request(requestConfig))
        )

        let result = await store.remove(atID: EntitySpyIdentifier(value: .remote(42, nil)), in: writeContext)
        switch result {
        case .some(.success):
            XCTAssertNotEqual(self.store.level, .remote)
            XCTAssertEqual(EntitySpy.remotePathRecords.count, 1)
            XCTAssertEqual(EntitySpy.remotePathRecords.first, .remove(EntitySpyIdentifier(value: .remote(42, nil))))
            let appendInvocations = await self.clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.first?.wrapped.config.path, .path("fake_entity") / "42")
        case .some(.failure(let error)):
            XCTFail("Unexpected error: \(error)")
        case .none:
            XCTAssertEqual(self.store.level, .remote)
        }
    }

    // MARK: search(withQuery:in:completion:)

    func test_should_request_entities_from_the_client_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_entities_from_the_client_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext)
        switch result {
        case .success(let entities):
            XCTAssertEqual(entities.entity?.identifier.value, .remote(24, nil))

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_should_request_entities_from_the_client_and_order_them_by_id_asc_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_entities_from_the_client_and_order_them_by_id_asc_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let query = Query<EntitySpy>
            .filter(.title == .string("fake_title"))
            .order([.asc(by: .identifier)])

        let result = await store.search(withQuery: query, in: requestContext)
        switch result {
        case .success(let entities):
            XCTAssertEqual(entities.first?.identifier.value.remoteValue, 24)
            XCTAssertEqual(entities.array.last?.identifier.value.remoteValue, 42)

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_should_request_entities_from_the_client_and_order_them_by_id_desc_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_entities_from_the_client_and_order_them_by_id_desc_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let query = Query<EntitySpy>
            .filter(.title == .string("fake_title"))
            .order([.desc(by: .identifier)])

        let result = await store.search(withQuery: query, in: requestContext)
        switch result {
        case .success(let entities):
            XCTAssertEqual(entities.first?.identifier.value.remoteValue, 42)
            XCTAssertEqual(entities.array.last?.identifier.value.remoteValue, 24)

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_two_searches_should_only_send_one_request_to_the_client_by_inferring_the_same_api_request_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")

        store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)

                self.store.search(withQuery: .filter(.title == .string("fake_title")), in: self.requestContext) { result in
                    switch result {
                    case .success(let entities):
                        XCTAssertEqual(entities.isEmpty, false)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 1)

        let appendExpectation = self.expectation(description: "append_invocations")

        Task {
            let appendInvocations = await self.clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.count, 1)
            appendExpectation.fulfill()
        }

        wait(for: [appendExpectation], timeout: 1)
    }

    func test_two_searches_should_only_send_one_request_to_the_client_by_inferring_the_same_api_request_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await self.store.search(withQuery: .filter(.title == .string("fake_title")), in: self.requestContext)
        switch result {
        case .success(let entities):
            XCTAssertEqual(entities.isEmpty, false)

            let result = await self.store.search(withQuery: .filter(.title == .string("fake_title")), in: self.requestContext)
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }

        let appendInvocations = await self.clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 1)
    }

    func test_two_searches_should_only_send_one_request_to_the_client_by_passing_in_the_request_token_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_two_searches_should_only_send_one_request_to_the_client_by_passing_in_the_request_token_using_request_endpoint_async() async  {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.isEmpty, false)

            let query = Query<EntitySpy>(filter: .title == .string("fake_title"))
            _ = await self.store.search(withQuery: query, in: self.requestContext)
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_two_searches_in_two_different_contexts_should_send_two_requests_to_the_client_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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
            Task {
                let appendInvocations = await self.clientQueueSpy.appendInvocations
                XCTAssertEqual(appendInvocations.count, 2)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_two_searches_in_two_different_contexts_should_send_two_requests_to_the_client_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let requestContext1 = ReadContext<EntitySpy>(dataSource: .remoteOrLocal(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: stubEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        let requestContext2 = ReadContext<EntitySpy>(dataSource: .remoteOrLocal(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: stubEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let result = await self.store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext1)
                switch result {
                case .success(let entities):
                    XCTAssertEqual(entities.isEmpty, false)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }

            group.addTask {
                let result = await self.store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext2)
                switch result {
                case .success(let entities):
                    XCTAssertEqual(entities.isEmpty, false)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }

        let appendInvocations = await self.clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 2)
    }

    func test_two_different_searches_should_send_two_requests_to_the_client_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }

        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")

        store.search(withQuery: .filter(.title == .string("fake_title")), in: requestContext) { result in
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)

                self.store.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(24, nil)))), in: self.requestContext) { result in
                    switch result {
                    case .success(let entities):
                        XCTAssertEqual(entities.isEmpty, false)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                }

            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 1)

        let appendExpectation = self.expectation(description: "append_invocations")

        Task {
            let appendInvocations = await self.clientQueueSpy.appendInvocations
            XCTAssertEqual(appendInvocations.count, 1)
            appendExpectation.fulfill()
        }

        wait(for: [appendExpectation], timeout: 1)
    }

    func test_two_different_searches_should_send_two_requests_to_the_client_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await self.store.search(withQuery: .filter(.title == .string("fake_title")), in: self.requestContext)
        switch result {
        case .success(let entities):
            XCTAssertEqual(entities.isEmpty, false)

            let result = await self.store.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(24, nil)))), in: self.requestContext)
            switch result {
            case .success(let entities):
                XCTAssertEqual(entities.isEmpty, false)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }

        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }

        let appendInvocations = await self.clientQueueSpy.appendInvocations
        XCTAssertEqual(appendInvocations.count, 1)
    }

    func test_setting_an_entity_should_flip_synchronized_flag_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_setting_an_entity_should_flip_synchronized_flag_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let entity = EntitySpy(idValue: .remote(42, nil), title: "fake_title")
        XCTAssertEqual(entity.identifier._remoteSynchronizationState.value, .outOfSync)

        let result = await store.set(entity, in: WriteContext(dataTarget: .localAndRemote(endpoint: .derivedFromEntityType)))
        switch result {
        case .some(.success(let entity)):
            XCTAssertEqual(entity.identifier._remoteSynchronizationState.value, .synced)
        case .some(.failure(let error)):
            XCTFail("Unexpected error: \(error)")
        case .none:
            XCTAssertEqual(self.store.level, .remote)
        }
    }

    func test_should_fail_to_search_for_an_entity_from_the_client_when_query_contains_local_identifiers_using_request_endpoint() {

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

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

    func test_should_fail_to_search_for_an_entity_from_the_client_when_query_contains_local_identifiers_using_request_endpoint_async() async {

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        let localIdentifier = EntitySpyIdentifier(value: .local("local_identifier"))
        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(APIRequestConfig(method: .get, path: .path("fake_entity/42"), query: [("object_id", localIdentifier.queryValue)]), resultPayload: .empty),
            persistenceStrategy: .doNotPersist
        ))

        let result = await store.search(withQuery: .filter(.identifier == .identifier(localIdentifier)), in: requestContext)
        switch result {
        case .failure(.identifierNotSynced):
            break
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        case .success:
            XCTFail("Unexpected success.")
        }
    }

    // MARK: search(withQuery:in:completion:) with root entities in metadata and trustRemoteFiltering flag

    func test_should_request_entities_from_the_client_and_not_filter_if_there_are_no_root_entities_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_entities_from_the_client_and_not_filter_if_there_are_no_root_entities_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let allEntities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: allEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        let result = await store.search(withQuery: .all, in: requestContext)
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
    }

    func test_should_request_entities_from_the_client_and_filter_for_root_entities_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_entities_from_the_client_and_filter_for_root_entities_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let allEntities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }
        let rootEntities = (1...2).map { EntitySpyMetadata(remoteID: $0) }

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: allEntities,
                                                               stubEntityMetadata: rootEntities,
                                                               stubEndpointMetadata: nil)))
        )

        let result = await store.search(withQuery: .all, in: requestContext)
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
    }

    func test_should_request_entities_from_the_client_and_filter_on_query_when_trust_remote_filtering_is_false_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_entities_from_the_client_and_filter_on_query_when_trust_remote_filtering_is_false_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let allEntities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: allEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)),
            trustRemoteFiltering: false)
        )

        let result = await store.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(1, nil)))), in: requestContext)
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
    }

    func test_should_request_entities_from_the_client_and_not_filter_on_query_when_trust_remote_filtering_is_true_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_entities_from_the_client_and_not_filter_on_query_when_trust_remote_filtering_is_true_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

        let allEntities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: allEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)),
            trustRemoteFiltering: true)
        )

        let result = await store.search(withQuery: .filter(.identifier == .identifier(EntitySpyIdentifier(value: .remote(1, nil)))), in: requestContext)
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
    }

    func test_should_request_entities_from_the_client_and_filter_on_query_when_trust_remote_filtering_is_true_but_response_is_from_cache_using_request_endpoint() {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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

    func test_should_request_entities_from_the_client_and_filter_on_query_when_trust_remote_filtering_is_true_but_response_is_from_cache_using_request_endpoint_async() async {

        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(APIClientResponse(data: payloadStubData, cachedResponse: false))]
        await clientQueueSpy.setResponseStubs(responseStub)

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

        let result = await store.search(withQuery: .all, in: requestContext)
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
    }

    // MARK: - Payloads

    func test_get_should_return_store_error_empty_response_for_api_response_with_304_and_empty_body() {

        let emptyHeader = APIResponseHeader { key in
            if key == "Status" {
                return "304 Not Modified"
            } else {
                return nil
            }
        }
        let emptyResponse = APIClientResponse(data: Data(), header: emptyHeader, cachedResponse: true)
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(emptyResponse)]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        let expectation = self.expectation(description: "entity")
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: derivedFromEntityTypeContext) { result in
            switch result {
            case .success:
                XCTFail("Unexpected success")
            case .failure(.emptyResponse):
                break
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_get_should_return_store_error_empty_response_for_api_response_with_304_and_empty_body_async() async {

        let emptyHeader = APIResponseHeader { key in
            if key == "Status" {
                return "304 Not Modified"
            } else {
                return nil
            }
        }
        let emptyResponse = APIClientResponse(data: Data(), header: emptyHeader, cachedResponse: true)
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(emptyResponse)]
        await clientQueueSpy.setResponseStubs(responseStub)

        let result = await store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: derivedFromEntityTypeContext)
        switch result {
        case .success:
            XCTFail("Unexpected success")
        case .failure(.emptyResponse):
            break
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_search_should_return_store_error_empty_response_for_api_response_with_304_and_empty_body() {

        let emptyHeader = APIResponseHeader { key in
            if key == "Status" {
                return "304 Not Modified"
            } else {
                return nil
            }
        }
        let emptyResponse = APIClientResponse(data: Data(), header: emptyHeader, cachedResponse: true)
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(emptyResponse)]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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
            case .success:
                XCTFail("Unexpected success")
            case .failure(.emptyResponse):
                break
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_search_should_return_store_error_empty_response_for_api_response_with_304_and_empty_body_async() async {

        let emptyHeader = APIResponseHeader { key in
            if key == "Status" {
                return "304 Not Modified"
            } else {
                return nil
            }
        }
        let emptyResponse = APIClientResponse(data: Data(), header: emptyHeader, cachedResponse: true)
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(emptyResponse)]
        await clientQueueSpy.setResponseStubs(responseStub)

        let allEntities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: allEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        let result = await store.search(withQuery: .all, in: requestContext)
        switch result {
        case .success:
            XCTFail("Unexpected success")
        case .failure(.emptyResponse):
            break
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_get_should_attempt_to_create_endpoint_payload_for_api_response_with_304_and_greater_than_zero_body() {

        let emptyHeader = APIResponseHeader { key in
            if key == "Status" {
                return "304 Not Modified"
            } else {
                return nil
            }
        }
        let someResponse = APIClientResponse(data: Data(count: 1), header: emptyHeader, cachedResponse: true)
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(someResponse)]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: stubEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        let expectation = self.expectation(description: "entity")
        store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext) { result in
            switch result {
            case .success(let queryResult):
                XCTAssertEqual(queryResult.entity?.identifier, EntitySpyIdentifier(value: .remote(42, nil)))
            case .failure(.emptyResponse):
                XCTFail("Unexpected empty response")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_get_should_attempt_to_create_endpoint_payload_for_api_response_with_304_and_greater_than_zero_body_async() async {

        let emptyHeader = APIResponseHeader { key in
            if key == "Status" {
                return "304 Not Modified"
            } else {
                return nil
            }
        }
        let someResponse = APIClientResponse(data: Data(count: 1), header: emptyHeader, cachedResponse: true)
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(someResponse)]
        await clientQueueSpy.setResponseStubs(responseStub)

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: stubEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        let result = await store.get(byID: EntitySpyIdentifier(value: .remote(42, nil)), in: requestContext)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.entity?.identifier, EntitySpyIdentifier(value: .remote(42, nil)))
        case .failure(.emptyResponse):
            XCTFail("Unexpected empty response")
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_search_should_attempt_to_create_endpoint_payload_api_response_with_304_and_greater_than_zero_body() {

        let emptyHeader = APIResponseHeader { key in
            if key == "Status" {
                return "304 Not Modified"
            } else {
                return nil
            }
        }
        let someResponse = APIClientResponse(data: Data(count: 1), header: emptyHeader, cachedResponse: true)
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(someResponse)]
        let spyExpectation = self.expectation(description: "client_queue_spy_setup")
        Task {
            await clientQueueSpy.setResponseStubs(responseStub)
            spyExpectation.fulfill()
        }
        wait(for: [spyExpectation], timeout: 1)

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
            case .success(let queryResult):
                XCTAssertEqual(queryResult.array, allEntities)
            case .failure(.emptyResponse):
                XCTFail("Unexpected empty response")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_search_should_attempt_to_create_endpoint_payload_api_response_with_304_and_greater_than_zero_body_async() async {

        let emptyHeader = APIResponseHeader { key in
            if key == "Status" {
                return "304 Not Modified"
            } else {
                return nil
            }
        }
        let someResponse = APIClientResponse(data: Data(count: 1), header: emptyHeader, cachedResponse: true)
        let responseStub: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [requestConfig: APIClientQueueResult<Data, APIError>.success(someResponse)]
        await clientQueueSpy.setResponseStubs(responseStub)

        let allEntities = (1...3).map { EntitySpy(idValue: .remote($0, nil)) }

        requestContext = ReadContext<EntitySpy>(dataSource: .remote(
            endpoint: .request(requestConfig,
                               resultPayload: EndpointStubData(stubEntities: allEntities,
                                                               stubEntityMetadata: nil,
                                                               stubEndpointMetadata: nil)))
        )

        let result = await store.search(withQuery: .all, in: requestContext)
        switch result {
        case .success(let queryResult):
            XCTAssertEqual(queryResult.array, allEntities)
        case .failure(.emptyResponse):
            XCTFail("Unexpected empty response")
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
    }
}
