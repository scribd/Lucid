//
//  APIAPIRequestDeduplicator.swift
//  Lucid-iOS
//
//  Created by Ibrahim Sha'ath on 3/27/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation

public protocol APIRequestDeduplicating {

    func testForDuplication(request: APIRequestConfig,
                            handler: @escaping (Result<APIClientResponse<Data>, APIError>) -> Void, completion: @escaping (Bool) -> Void)

    func applyResultToDuplicates(request: APIRequestConfig, result: Result<APIClientResponse<Data>, APIError>)
}

public final class APIRequestDeduplicator: APIRequestDeduplicating {

    private let queue: DispatchQueue
    private var _requestsInProgress = Set<APIRequestConfig>()
    private var _duplicateHandlers = [APIRequestConfig: [(Result<APIClientResponse<Data>, APIError>) -> Void]]()

    public init(label: String) {
        queue = DispatchQueue(label: "\(label):\(APIRequestDeduplicator.self):queue")
    }

    public func testForDuplication(request: APIRequestConfig,
                                   handler: @escaping (Result<APIClientResponse<Data>, APIError>) -> Void,
                                   completion: @escaping (Bool) -> Void) {
        queue.async {
            if request.deduplicate && self._requestsInProgress.contains(request) {
                var handlers = self._duplicateHandlers[request] ?? []
                handlers.append(handler)
                self._duplicateHandlers[request] = handlers
                completion(true)
            } else {
                self._requestsInProgress.insert(request)
                completion(false)
            }
        }
    }

    public func applyResultToDuplicates(request: APIRequestConfig, result: Result<APIClientResponse<Data>, APIError>) {
        queue.async {
            self._requestsInProgress.remove(request)
            let handlers = self._duplicateHandlers.removeValue(forKey: request) ?? []
            for handler in handlers {
                handler(result)
            }
        }
    }
}
