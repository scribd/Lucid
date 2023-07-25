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

    func isDuplicated(request: APIRequestConfig) async -> Bool

    func waitForDuplicated(request: APIRequestConfig) async -> Result<APIClientResponse<Data>, APIError>

    func applyResultToDuplicates(request: APIRequestConfig, result: Result<APIClientResponse<Data>, APIError>)
}

public final class APIRequestDeduplicator: APIRequestDeduplicating {

    private let queue: DispatchQueue
    private let asyncTaskQueue: AsyncTaskQueue = AsyncTaskQueue()
    private var _requestsInProgress = Set<APIRequestConfig>()
    private var _duplicateHandlers = [APIRequestConfig: [(Result<APIClientResponse<Data>, APIError>) -> Void]]()
    private var _asyncDuplicateContinuations = [APIRequestConfig: [CheckedContinuation<Result<APIClientResponse<Data>, APIError>, Never>]]()

    public init(label: String) {
        queue = DispatchQueue(label: "\(label):\(APIRequestDeduplicator.self):queue")
    }

    public func testForDuplication(request: APIRequestConfig,
                                   handler: @escaping (Result<APIClientResponse<Data>, APIError>) -> Void,
                                   completion: @escaping (Bool) -> Void) {
        Task {
            try? await asyncTaskQueue.enqueue { operationCompletion in
                defer { operationCompletion() }
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
    }

    public func isDuplicated(request: APIRequestConfig) async -> Bool {
        do {
            return try await asyncTaskQueue.enqueue { operationCompletion in
                defer { operationCompletion() }
                return request.deduplicate && self._requestsInProgress.contains(request)
            }
        } catch {
            Logger.log(.error, "\(APIRequestDeduplicator.self) failed to enqueue task")
            return false
        }
    }

    public func waitForDuplicated(request: APIRequestConfig) async -> Result<APIClientResponse<Data>, APIError> {
        do {
            return try await asyncTaskQueue.enqueue { operationCompletion in
                var continuations = self._asyncDuplicateContinuations[request] ?? []
                return await withCheckedContinuation { continuation in
                    continuations.append(continuation)
                    self._asyncDuplicateContinuations[request] = continuations
                    operationCompletion()
                }
            }
        } catch {
            return .failure(.other("\(APIRequestDeduplicator.self) failed to enqueue task"))
        }
    }

    public func applyResultToDuplicates(request: APIRequestConfig, result: Result<APIClientResponse<Data>, APIError>) {
        Task {
            try? await asyncTaskQueue.enqueue { completion in
                defer { completion() }
                self._requestsInProgress.remove(request)
                let handlers = self._duplicateHandlers.removeValue(forKey: request) ?? []
                for handler in handlers {
                    handler(result)
                }
                let continuations = self._asyncDuplicateContinuations.removeValue(forKey: request) ?? []
                for continuation in continuations {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}
