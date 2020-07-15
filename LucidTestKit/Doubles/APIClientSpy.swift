//
//  APIClientSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 10/18/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

#if !RELEASE

import XCTest

#if LUCID_REACTIVE_KIT
@testable import Lucid_ReactiveKit
#else
@testable import Lucid
#endif

public final class APIClientSpy: APIClient {

    public var deduplicator: APIRequestDeduplicating = APIRequestDeduplicatorSpy()

    // MARK: - Stubs

    public var identifierStub = UUID().uuidString

    public var hostStub = "http://fake_host/"

    public var resultStubs = [APIRequestConfig: Any]()

    // MARK: - Behavior

    public var requestWillComplete: Bool = true

    public var completionDelay: TimeInterval?

    public var willHandleResponse: Bool = true

    // MARK: - Records

    public private(set) var requestRecords = [Any]()

    public private(set) var shouldHandleResponseRecords = [(APIRequestConfig, (Bool) -> Void)]()

    // MARK: - Implementation

    public init() {
        // no-op
    }

    deinit {
        DiskCache<APIClientQueueRequest>(basePath: "\(identifierStub)_client_queue").clear()
    }

    public var identifier: String {
        return identifierStub
    }

    public var host: String {
        return hostStub
    }

    public var networkClient: NetworkClient {
        return URLSession.shared
    }

    public func send(request: APIRequest<Data>, completion: @escaping (Result<APIClientResponse<Data>, APIError>) -> Void) {
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

    public func send<Model>(request: APIRequest<Model>, completion: @escaping (Result<Model, APIError>) -> Void) where Model: Decodable {
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

    public func errorPayload(from body: Data) -> APIErrorPayload? {
        return nil
    }
}

#endif
