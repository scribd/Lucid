//
//  APIClientSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 10/18/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import XCTest

@testable import Lucid

final class APIClientSpy: APIClient {

    var deduplicator: APIRequestDeduplicating = APIRequestDeduplicatorSpy()
    
    // MARK: - Stubs
    
    var identifierStub = UUID().uuidString
    
    var hostStub = "http://fake_host/"
    
    var resultStubs = [APIRequestConfig: Any]()
    
    // MARK: - Behavior
    
    var requestWillComplete: Bool = true
    
    var completionDelay: TimeInterval?

    var willHandleResponse: Bool = true
    
    // MARK: - Records
    
    private(set) var requestRecords = [Any]()

    private(set) var shouldHandleResponseRecords = [(APIRequestConfig, (Bool) -> Void)]()

    // MARK: - Implementation
    
    deinit {
        DiskCache<APIClientQueueRequest>(basePath: "\(identifierStub)_client_queue").clear()
    }
    
    var identifier: String {
        return identifierStub
    }
    
    var host: String {
        return hostStub
    }
    
    var networkClient: NetworkClient {
        return URLSession.shared
    }
    
    func send(request: APIRequest<Data>, completion: @escaping (Result<APIClientResponse<Data>, APIError>) -> Void) {
        requestRecords.append(request as Any)
        guard let resultStub = resultStubs[request.config] as? Result<APIClientResponse<Data>, APIError> else {
            completion(.failure(.api(httpStatusCode: 500, errorPayload: nil)))
            XCTFail("Expected stub for request with path: \(request.config.path.description)")
            return
        }
        if requestWillComplete {
            if let completionDelay = completionDelay {
                DispatchQueue.main.asyncAfter(deadline: .now() + completionDelay) {
                    completion(resultStub)
                }
            } else {
                completion(resultStub)
            }
        }
    }
    
    func send<Model>(request: APIRequest<Model>, completion: @escaping (Result<Model, APIError>) -> Void) where Model: Decodable {
        requestRecords.append(request as Any)
        guard let resultStub = resultStubs[request.config] as? Result<Model, APIError> else {
            completion(.failure(.api(httpStatusCode: 500, errorPayload: nil)))
            XCTFail("Expected stub for request with path: \(request.config.path.description)")
            return
        }
        if requestWillComplete {
            if let completionDelay = completionDelay {
                DispatchQueue.main.asyncAfter(deadline: .now() + completionDelay) {
                    completion(resultStub)
                }
            } else {
                completion(resultStub)
            }
        }
    }

    public func shouldHandleResponse(for requestConfig: APIRequestConfig, completion: @escaping (Bool) -> Void) {
        shouldHandleResponseRecords.append((requestConfig, completion))
        completion(willHandleResponse)
    }
    
    func errorPayload(from body: Data) -> APIErrorPayload? {
        return nil
    }
}
