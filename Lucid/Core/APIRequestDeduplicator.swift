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
                                   handler: @escaping (Result<APIClientResponse<Data>, APIError>) -> Void, completion: @escaping (Bool) -> Void) {

        // keep response off internal data queue
        var isADuplicate = false
        defer { completion(isADuplicate) }

        queue.sync {
            if request.deduplicate && self._requestsInProgress.contains(request) {
                var handlers = self._duplicateHandlers[request] ?? []
                handlers.append(handler)
                self._duplicateHandlers[request] = handlers
                isADuplicate = true
            } else {
                self._requestsInProgress.insert(request)
                isADuplicate = false
            }
        }
    }

    public func applyResultToDuplicates(request: APIRequestConfig, result: Result<APIClientResponse<Data>, APIError>) {

        // keep handler execution off internal data queue
        var handlers = [(Result<APIClientResponse<Data>, APIError>) -> Void]()
        defer { handlers.forEach { $0(result) } }

        queue.sync {
            self._requestsInProgress.remove(request)
            handlers = self._duplicateHandlers.removeValue(forKey: request) ?? []
        }
    }
}
