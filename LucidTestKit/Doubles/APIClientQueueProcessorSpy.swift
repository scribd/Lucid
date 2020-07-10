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

final class APIClientQueueProcessorSpy: APIClientQueueProcessing {

    // MARK: - Records

    private(set) var didEnqueueNewRequestInvocations = 0

    private(set) var flushInvocations = 0

    private(set) var getDelegateInvocations = 0
    private(set) var setDelegateInvocations = [APIClientQueueProcessorDelegate?]()

    private(set) var registerInvocations = [APIClientQueueProcessorResponseHandler]()

    private(set) var unregisterInvocations = [UUID]()

    // MARK: - Stubs

    var tokenStub = UUID()

    // MARK: - API

    var delegate: APIClientQueueProcessorDelegate? {
        get {
            getDelegateInvocations += 1
            return nil
        }
        set {
            setDelegateInvocations.append(newValue)
        }
    }

    func didEnqueueNewRequest() {
        didEnqueueNewRequestInvocations += 1
    }

    func flush() {
        flushInvocations += 1
    }

    func register(_ handler: @escaping APIClientQueueProcessorResponseHandler) -> APIClientQueueResponseHandlerToken {
        registerInvocations.append(handler)
        return tokenStub
    }

    func unregister(_ token: APIClientQueueProcessorResponseHandlerToken) {
        unregisterInvocations.append(token)
    }
}

final class APIClientQueueProcessorDelegateSpy: APIClientQueueProcessorDelegate {

    // MARK: - Stubs

    var requestStub: APIClientQueueRequest?

    var removeRequestsStub: [APIClientQueueRequest] = []

    // MARK: - Records

    private(set) var prependInvocations = [
        APIClientQueueRequest
    ]()

    private(set) var removeRequestsInvocations = [
        (APIClientQueueRequest) -> Bool
    ]()

    private(set) var nextRequestInvocations = 0

    // MARK: - API

    func prepend(_ request: APIClientQueueRequest) {
        prependInvocations.append((request))
    }

    func removeRequests(matching: @escaping (APIClientQueueRequest) -> Bool) -> [APIClientQueueRequest] {
        removeRequestsInvocations.append(matching)
        return removeRequestsStub
    }

    func nextRequest() -> APIClientQueueRequest? {
        nextRequestInvocations += 1
        return requestStub
    }
}
