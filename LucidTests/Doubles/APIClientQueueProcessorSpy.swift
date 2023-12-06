//
//  APIClientQueueProcessorDelegateSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 4/24/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
@testable import Lucid

public final actor APIClientQueueProcessorSpy: APIClientQueueProcessing {

    // MARK: - Records

    public private(set) var didEnqueueNewRequestInvocations = 0

    public private(set) var flushInvocations = 0

    public private(set) var setDelegateInvocations = [APIClientQueueProcessorDelegate?]()

    public private(set) var registerInvocations = [APIClientQueueProcessorResponseHandler]()

    public private(set) var unregisterInvocations = [UUID]()

    public private(set) var abortRequestInvocations = [APIClientQueueRequest]()

    public private(set) var prepareRequestInvocations = [APIRequestConfig]()

    // MARK: - Stubs

    public var tokenStub = UUID()

    // MARK: - API

    public init() {
        // no-op
    }

    public func setDelegate(_ delegate: APIClientQueueProcessorDelegate?) async {
        setDelegateInvocations.append(delegate)
    }

    public func didEnqueueNewRequest() async {
        didEnqueueNewRequestInvocations += 1
    }

    public func flush() async {
        flushInvocations += 1
    }

    public func register(_ handler: @escaping APIClientQueueProcessorResponseHandler) async -> APIClientQueueResponseHandlerToken {
        registerInvocations.append(handler)
        return tokenStub
    }

    public func unregister(_ token: APIClientQueueProcessorResponseHandlerToken) async {
        unregisterInvocations.append(token)
    }

    public func abortRequest(_ request: APIClientQueueRequest) async {
        abortRequestInvocations.append(request)
    }

    public func prepareRequest(_ requestConfig: APIRequestConfig) async -> APIRequestConfig {
        prepareRequestInvocations.append(requestConfig)
        return requestConfig
    }
}

public final actor APIClientQueueProcessorDelegateSpy: APIClientQueueProcessorDelegate {

    // MARK: - Stubs

    public var requestStub: APIClientQueueRequest?

    public func setRequestStub(stub: APIClientQueueRequest?) {
        self.requestStub = stub
    }

    public var removeRequestsStub: [APIClientQueueRequest] = []

    public func setRemoveRequestsStub(stub: [APIClientQueueRequest]) {
        self.removeRequestsStub = stub
    }

    // MARK: - Records

    public private(set) var prependInvocations = [
        APIClientQueueRequest
    ]()

    public private(set) var removeRequestsInvocations = [
        (APIClientQueueRequest) -> Bool
    ]()

    public private(set) var nextRequestInvocations = 0

    // MARK: - API

    public init() {
        // no-op
    }

    public func prepend(_ request: APIClientQueueRequest) async {
        prependInvocations.append((request))
    }

    public func removeRequests(matching: @escaping (APIClientQueueRequest) -> Bool) async -> [APIClientQueueRequest] {
        removeRequestsInvocations.append(matching)
        return removeRequestsStub
    }

    public func nextRequest() async -> APIClientQueueRequest? {
        nextRequestInvocations += 1
        return requestStub
    }
}
