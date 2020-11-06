//
//  APIClientQueueProcessorDelegateSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 4/24/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

#if LUCID_REACTIVE_KIT
@testable import Lucid_ReactiveKit
#else
@testable import Lucid
#endif

public final class APIClientQueueProcessorSpy: APIClientQueueProcessing {

    // MARK: - Records

    public private(set) var didEnqueueNewRequestInvocations = 0

    public private(set) var flushInvocations = 0

    public private(set) var getDelegateInvocations = 0
    
    public private(set) var setDelegateInvocations = [APIClientQueueProcessorDelegate?]()

    public private(set) var registerInvocations = [APIClientQueueProcessorResponseHandler]()

    public private(set) var unregisterInvocations = [UUID]()

    public private(set) var abortRequestInvocations = [APIClientQueueRequest]()

    // MARK: - Stubs

    public var tokenStub = UUID()

    // MARK: - API

    public init() {
        // no-op
    }

    public var delegate: APIClientQueueProcessorDelegate? {
        get {
            getDelegateInvocations += 1
            return nil
        }
        set {
            setDelegateInvocations.append(newValue)
        }
    }

    public func didEnqueueNewRequest() {
        didEnqueueNewRequestInvocations += 1
    }

    public func flush() {
        flushInvocations += 1
    }

    public func register(_ handler: @escaping APIClientQueueProcessorResponseHandler) -> APIClientQueueResponseHandlerToken {
        registerInvocations.append(handler)
        return tokenStub
    }

    public func unregister(_ token: APIClientQueueProcessorResponseHandlerToken) {
        unregisterInvocations.append(token)
    }

    public func abortRequest(_ request: APIClientQueueRequest) {
        abortRequestInvocations.append(request)
    }

    public var jsonCoderConfig = APIJSONCoderConfig()
}

public final class APIClientQueueProcessorDelegateSpy: APIClientQueueProcessorDelegate {

    // MARK: - Stubs

    public var requestStub: APIClientQueueRequest?

    public var removeRequestsStub: [APIClientQueueRequest] = []

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

    public func prepend(_ request: APIClientQueueRequest) {
        prependInvocations.append((request))
    }

    public func removeRequests(matching: @escaping (APIClientQueueRequest) -> Bool) -> [APIClientQueueRequest] {
        removeRequestsInvocations.append(matching)
        return removeRequestsStub
    }

    public func nextRequest() -> APIClientQueueRequest? {
        nextRequestInvocations += 1
        return requestStub
    }
}
