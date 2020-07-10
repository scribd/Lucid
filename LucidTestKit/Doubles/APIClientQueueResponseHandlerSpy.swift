//
//  APIClientQueueResponseHandlerSpy.swift
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

final class APIClientQueueProcessorResponseHandlerSpy {

    // MARK: - Records

    private(set) var resultRecords = [Result<APIClientResponse<Data>, APIError>]()

    private(set) var requestRecords = [APIClientQueueRequest]()

    // MARK: - API

    var handler: APIClientQueueProcessorResponseHandler {
        return { result, request, completion in
            self.resultRecords.append(result)
            self.requestRecords.append(request)
            completion()
        }
    }
}

final class APIClientQueueResponseHandlerSpy: APIClientQueueResponseHandler {

    // MARK: - Records

    private(set) var resultRecords = [Result<APIClientResponse<Data>, APIError>]()

    private(set) var requestRecords = [APIClientQueueRequest]()

    // MARK: - API

    func clientQueue(_ clientQueue: APIClientQueuing,
                     didReceiveResponse result: Result<APIClientResponse<Data>, APIError>,
                     for request: APIClientQueueRequest,
                     completion: @escaping () -> Void) {

        resultRecords.append(result)
        requestRecords.append(request)
        completion()
    }
}
