//
//  APIClientSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 10/18/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import XCTest
import Lucid

public final class APIClientSpy: APIClient {

    public var deduplicator: APIRequestDeduplicating = APIRequestDeduplicatorSpy()

    // MARK: - Stubs

    public var identifierStub = UUID().uuidString

    public var hostStub = "http://fake_host/"

    public var resultStubs = [APIRequestConfig: Any]()

    // MARK: - Behavior

    public var requestWillComplete: Bool = true

    public var completionDelay: TimeInterval?

    public var willHandleResponse: Result<Void, APIError> = .success(())

    // MARK: - Records

    public private(set) var requestRecords = [Any]()

    public private(set) var shouldHandleResponseRecords = [(APIRequestConfig, (Result<Void, APIError>) -> Void)]()

    public private(set) var shouldHandleResponseAsyncRecords = [APIRequestConfig]()

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
            completion(.failure(.api(httpStatusCode: 500, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false))))
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

    public func send(request: APIRequest<Data>) async -> Result<APIClientResponse<Data>, APIError> {
        requestRecords.append(request as Any)
        guard let resultStub = resultStubs[request.config] as? Result<APIClientResponse<Data>, APIError> else {
            XCTFail("Expected stub for request with path: \(request.config.path.description)")
            return .failure(.api(httpStatusCode: 500, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)))
        }
        if requestWillComplete {
            if let completionDelay = completionDelay {
                try? await Task.sleep(nanoseconds: NSEC_PER_SEC * UInt64(completionDelay))
                return resultStub
            } else {
                return resultStub
            }
        } else {
            return .failure(APIError.network(.cancelled))
        }
    }

    public func send<Model>(request: APIRequest<Model>, completion: @escaping (Result<Model, APIError>) -> Void) where Model: Decodable {
        requestRecords.append(request as Any)
        guard let resultStub = resultStubs[request.config] as? Result<Model, APIError> else {
            completion(.failure(.api(httpStatusCode: 500, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false))))
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

    public func send<Model>(request: APIRequest<Model>) async -> Result<Model, APIError> where Model: Decodable {
        requestRecords.append(request as Any)
        guard let resultStub = resultStubs[request.config] as? Result<Model, APIError> else {
            XCTFail("Expected stub for request with path: \(request.config.path.description)")
            return .failure(.api(httpStatusCode: 500, errorPayload: nil, response: APIClientResponse(data: Data(), cachedResponse: false)))
        }
        if requestWillComplete {
            if let completionDelay = completionDelay {
                try? await Task.sleep(nanoseconds: NSEC_PER_SEC * UInt64(completionDelay))
                return resultStub
            } else {
                return resultStub
            }
        } else {
            return .failure(APIError.network(.cancelled))
        }
    }

    public func shouldHandleResponse(for requestConfig: APIRequestConfig, completion: @escaping (Result<Void, APIError>) -> Void) {
        shouldHandleResponseRecords.append((requestConfig, completion))
        completion(willHandleResponse)
    }

    public func shouldHandleResponse(for requestConfig: APIRequestConfig) async -> Result<Void, APIError> {
        shouldHandleResponseAsyncRecords.append((requestConfig))
        return willHandleResponse
    }

    public func errorPayload(from body: Data) -> APIErrorPayload? {
        return nil
    }
}
