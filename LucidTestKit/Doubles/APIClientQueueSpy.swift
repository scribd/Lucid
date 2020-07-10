//
//  APIClientQueueSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 10/19/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

#if LUCID_REACTIVE_KIT
@testable import Lucid_ReactiveKit
#else
@testable import Lucid
#endif

final class APIClientQueueSpy: APIClientQueuing, APIClientQueueFlushing {

    // MARK: - Records

    private(set) var appendInvocations = [APIClientQueueRequest]()

    private(set) var flushInvocations = 0

    private(set) var registerInvocations = [APIClientQueueResponseHandler]()

    private(set) var mapInvocations = 0

    private(set) var unregisterInvocations = [UUID]()

    // MARK: - Stubs

    var tokenStub = UUID()

    var responseStubs: [APIRequestConfig: Result<APIClientResponse<Data>, APIError>] = [:]

    // MARK: - API

    func append(_ request: APIClientQueueRequest) {
        appendInvocations.append(request)
        registerInvocations.forEach {
            guard let response = responseStubs[request.wrapped.config] else { return }
            $0.clientQueue(self, didReceiveResponse: response, for: request) {}
        }
    }

    func flush() {
        flushInvocations += 1
    }

    func register(_ handler: APIClientQueueResponseHandler) -> APIClientQueueProcessorResponseHandlerToken {
        registerInvocations.append(handler)
        return tokenStub
    }

    func unregister(_ token: APIClientQueueResponseHandlerToken) {
        unregisterInvocations.append(token)
    }

    func map(_ transform: (APIClientQueueRequest) -> APIClientQueueRequest) {
        mapInvocations += 1
    }
}
