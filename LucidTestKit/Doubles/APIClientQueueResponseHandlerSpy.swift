//
//  APIClientQueueResponseHandlerSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 4/24/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
import Lucid

public final class APIClientQueueProcessorResponseHandlerSpy {

    // MARK: - Records

    public private(set) var resultRecords = [APIClientQueueResult<Data, APIError>]()

    public private(set) var requestRecords = [APIClientQueueRequest]()

    // MARK: - API

    public init() {
        // no-op
    }

    public var handler: APIClientQueueProcessorResponseHandler {
        return { result, request in
            self.resultRecords.append(result)
            self.requestRecords.append(request)
        }
    }
}

public final class APIClientQueueResponseHandlerSpy: APIClientQueueResponseHandler {

    // MARK: - Records

    public private(set) var resultRecords = [APIClientQueueResult<Data, APIError>]()

    public private(set) var requestRecords = [APIClientQueueRequest]()

    // MARK: - API

    public init() {
        // no-op
    }

    public func clientQueue(_ clientQueue: APIClientQueuing,
                            didReceiveResponse result: APIClientQueueResult<Data, APIError>,
                            for request: APIClientQueueRequest) {

        resultRecords.append(result)
        requestRecords.append(request)
    }
}
