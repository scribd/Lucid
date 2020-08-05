//
//  APIClientQueueSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 10/19/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

#if LUCID_REACTIVE_KIT
import Lucid_ReactiveKit
#else
import Lucid
#endif

public final class APIClientQueueSpy: APIClientQueuing, APIClientQueueFlushing {

    // MARK: - Records

    public private(set) var appendInvocations = [APIClientQueueRequest]()

    public private(set) var flushInvocations = 0

    public private(set) var registerInvocations = [APIClientQueueResponseHandler]()

    public private(set) var mapInvocations = 0

    public private(set) var unregisterInvocations = [UUID]()

    // MARK: - Stubs

    public var tokenStub = UUID()

    public var responseStubs: [APIRequestConfig: APIClientQueueResult<Data, APIError>] = [:]

    // MARK: - API

    public init() {
        // no-op
    }

    public func append(_ request: APIClientQueueRequest) {
        appendInvocations.append(request)
        registerInvocations.forEach {
            guard let response = responseStubs[request.wrapped.config] else { return }
            $0.clientQueue(self, didReceiveResponse: response, for: request)
        }
    }

    public func flush() {
        flushInvocations += 1
    }

    public func register(_ handler: APIClientQueueResponseHandler) -> APIClientQueueProcessorResponseHandlerToken {
        registerInvocations.append(handler)
        return tokenStub
    }

    public func unregister(_ token: APIClientQueueResponseHandlerToken) {
        unregisterInvocations.append(token)
    }

    public func map(_ transform: (APIClientQueueRequest) -> APIClientQueueRequest) {
        mapInvocations += 1
    }

    public var jsonCoderConfig = APIJSONCoderConfig()
}
