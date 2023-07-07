//
//  APIClientQueueProcessorTests.swift
//  LucidTests
//
//  Created by Stephane Magne on 3/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import XCTest

@testable import LucidTestKit
@testable import Lucid

final class APIClientQueueProcessorTests: XCTestCase {

    // MARK: - Spies

    private var clientSpy: APIClientSpy!

    private var backgroundTaskManagerSpy: BackgroundTaskManagerSpy!

    private var processDelegateSpy: APIClientQueueProcessorDelegateSpy!

    private var schedulerSpy: APIClientQueueSchedulerSpy!

    private var diskCacheSpy: DiskCacheSpy<APIClientQueueRequest>!

    private var responseHandlerSpy: APIClientQueueProcessorResponseHandlerSpy!

    private var processingQueue: DispatchQueue!

    private var asyncOperationInternalQueue: DispatchQueue!

    private var asyncOperationQueue: AsyncOperationQueue!

    // MARK: - Subject

    private var processor: APIClientQueueProcessor!

    override func setUp() {
        super.setUp()

        LucidConfiguration.logger = LoggerMock(shouldCauseFailures: false)

        clientSpy = APIClientSpy()
        backgroundTaskManagerSpy = BackgroundTaskManagerSpy()
        processDelegateSpy = APIClientQueueProcessorDelegateSpy()
        schedulerSpy = APIClientQueueSchedulerSpy()
        diskCacheSpy = DiskCacheSpy()
        responseHandlerSpy = APIClientQueueProcessorResponseHandlerSpy()
        processingQueue = DispatchQueue(label: "test_processing_queue")
        asyncOperationInternalQueue = DispatchQueue(label: "test_internal_operation_queue")
        asyncOperationQueue = AsyncOperationQueue(dispatchQueue: asyncOperationInternalQueue)

        processor = APIClientQueueProcessor(client: clientSpy,
                                            backgroundTaskManager: backgroundTaskManagerSpy,
                                            scheduler: schedulerSpy,
                                            diskCache: diskCacheSpy.caching,
                                            responseHandlers: [responseHandlerSpy.handler],
                                            processingQueue: processingQueue,
                                            operationQueue: asyncOperationQueue)
    }

    override func tearDown() {
        defer { super.tearDown() }

        clientSpy = nil
        backgroundTaskManagerSpy = nil
        processDelegateSpy = nil
        schedulerSpy = nil
        diskCacheSpy = nil
        responseHandlerSpy = nil
        processor = nil
        processingQueue = nil
    }

    private var nsError: NSError {
        return NSError(domain: "test", code: 1, userInfo: nil)
    }

    private func waitForAsyncQueues(_ completion: @escaping () -> Void) {
        asyncOperationInternalQueue.async {
            self.processingQueue.async {
                completion()
            }
        }
    }

    // MARK: - Tests

    func test_processor_with_existing_cached_operation_prepends_to_client_queue() {
        let request = APIRequest<Data>(method: .post, path: .path("fake_path"))
        let mockQueueRequest = APIClientQueueRequest(wrapping: request)
        diskCacheSpy.values = ["APIClientQueueProcessorCacheKey": mockQueueRequest]

        XCTAssertTrue(processDelegateSpy.prependInvocations.isEmpty)

        processor.delegate = processDelegateSpy

        XCTAssertEqual(processDelegateSpy.prependInvocations.count, 1)
        XCTAssertEqual(processDelegateSpy.prependInvocations.first, mockQueueRequest)
    }

    func test_processor_with_existing_cached_operation_does_not_process_at_setup() {
        let request = APIRequest<Data>(method: .post, path: .path("fake_path"))
        let mockQueueRequest = APIClientQueueRequest(wrapping: request)
        diskCacheSpy.values = ["APIClientQueueProcessorCacheKey": mockQueueRequest]

        XCTAssertEqual(schedulerSpy.didEnqueueNewRequestCallCount, 0)

        processor.delegate = processDelegateSpy

        XCTAssertEqual(schedulerSpy.didEnqueueNewRequestCallCount, 0)
    }

    func test_processor_sets_up_scheduler_as_delegate() {
        XCTAssertTrue(schedulerSpy.delegate === processor)
    }

    func test_processor_informs_scheduler_of_new_request() {
        XCTAssertEqual(schedulerSpy.didEnqueueNewRequestCallCount, 0)
        XCTAssertEqual(schedulerSpy.flushCallCount, 0)
        XCTAssertEqual(schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(schedulerSpy.requestDidFailCallCount, 0)

        processor.didEnqueueNewRequest()

        XCTAssertEqual(schedulerSpy.didEnqueueNewRequestCallCount, 1)
        XCTAssertEqual(schedulerSpy.flushCallCount, 0)
        XCTAssertEqual(schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(schedulerSpy.requestDidFailCallCount, 0)
    }

    func test_processor_informs_scheduler_of_flush() {
        XCTAssertEqual(schedulerSpy.didEnqueueNewRequestCallCount, 0)
        XCTAssertEqual(schedulerSpy.flushCallCount, 0)
        XCTAssertEqual(schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(schedulerSpy.requestDidFailCallCount, 0)

        processor.flush()

        XCTAssertEqual(schedulerSpy.didEnqueueNewRequestCallCount, 0)
        XCTAssertEqual(schedulerSpy.flushCallCount, 1)
        XCTAssertEqual(schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(schedulerSpy.requestDidFailCallCount, 0)
    }

    func test_processor_asks_delegate_for_next_request() {
        processor.delegate = processDelegateSpy
        XCTAssertEqual(processDelegateSpy.nextRequestInvocations, 0)
        processor.processNext()
        XCTAssertEqual(processDelegateSpy.nextRequestInvocations, 1)
    }

    func test_processor_tells_scheduler_false_if_no_requests_are_pending() {
        processor.delegate = processDelegateSpy
        let didProcessNext = processor.processNext().didProcess
        XCTAssertFalse(didProcessNext)
    }

    func test_processor_tells_scheduler_true_if_there_is_a_pending_request() {
        let request = APIRequest<Data>(method: .post, path: .path("fake_path"))
        processDelegateSpy.requestStub = APIClientQueueRequest(wrapping: request)
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs[request.config] = Result<APIClientResponse<Data>, APIError>.success(
            APIClientResponse(data: Data(), cachedResponse: false)
        )

        let didProcessNext = processor.processNext().didProcess
        XCTAssertTrue(didProcessNext)
    }

    func test_processor_does_nothing_if_no_requests_are_pending() {
        processor.delegate = processDelegateSpy

        XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 0)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_calls_background_task_manager_function_begin_background_task_if_there_is_a_pending_post_request() {
        let request = APIRequest<Data>(method: .post, path: .path("fake_path"))
        processDelegateSpy.requestStub = APIClientQueueRequest(wrapping: request)
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs[request.config] = Result<APIClientResponse<Data>, APIError>.success(
            APIClientResponse(data: Data(), cachedResponse: false)
        )

        XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 0)
        XCTAssertEqual(self.processDelegateSpy.nextRequestInvocations, 0)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 1)
            XCTAssertEqual(self.processDelegateSpy.nextRequestInvocations, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_does_not_call_background_task_manager_function_begin_background_task_if_there_is_a_pending_get_request() {
        let request = APIRequest<Data>(method: .get, path: .path("fake_path"))
        processDelegateSpy.requestStub = APIClientQueueRequest(wrapping: request)
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs[request.config] = Result<APIClientResponse<Data>, APIError>.success(
            APIClientResponse(data: Data(), cachedResponse: false)
        )

        XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 0)
        XCTAssertEqual(self.processDelegateSpy.nextRequestInvocations, 0)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 0)
            XCTAssertEqual(self.processDelegateSpy.nextRequestInvocations, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_does_not_attempt_to_process_request_if_already_running_barrier_request() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [])
        let request = APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy)
        processDelegateSpy.requestStub = APIClientQueueRequest(wrapping: request)
        processor.delegate = processDelegateSpy

        clientSpy.completionDelay = 0.05
        clientSpy.resultStubs[request.config] = Result<APIClientResponse<Data>, APIError>.success(
            APIClientResponse(data: Data(), cachedResponse: false)
        )

        XCTAssertEqual(backgroundTaskManagerSpy.startInvocations.count, 0)
        XCTAssertEqual(processDelegateSpy.nextRequestInvocations, 0)

        processor.processNext()
        processor.processNext()

        processingQueue.sync { }

        XCTAssertEqual(backgroundTaskManagerSpy.startInvocations.count, 1)
        XCTAssertEqual(processDelegateSpy.nextRequestInvocations, 1)
    }

    func test_processor_does_attempt_to_process_request_if_already_running_concurrent_request() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .concurrent, retryPolicy: [])
        let request = APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy)
        processDelegateSpy.requestStub = APIClientQueueRequest(wrapping: request)
        processor.delegate = processDelegateSpy

        clientSpy.completionDelay = 0.05
        clientSpy.resultStubs[request.config] = Result<APIClientResponse<Data>, APIError>.success(
            APIClientResponse(data: Data(), cachedResponse: false)
        )

        XCTAssertEqual(backgroundTaskManagerSpy.startInvocations.count, 0)
        XCTAssertEqual(processDelegateSpy.nextRequestInvocations, 0)

        processor.processNext()
        processor.processNext()

        processingQueue.sync { }

        XCTAssertEqual(backgroundTaskManagerSpy.startInvocations.count, 1)
        XCTAssertEqual(processDelegateSpy.nextRequestInvocations, 2)
    }

    func test_processor_attempts_to_process_after_finished_running() {
        let request1 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path1")))
        let request2 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path2")))
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request1.wrapped.config: Result<APIClientResponse<Data>, APIError>.success(
                APIClientResponse(data: Data(), cachedResponse: false)
            ),
            request2.wrapped.config: Result<APIClientResponse<Data>, APIError>.success(
                APIClientResponse(data: Data(), cachedResponse: false)
            )
        ]

        let expectation = self.expectation(description: "processor")

        XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 0)
        XCTAssertEqual(self.processDelegateSpy.nextRequestInvocations, 0)

        processDelegateSpy.requestStub = request1
        processor.processNext()

        waitForAsyncQueues {
            self.processDelegateSpy.requestStub = request2
            self.processor.processNext()

            self.waitForAsyncQueues {
                XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 2)
                XCTAssertEqual(self.processDelegateSpy.nextRequestInvocations, 2)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_calls_client_function_send_if_there_is_a_pending_request() {
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path")))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.success(
                APIClientResponse(data: Data(), cachedResponse: false)
            )
        ]

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.clientSpy.requestRecords.first as? APIRequest<Data>, request.wrapped)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_succeeded_and_asks_for_next_request_for_result_success() {
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path")))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.success(
                APIClientResponse(data: Data(), cachedResponse: false)
            )
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 1)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    private func _testFailureStateWithAPIError(_ apiError: APIError) {
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path")))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(apiError)
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
            XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_failed_and_does_not_prepend_request_for_failure_with_error_networkingProtocolIsNotHTTP() {
        _testFailureStateWithAPIError(.networkingProtocolIsNotHTTP)
    }

    func test_processor_tells_scheduler_request_failed_and_does_not_prepend_request_for_failure_with_error_network() {
        _testFailureStateWithAPIError(.network(.other(nsError)))
    }

    func test_processor_tells_scheduler_request_failed_and_does_not_prepend_request_for_failure_with_error_url() {
        _testFailureStateWithAPIError(.url)
    }

    func test_processor_tells_scheduler_request_failed_and_does_not_prepend_request_for_failure_with_error_deserialization() {
        _testFailureStateWithAPIError(.deserialization(nsError))
    }

    func test_processor_tells_scheduler_request_failed_and_does_not_prepend_request_for_failure_with_error_emptyBodyResponse() {
        _testFailureStateWithAPIError(.other("fake error"))
    }

    func test_processor_tells_scheduler_request_failed_and_does_not_prepend_request_for_failure_with_error_api() {
        _testFailureStateWithAPIError(.api(
            httpStatusCode: 1,
            errorPayload: APIErrorPayload(apiStatusCode: 5, message: "error"),
            response: APIClientResponse(data: Data(), cachedResponse: false)
        ))
    }

    func test_processor_tells_scheduler_request_failed_and_prepends_request_for_failure_with_error_no_internet_connection() {
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path")))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.notConnectedToInternet)))
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
            XCTAssertEqual(self.processDelegateSpy.prependInvocations.first, request)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_failed_and_prepends_request_for_failure_with_error_internet_connection_lost() {
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path")))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.networkConnectionLost)))
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
            XCTAssertEqual(self.processDelegateSpy.prependInvocations.first, request)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_failed_and_prepends_request_for_failure_with_error_internet_connection_timed_out() {
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path")))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.requestTimedOut)))
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
            XCTAssertEqual(self.processDelegateSpy.prependInvocations.first, request)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_failed_and_does_not_prepend_request_for_failure_with_error_no_internet_connection_where_retry_is_set_to_false() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.notConnectedToInternet)))
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
            XCTAssertNil(self.processDelegateSpy.prependInvocations.first)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_failed_and_does_not_prepend_request_for_failure_with_error_network_connection_lost_where_retry_is_set_to_false() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.networkConnectionLost)))
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
            XCTAssertNil(self.processDelegateSpy.prependInvocations.first)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_failed_and_does_not_prepend_request_for_failure_with_error_request_timed_out_where_retry_is_set_to_false() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.requestTimedOut)))
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
            XCTAssertNil(self.processDelegateSpy.prependInvocations.first)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_failed_and_prepends_request_for_background_session_expired() {
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path")))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.networkConnectionLost)))
        ]

        XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        clientSpy.requestWillComplete = false
        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            // expire background session
            self.backgroundTaskManagerSpy.startInvocations.forEach { $0() }

            self.waitForAsyncQueues {
                XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 1)
                XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
                XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
                XCTAssertEqual(self.processDelegateSpy.prependInvocations.first, request)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_does_not_tell_scheduler_request_failed_or_prepend_request_for_background_session_expired_if_request_is_already_processed() {
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path")))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.success(
                APIClientResponse(data: Data(), cachedResponse: false)
            )
        ]

        XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 0)
        XCTAssertEqual(self.backgroundTaskManagerSpy.stopInvocations.count, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        clientSpy.requestWillComplete = true
        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.backgroundTaskManagerSpy.stopInvocations.count, 1)
            XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 1)
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 1)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
            XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_failed_and_does_not_prepend_request_for_retry_when_returned_error_code_is_not_included_in_custom_list() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [
            .onCustomErrorCodes([1008])
        ])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        let error = NSError(domain: "test", code: 550)
        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.other(error)))
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
            XCTAssertNil(self.processDelegateSpy.prependInvocations.first)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_failed_and_prepends_request_for_retry_when_returned_error_code_is_included_in_custom_list() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [
            .onCustomErrorCodes([1008])
        ])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        let error = NSError(domain: "test", code: 1008)
        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.other(error)))
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 1)
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
            XCTAssertEqual(self.processDelegateSpy.prependInvocations.first, request)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_failed_and_does_not_prepend_request_for_retry_when_returned_error_code_is_included_in_exception_list() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [
            .onAllErrorCodesExcept([1008])
        ])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        let error = NSError(domain: "test", code: 1008)
        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.other(error)))
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
            XCTAssertNil(self.processDelegateSpy.prependInvocations.first)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_tells_scheduler_request_failed_and_prepends_request_for_retry_when_returned_error_code_is_not_included_in_exception_list() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [
            .onAllErrorCodesExcept([1008])
        ])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        let error = NSError(domain: "test", code: 408)
        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.other(error)))
        ]

        XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
        XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 0)
        XCTAssertTrue(self.processDelegateSpy.prependInvocations.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.backgroundTaskManagerSpy.startInvocations.count, 1)
            XCTAssertEqual(self.schedulerSpy.requestDidSucceedCallCount, 0)
            XCTAssertEqual(self.schedulerSpy.requestDidFailCallCount, 1)
            XCTAssertEqual(self.processDelegateSpy.prependInvocations.first, request)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_should_call_response_handlers_after_process_is_complete_with_success() {
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path")))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.success(
                APIClientResponse(data: Data(), cachedResponse: false)
            )
        ]

        XCTAssertTrue(self.responseHandlerSpy.resultRecords.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.responseHandlerSpy.resultRecords.first?.value?.data, Data())
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.first, request)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_should_call_response_handlers_after_process_is_complete_with_failure() {
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path")))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.url)
        ]

        XCTAssertTrue(self.responseHandlerSpy.resultRecords.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.responseHandlerSpy.resultRecords.first?.error, .url)
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.first, request)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: .networkConnectionFailure

    func test_processor_should_not_call_response_handlers_after_process_is_complete_with_internet_connection_failure_for_request_with_retry_set_to_true() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [.onNetworkInterrupt])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.networkConnectionLost)))
        ]

        XCTAssertTrue(self.responseHandlerSpy.resultRecords.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertNil(self.responseHandlerSpy.requestRecords.first)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_calls_response_handlers_after_process_is_complete_with_internet_connection_failure_for_request_with_retry_set_to_false() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.networkConnectionLost)))
        ]

        XCTAssertTrue(self.responseHandlerSpy.resultRecords.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.count, 1)
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.first, request)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_calls_response_handlers_after_process_is_complete_with_request_timed_out_for_request_with_retry_set_to_false() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.requestTimedOut)))
        ]

        XCTAssertTrue(self.responseHandlerSpy.resultRecords.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.count, 1)
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.first, request)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_does_not_call_response_handlers_after_process_is_complete_with_request_timed_out_for_request_with_retry_timeout_set_to_true() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [.onRequestTimeout])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.requestTimedOut)))
        ]

        XCTAssertTrue(self.responseHandlerSpy.resultRecords.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertNil(self.responseHandlerSpy.requestRecords.first)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_calls_response_handlers_after_process_is_complete_with_internet_connection_failure_for_request_with_retry_timeout_set_to_true() {
        let queueingStrategy = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [.onRequestTimeout])
        let request = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path"), queueingStrategy: queueingStrategy))
        processDelegateSpy.requestStub = request
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.networkConnectionLost)))
        ]

        XCTAssertTrue(self.responseHandlerSpy.resultRecords.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.count, 1)
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.first, request)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    // MARK: - Removing items from queue on network error

    func test_processor_calls_all_response_handlers_for_requests_in_queue_after_internet_connection_failure_for_requests_with_retry_set_to_false() {
        let queueingStrategy1 = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [.onNetworkInterrupt])
        let request1 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_1"), queueingStrategy: queueingStrategy1))

        let queueingStrategy2 = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [])
        let request2 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_2"), queueingStrategy: queueingStrategy2))

        let queueingStrategy3 = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [.onNetworkInterrupt])
        let request3 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_3"), queueingStrategy: queueingStrategy3))

        let queueingStrategy4 = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [.onRequestTimeout])
        let request4 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_4"), queueingStrategy: queueingStrategy4))

        let requestQueue = [request2, request3, request4]

        processDelegateSpy.requestStub = request1
        processDelegateSpy.removeRequestsStub = [request2, request4]
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request1.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.networkConnectionLost)))
        ]

        XCTAssertTrue(self.responseHandlerSpy.resultRecords.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.processDelegateSpy.removeRequestsInvocations.count, 1)
            if let matchingFilter = self.processDelegateSpy.removeRequestsInvocations.first {
                let calculatedResults = requestQueue.filter(matchingFilter)
                XCTAssertEqual(calculatedResults, self.processDelegateSpy.removeRequestsStub)
            } else {
                XCTFail("Couldn't get expected filter.")
            }

            XCTAssertEqual(self.responseHandlerSpy.requestRecords.count, 2)
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.first, request2)
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.last, request4)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_calls_all_response_handlers_for_requests_in_queue_for_barrier_request_complete_with_timeout_failure_for_requests_with_retry_set_to_false() {
        let queueingStrategy1 = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [.onRequestTimeout])
        let request1 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_1"), queueingStrategy: queueingStrategy1))

        let queueingStrategy2 = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [])
        let request2 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_2"), queueingStrategy: queueingStrategy2))

        let queueingStrategy3 = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [.onNetworkInterrupt])
        let request3 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_3"), queueingStrategy: queueingStrategy3))

        let queueingStrategy4 = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [.onRequestTimeout])
        let request4 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_4"), queueingStrategy: queueingStrategy4))

        let requestQueue = [request2, request3, request4]

        processDelegateSpy.requestStub = request1
        processDelegateSpy.removeRequestsStub = [request2, request3]
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request1.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.requestTimedOut)))
        ]

        XCTAssertTrue(self.responseHandlerSpy.resultRecords.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.processDelegateSpy.removeRequestsInvocations.count, 1)
            if let matchingFilter = self.processDelegateSpy.removeRequestsInvocations.first {
                let calculatedResults = requestQueue.filter(matchingFilter)
                XCTAssertEqual(calculatedResults, self.processDelegateSpy.removeRequestsStub)
            } else {
                XCTFail("Couldn't get expected filter.")
            }

            XCTAssertEqual(self.responseHandlerSpy.requestRecords.count, 2)
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.first, request2)
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.last, request3)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_processor_does_not_call_all_response_handlers_for_requests_in_queue_for_concurrent_request_complete_with_timeout_failure_for_requests_with_retry_set_to_false() {
        let queueingStrategy1 = APIRequestConfig.QueueingStrategy(synchronization: .concurrent, retryPolicy: [.onRequestTimeout])
        let request1 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_1"), queueingStrategy: queueingStrategy1))

        let queueingStrategy2 = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [])
        let request2 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_2"), queueingStrategy: queueingStrategy2))

        let queueingStrategy3 = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [.onNetworkInterrupt])
        let request3 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_3"), queueingStrategy: queueingStrategy3))

        let queueingStrategy4 = APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryPolicy: [.onRequestTimeout])
        let request4 = APIClientQueueRequest(wrapping: APIRequest<Data>(method: .post, path: .path("fake_path_4"), queueingStrategy: queueingStrategy4))

        processDelegateSpy.requestStub = request1
        processDelegateSpy.removeRequestsStub = [request2, request3, request4]
        processor.delegate = processDelegateSpy

        clientSpy.resultStubs = [
            request1.wrapped.config: Result<APIClientResponse<Data>, APIError>.failure(.network(.networkConnectionFailure(.requestTimedOut)))
        ]

        XCTAssertTrue(self.responseHandlerSpy.resultRecords.isEmpty)

        processor.processNext()

        let expectation = self.expectation(description: "processor")
        waitForAsyncQueues {
            XCTAssertEqual(self.processDelegateSpy.removeRequestsInvocations.count, 0)
            XCTAssertEqual(self.responseHandlerSpy.requestRecords.count, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

}
