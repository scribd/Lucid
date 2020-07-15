//
//  APIClientQueueResponseHandlerSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 4/24/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

#if !RELEASE

import Foundation

#if LUCID_REACTIVE_KIT
@testable import Lucid_ReactiveKit
#else
@testable import Lucid
#endif

public final class APIClientQueueProcessorResponseHandlerSpy {

    // MARK: - Records

    public private(set) var resultRecords = [Result<APIClientResponse<Data>, APIError>]()

    public private(set) var requestRecords = [APIClientQueueRequest]()

    // MARK: - API

    public init() {
        // no-op
    }

    public var handler: APIClientQueueProcessorResponseHandler {
        return { result, request, completion in
            self.resultRecords.append(result)
            self.requestRecords.append(request)
            completion()
        }
    }
}

public final class APIClientQueueResponseHandlerSpy: APIClientQueueResponseHandler {

    // MARK: - Records

    public private(set) var resultRecords = [Result<APIClientResponse<Data>, APIError>]()

    public private(set) var requestRecords = [APIClientQueueRequest]()

    // MARK: - API

    public init() {
        // no-op
    }

    public func clientQueue(_ clientQueue: APIClientQueuing,
                            didReceiveResponse result: Result<APIClientResponse<Data>, APIError>,
                            for request: APIClientQueueRequest,
                            completion: @escaping () -> Void) {

        resultRecords.append(result)
        requestRecords.append(request)
        completion()
    }
}

#endif
