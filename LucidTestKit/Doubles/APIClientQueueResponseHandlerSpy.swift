//
//  APIClientQueueResponseHandlerSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 4/24/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

@testable import Lucid

final class APIClientQueueProcessorResponseHandlerSpy {
    
    // MARK: - Records
    
    private(set) var resultRecords = [Result<Data, APIError>]()
    
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
    
    private(set) var resultRecords = [Result<Data, APIError>]()
    
    private(set) var requestRecords = [APIClientQueueRequest]()
    
    // MARK: - API
    
    func clientQueue(_ clientQueue: APIClientQueuing,
                     didReceiveResponse result: Result<Data, APIError>,
                     for request: APIClientQueueRequest,
                     completion: @escaping () -> Void) {
        
        resultRecords.append(result)
        requestRecords.append(request)
        completion()
    }
}
