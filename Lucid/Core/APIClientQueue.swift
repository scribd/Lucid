//
//  APIClientQueue.swift
//  Lucid
//
//  Created by Stephane Magne on 3/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Constants

private extension APIClientQueue {
    enum Constants {
        static func diskCacheBasePath(_ identifier: String) -> String {
            return "\(identifier)_client_queue_9_8_0"
        }
    }
}

private extension APIClientQueueProcessor {
    enum Constants {
        static let cacheKey = "APIClientQueueProcessorCacheKey"

        static func diskCacheBasePath(_ identifier: String) -> String {
            return "\(identifier)_processor_9_8_0"
        }
    }
}

// MARK: - Request

/// Request passed to the `APIClientQueue`.
///
/// - Warning: This object is being stored to disk. Any breaking change to its serialization/deserialization
///            should be shipped with an appropriate migration in order to not lose users' requests pushed
///            prior to the update.
public struct APIClientQueueRequest: Equatable, Codable {

    public var wrapped: APIRequest<Data>

    public let identifiers: Data?

    public let timestamp: UInt64

    public let token: UUID

    public var isBarrier: Bool {
        switch wrapped.config.queueingStrategy.synchronization {
        case .barrier:
            return true
        case .concurrent:
            return false
        }
    }

    public var retryOnNetworkInterrupt: Bool {
        return wrapped.config.queueingStrategy.retryPolicy.contains(.onNetworkInterrupt)
    }

    public var retryOnRequestTimeout: Bool {
        return wrapped.config.queueingStrategy.retryPolicy.contains(.onRequestTimeout)
    }

    public var retryErrorCodes: [Int]? {
        let codes: [Int] = wrapped.config.queueingStrategy.retryPolicy.compactMap { policy in
            switch policy {
            case .onCustomErrorCodes(let customCodes):
                return customCodes
            case .onRequestTimeout,
                 .onNetworkInterrupt,
                 .onAllErrorCodesExcept:
                return nil
            }
        }.flatMap { $0 }

        return codes.isEmpty ? nil : codes
    }

    public var doNotRetryErrorCodes: [Int]? {
        let codes: [Int] = wrapped.config.queueingStrategy.retryPolicy.compactMap { policy in
            switch policy {
            case .onAllErrorCodesExcept(let exceptingCodes):
                return exceptingCodes
            case .onRequestTimeout,
                 .onNetworkInterrupt,
                 .onCustomErrorCodes:
                return nil
            }
        }.flatMap { $0 }

        return codes.isEmpty ? nil : codes
    }

    public init(wrapping request: APIRequest<Data>, identifiers: Data? = nil) {
        self.wrapped = request
        self.identifiers = identifiers
        self.timestamp = timestampInNanoseconds()
        self.token = UUID()
    }
}

// MARK: - Handler

public enum APIClientQueueResult<T, E: Error> {
    case success(APIClientResponse<T>)
    case aborted
    case failure(E)
}

/// Object in charge of handling the response of a request.
public protocol APIClientQueueResponseHandler: AnyObject {

    /// Called by the `APIClientQueueProcessor` when a response has been received for a specific request.
    ///
    /// - Parameters:
    ///     - clientQueue: Client queue which has received the response.
    ///     - result: Either the responded data or an error.
    ///     - request: `APIClientQueueRequest` associated to the response.
    func clientQueue(_ clientQueue: APIClientQueuing,
                     didReceiveResponse result: APIClientQueueResult<Data, APIError>,
                     for request: APIClientQueueRequest)
}

/// Response Handler registration token.
public typealias APIClientQueueResponseHandlerToken = UUID

// MARK: - Client Queue

/// An API client able to run a FIFO queue of requests persisted on disk.
///
/// - Warning:
///     - Running two instances for the same client in parallel isn't supported at the moment.
public protocol APIClientQueuing: AnyObject {

    /// Adds a request to the queue.
    ///
    /// - Parameters:
    ///     - request: `APIRequest` to add in front of the queue.
    func append(_ request: APIClientQueueRequest) async

    /// Registers a response handler which will be notified when the client received a response.
    ///
    /// - Parameters:
    ///     - handler: `APIClientQueueResponseHandler` to register.
    /// - Returns: The handler's registration token.
    @discardableResult
    func register(_ handler: APIClientQueueResponseHandler) async -> APIClientQueueResponseHandlerToken

    /// Unregister a response handler based on its token.
    ///
    /// - Parameters:
    ///     - token: Token of the handler to unregister.
    func unregister(_ token: APIClientQueueResponseHandlerToken) async

    /// Transform each elements of the queue.
    ///
    /// - Parameters:
    ///     - transform: Block performing the transformation.
    func map(_ transform: @escaping (APIClientQueueRequest) -> APIClientQueueRequest) async
}

protocol APIClientPriorityQueuing {

    /// Adds a request to the front of the queue. This should only be called to reschedule the request after a send failure.
    ///
    /// - Parameters:
    ///     - request: `APIRequest` to add in front of the queue.
    func prepend(_ request: APIClientQueueRequest) async

    /// Remove requests from the queue based on a passed in filter.
    ///
    /// - Parameters:
    ///     - filter: Logical filter to identify requests to remove. Return true to remove.
    /// - Returns: The removed requests
    func removeRequests(matching: @escaping (APIClientQueueRequest) -> Bool) async -> [APIClientQueueRequest]
}

public protocol APIClientQueueFlushing {

    /// Run the requests from the queue consecutively.
    ///
    /// - Note:
    ///     - Each request is popped and ran consecutively in order of insertion (FIFO).
    ///     - When a request fails because the device isn't connected to the internet,
    ///       it is up to the scheduler to handle the timing of the retry.
    ///       The default scheduler retries after 15 seconds.
    ///     - The scheduler will also inform the processor when to attempt the next request,
    ///       at which time it will alert the queue and the request will be popped off.
    func flush() async
}

public final class APIClientQueue: NSObject {

    public typealias UniquingFunction = (APIClientQueueRequest) -> String

    public enum Strategy {
        case `default`

        /// - Warning:`prepend` only writes if no request was appended with the same key.
        ///            Other components should not assume that a prepend will always add to the queue.
        case uniquing(_: UniquingFunction)
    }

    private static var instancesDispatchQueue = DispatchQueue(label: "\(APIClientQueue.self):instances")
    private static var instances = NSMapTable<NSString, APIClientQueue>.strongToWeakObjects()

    /// - Warning: This key is being stored to disk. Any change to it should be shipped
    ///            with an appropriate migration in order to not lose users' requests pushed
    ///            prior to the update.
    private static let uniquingCacheKey = "\(APIClientQueue.self)_uniquing_cache_key"

    // MARK: Dependencies

    enum Cache {
        actor UniquingCache {
            var orderingSetCache: DiskCaching<OrderedSet<String>>
            var valueCache: DiskCaching<APIClientQueueRequest>

            init(orderingSetCache: DiskCaching<OrderedSet<String>>, valueCache: DiskCaching<APIClientQueueRequest>) {
                self.orderingSetCache = orderingSetCache
                self.valueCache = valueCache
            }
        }

        case `default`(DiskQueue<APIClientQueueRequest>)
        case uniquing(UniquingCache, UniquingFunction)
    }

    private let cache: Cache
    private let processor: APIClientQueueProcessing

    // MARK: Inits

    init(cache: Cache,
         processor: APIClientQueueProcessing) {

        self.cache = cache
        self.processor = processor
        super.init()
        self.processor.delegate = self
    }

    /// Create a new client queue the first time the identifier is used, then, returns the existing one.
    ///
    /// - Parameters:
    ///     - identifier: Identifier used to describe the queue.
    ///     - client: Client to use to process the requests pushed to the queue.
    ///     - processor: `APIClientQueueProcessor` used to run the requests from the queue.
    public static func clientQueue(for identifier: String,
                                   client: APIClient,
                                   scheduler: APIClientQueueScheduling,
                                   strategy: Strategy = .default) -> APIClientQueue {

        let queueIdentifier = "\(client.identifier)_\(identifier)"

        return APIClientQueue.instancesDispatchQueue.sync {
            if let instance = APIClientQueue.instances.object(forKey: queueIdentifier as NSString) {
                Logger.log(.error, "\(APIClientQueue.self): Instance for identifier \(queueIdentifier) already exists. The scheduler is ignored.", assert: true)
                return instance
            } else {

                let processor = APIClientQueueProcessor(identifier: queueIdentifier,
                                                        client: client,
                                                        scheduler: scheduler)

                let codingContext: CodingContext = .clientQueueRequest

                let cache: Cache = {
                    switch strategy {
                    case .default:
                        let diskCache = DiskCache<APIClientQueueRequest>(basePath: Constants.diskCacheBasePath(queueIdentifier),
                                                                         codingContext: codingContext)
                        return .default(DiskQueue(diskCache: diskCache.caching))
                    case .uniquing(let uniquingFunction):
                        let orderingSetCache = DiskCache<OrderedSet<String>>(basePath: Constants.diskCacheBasePath(queueIdentifier + "_ordering"),
                                                                     codingContext: codingContext)
                        let valueCache = DiskCache<APIClientQueueRequest>(basePath: Constants.diskCacheBasePath(queueIdentifier + "_values"),
                                                                          codingContext: codingContext)
                        let uniquingCache = Cache.UniquingCache(orderingSetCache: orderingSetCache.caching, valueCache: valueCache.caching)
                        return .uniquing(uniquingCache,
                                         uniquingFunction)
                    }
                }()

                let clientQueue = APIClientQueue(cache: cache,
                                                 processor: processor)

                APIClientQueue.instances.setObject(clientQueue, forKey: queueIdentifier as NSString)

                Logger.log(.info, "\(APIClientQueue.self): Created new instance for identifier \(queueIdentifier).")

                return clientQueue
            }
        }
    }
}

// MARK: APIClientQueuing

extension APIClientQueue: APIClientQueuing {

    public func append(_ request: APIClientQueueRequest) async {
        let config = await processor.prepareRequest(request.wrapped.config)
        var request = request
        request.wrapped.config = config

        switch self.cache {
        case .default(let queue):
            queue.append(request)
            await self.processor.didEnqueueNewRequest()
        case .uniquing(let uniquingCache, let uniquingFunction):
            let key = uniquingFunction(request)

            let requestCopy = request

            var orderingSet = await uniquingCache.orderingSetCache[APIClientQueue.uniquingCacheKey] ?? OrderedSet<String>()
            orderingSet.append(key)
            await uniquingCache.orderingSetCache[APIClientQueue.uniquingCacheKey] = orderingSet
            if let existingRequest = await uniquingCache.valueCache[key] {
                await self.processor.abortRequest(existingRequest)
            }
            await uniquingCache.valueCache[key] = requestCopy
            await self.processor.didEnqueueNewRequest()
        }
    }

    @discardableResult
    public func register(_ handler: APIClientQueueResponseHandler) async -> APIClientQueueResponseHandlerToken {
        return await processor.register { [weak self] response, request in
            guard let strongSelf = self else { return }
            handler.clientQueue(strongSelf, didReceiveResponse: response, for: request)
        }
    }

    public func unregister(_ token: APIClientQueueResponseHandlerToken) async {
        await processor.unregister(token)
    }

    public func map(_ transform: @escaping (APIClientQueueRequest) -> APIClientQueueRequest) async {
        switch cache {
        case .default(let queue):
            queue.map(transform)
        case .uniquing(let uniquingCache, let uniquingFunction):
            let orderingSet = await uniquingCache.orderingSetCache[APIClientQueue.uniquingCacheKey] ?? OrderedSet<String>()
            guard orderingSet.isEmpty == false else { return }

            var newOrderingSet = OrderedSet<String>()
            for key in orderingSet {
                guard let value = await uniquingCache.valueCache[key] else {
                    Logger.log(.error, "\(APIClientQueue.self) found no cached value", assert: true)
                    continue
                }
                await uniquingCache.valueCache[key] = nil
                let newValue = transform(value)
                let newKey = uniquingFunction(newValue)
                await uniquingCache.valueCache[newKey] = newValue
                newOrderingSet.append(newKey)
            }
            await uniquingCache.orderingSetCache[APIClientQueue.uniquingCacheKey] = newOrderingSet
        }
    }
}

// MARK: APIClientPriorityQueuing

extension APIClientQueue: APIClientPriorityQueuing {

    func prepend(_ request: APIClientQueueRequest) async {
        let config = await processor.prepareRequest(request.wrapped.config)
        var request = request
        request.wrapped.config = config

        switch self.cache {
        case .default(let queue):
            queue.prepend(request)
        case .uniquing(let uniquingCache, let uniquingFunction):
            let key = uniquingFunction(request)

            let requestCopy = request

            var orderingSet = await uniquingCache.orderingSetCache[APIClientQueue.uniquingCacheKey] ?? OrderedSet<String>()
            guard orderingSet.contains(key) == false else {
                await self.processor.abortRequest(requestCopy)
                return
            }
            orderingSet.prepend(key)
            await uniquingCache.orderingSetCache[APIClientQueue.uniquingCacheKey] = orderingSet
            await uniquingCache.valueCache[key] = requestCopy
        }
    }

    func removeRequests(matching: @escaping (APIClientQueueRequest) -> Bool) async -> [APIClientQueueRequest] {
        var removedElements: [APIClientQueueRequest] = []

        switch cache {
        case .default(let queue):
            queue.filter { request in
                if matching(request) {
                    removedElements.append(request)
                    return false
                } else {
                    return true
                }
            }
        case .uniquing(let uniquingCache, _):
            var removedRequests: [APIClientQueueRequest] = []
            var orderingSet = await uniquingCache.orderingSetCache[APIClientQueue.uniquingCacheKey] ?? OrderedSet<String>()
            for key in orderingSet {
                guard let request = await uniquingCache.valueCache[key] else { continue }
                guard matching(request) else { continue }
                removedRequests.append(request)
                orderingSet.remove(key)
                await uniquingCache.valueCache[key] = nil
            }
            await uniquingCache.orderingSetCache[APIClientQueue.uniquingCacheKey] = orderingSet
            removedElements = removedRequests
        }

        return removedElements
    }
}

// MARK: APIClientQueueFlushing

extension APIClientQueue: APIClientQueueFlushing {

    public func flush() async {
        await self.processor.flush()
    }
}

// MARK: APIClientQueueProcessorDelegate

extension APIClientQueue: APIClientQueueProcessorDelegate {

    func nextRequest() async -> APIClientQueueRequest? {
        switch cache {
        case .default(let queue):
            return queue.dropFirst()
        case .uniquing(let uniquingCache, _):
            guard var orderingSet = await uniquingCache.orderingSetCache[APIClientQueue.uniquingCacheKey],
                  let key = orderingSet.popFirst() else { return nil }

            await uniquingCache.orderingSetCache[APIClientQueue.uniquingCacheKey] = orderingSet

            guard let value = await uniquingCache.valueCache[key] else {
                Logger.log(.error, "\(APIClientQueue.self) found no cached value", assert: true)
                return nil
            }
            await uniquingCache.valueCache[key] = nil
            return value
        }
    }
}

// MARK: - Processor

/// A mechanism that will process API requests one at a time.
/// The timing is handled by an injected scheduler.
///
/// - Warning:
///     - Make sure `APIClient`'s implementation handles `APIError.networkConnectionFailure`
///       correctly since it's used by the queueing retry strategy.
protocol APIClientQueueProcessing: AnyObject {

    func didEnqueueNewRequest() async

    func flush() async

    func register(_ handler: @escaping APIClientQueueProcessorResponseHandler) async -> APIClientQueueProcessorResponseHandlerToken

    func unregister(_ token: APIClientQueueProcessorResponseHandlerToken) async

    func abortRequest(_ request: APIClientQueueRequest) async

    func prepareRequest(_ requestConfig: APIRequestConfig) async -> APIRequestConfig

    var delegate: APIClientQueueProcessorDelegate? { get set }
}

public typealias APIClientQueueProcessorResponseHandlerToken = UUID
public typealias APIClientQueueProcessorResponseHandler = (
    _ result: APIClientQueueResult<Data, APIError>,
    _ request: APIClientQueueRequest
) -> Void

protocol APIClientQueueProcessorDelegate: AnyObject, APIClientPriorityQueuing {

    func nextRequest() async -> APIClientQueueRequest?
}

final class APIClientQueueProcessor {

    actor ResponseHandlers {

        private var values: OrderedDictionary<APIClientQueueProcessorResponseHandlerToken, APIClientQueueProcessorResponseHandler>

        init(values: [APIClientQueueProcessorResponseHandler]) {
            self.values = OrderedDictionary(values.map { (UUID(), $0) })
        }

        func get() -> [APIClientQueueProcessorResponseHandler] {
            return self.values.orderedValues
        }

        func append(token: APIClientQueueProcessorResponseHandlerToken, handler: @escaping APIClientQueueProcessorResponseHandler) {
            self.values.append(key: token, value: handler)
        }

        func remove(at token: APIClientQueueProcessorResponseHandlerToken) {
            self.values[token] = nil
        }
    }

    private let client: APIClient
    private let scheduler: APIClientQueueScheduling
    private let diskCache: DiskCaching<APIClientQueueRequest>

    private var _responseHandlers: ResponseHandlers

    private let operationQueue: AsyncTaskQueue

    private let lock = NSRecursiveLock(name: "\(APIClientQueueProcessor.self)")

    #if canImport(UIKit) && os(iOS)
    private let _backgroundTaskManager: BackgroundTaskManaging
    #endif

    weak var delegate: APIClientQueueProcessorDelegate? {
        didSet {
            guard let delegate = delegate else { return }
            lock.lock()
            defer { lock.unlock() }

            let keys = diskCache.keys()
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for key in keys {
                        guard let cachedRequest = diskCache[key] else { continue }
                        group.addTask {
                            await delegate.prepend(cachedRequest)
                            self.diskCache[key] = nil
                        }
                    }
                }
            }
        }
    }

    #if canImport(UIKit) && os(iOS)

    init(client: APIClient,
         backgroundTaskManager: BackgroundTaskManaging,
         scheduler: APIClientQueueScheduling,
         diskCache: DiskCaching<APIClientQueueRequest>,
         responseHandlers: [APIClientQueueProcessorResponseHandler],
         operationQueue: AsyncTaskQueue = AsyncTaskQueue()) {

        self.client = client
        self._backgroundTaskManager = backgroundTaskManager
        self.scheduler = scheduler
        self.diskCache = diskCache
        self._responseHandlers = ResponseHandlers(values: responseHandlers)
        self.operationQueue = operationQueue
        self.scheduler.delegate = self
    }

    /// Initializer
    ///
    /// - Parameters:
    ///     - identifier: A unique string value that will seed the cache file path.
    ///     - client: `APIClient` used to run the requests from the queue.
    ///     - scehduler: Scheduling object that tells the processor when to process the next request.
    ///     - responseHandlers: Custom handlers that can respond to a successful APIClientQueueRequest.
    convenience init(identifier: String,
                     client: APIClient,
                     scheduler: APIClientQueueScheduling,
                     responseHandlers: [APIClientQueueProcessorResponseHandler] = []) {

        let diskCache = DiskCache<APIClientQueueRequest>(basePath: Constants.diskCacheBasePath(identifier),
                                                         codingContext: .clientQueueRequest)

        self.init(client: client,
                  backgroundTaskManager: BackgroundTaskManager(),
                  scheduler: scheduler,
                  diskCache: diskCache.caching,
                  responseHandlers: responseHandlers)
    }

    #else

    init(client: APIClient,
         scheduler: APIClientQueueScheduling,
         diskCache: DiskCaching<APIClientQueueRequest>,
         responseHandlers: [APIClientQueueProcessorResponseHandler],
         operationQueue: AsyncTaskQueue = AsyncTaskQueue()) {

        self.client = client
        self.scheduler = scheduler
        self.diskCache = diskCache
        self._responseHandlers = ResponseHandlers(values: responseHandlers)
        self.operationQueue = operationQueue
        self.scheduler.delegate = self
    }

    /// Initializer
    ///
    /// - Parameters:
    ///     - identifier: A unique string value that will seed the cache file path.
    ///     - client: `APIClient` used to run the requests from the queue.
    ///     - scehduler: Scheduling object that tells the processor when to process the next request.
    ///     - responseHandlers: Custom handlers that can respond to a successful APIClientQueueRequest.
    convenience init(identifier: String,
                     client: APIClient,
                     scheduler: APIClientQueueScheduling,
                     responseHandlers: [APIClientQueueProcessorResponseHandler] = []) {

        let diskCache = DiskCache<APIClientQueueRequest>(basePath: Constants.diskCacheBasePath(identifier),
                                                         codingContext: .clientQueueRequest)

        self.init(client: client,
                  scheduler: scheduler,
                  diskCache: diskCache.caching,
                  responseHandlers: responseHandlers)
    }

    #endif
}

// MARK: APIClientQueueProcessing

extension APIClientQueueProcessor: APIClientQueueProcessing {

    func register(_ handler: @escaping APIClientQueueProcessorResponseHandler) async -> APIClientQueueProcessorResponseHandlerToken {
        let token = UUID()
        await self._responseHandlers.append(token: token, handler: handler)
        return token
    }

    func unregister(_ token: APIClientQueueProcessorResponseHandlerToken) async {
        await self._responseHandlers.remove(at: token)
    }

    func abortRequest(_ request: APIClientQueueRequest) async {
        let handlers = await self._responseHandlers.get()
        self.forwardDidReceiveResponseToHandlers(.aborted(request), handlers: handlers)
    }

    func didEnqueueNewRequest() async {
        await scheduler.didEnqueueNewRequest()
    }

    func flush() async {
        await scheduler.flush()
    }

    func prepareRequest(_ requestConfig: APIRequestConfig) async -> APIRequestConfig {
        return await client.prepareRequest(requestConfig)
    }
}

// MARK: APIClientQueueSchedulerDelegate

extension APIClientQueueProcessor: APIClientQueueSchedulerDelegate {

    @discardableResult
    func processNext() async -> APIClientQueueSchedulerProcessNextResult {
        guard await operationQueue.isLastBarrier == false else {
            return .didNotProcess
        }

        guard let request = await delegate?.nextRequest() else {
            return .didNotProcess
        }

        diskCache[request.token.uuidString] = request

        let operation: () async -> Void = {
            await self._process(request)
            self.diskCache[request.token.uuidString] = nil
        }
        if request.isBarrier {
            try? await operationQueue.enqueueBarrier { operationCompletion in
                await operation()
                operationCompletion()
            }
        } else {
            try? await operationQueue.enqueue {
                await operation()
            }
        }

        if request.isBarrier {
            return .processedBarrier
        } else {
            return .processedConcurrent
        }
    }
}

// MARK: Private

private extension APIClientQueueProcessor {

    func _process(_ request: APIClientQueueRequest) async {

        #if canImport(UIKit) && os(iOS)
        let taskID: UUID?
        var backgroundTask: Task<Void, Never>?
        if request.wrapped.config.background {
            taskID = _backgroundTaskManager.start {
                backgroundTask = Task {
                    Logger.log(.warning, "\(APIClientQueueProcessor.self): Background task expired.")
                    await self._complete(.backgroundSessionExpired(request))
                }
            }
        } else {
            taskID = nil
        }
        #endif

        let requestDescription = client.description(for: request.wrapped.config)
        Logger.log(.info, "\(APIClientQueueProcessor.self): Processing request: \(requestDescription)")

        let result = await client.send(request: request.wrapped)

        #if canImport(UIKit) && os(iOS)
        if let taskID = taskID, self._backgroundTaskManager.stop(taskID) == false {
            Logger.log(.warning, "\(APIClientQueueProcessor.self): Received response after background task timed out: \(requestDescription)")
            return
        }
        backgroundTask?.cancel()
        backgroundTask = nil
        #endif

        switch result {
        case .success(let response):
            Logger.log(.info, "\(APIClientQueueProcessor.self): Request succeeded: \(requestDescription)")
            await self._complete(.success(response, request))

        case .failure(let apiError):
            Logger.log(.info, "\(APIClientQueueProcessor.self): Request \(requestDescription) failed: \(apiError)")
            await self._complete(.apiError(apiError, request))
        }
    }

    func cacheRequest(_ request: APIClientQueueRequest) {
        diskCache[Constants.cacheKey] = request
    }

    private enum ProcessingResult {
        case success(_ response: APIClientResponse<Data>, _ request: APIClientQueueRequest)
        case aborted(_ request: APIClientQueueRequest)
        case apiError(_ apiError: APIError, _ request: APIClientQueueRequest)
        case backgroundSessionExpired(_ request: APIClientQueueRequest)
    }

    private func _complete(_ result: ProcessingResult) async {

        let responseHandlers = await self._responseHandlers.get()
        forwardDidReceiveResponseToHandlers(result, handlers: responseHandlers)

        let didSucceed: Bool
        switch result {
        case .success:
            didSucceed = true
        case .aborted:
            Logger.log(.error, "\(APIClientQueueProcessor.self): Processor should not be aborting requests in flight.", assert: true)
            didSucceed = true
        case .apiError(let apiError, let request):
            await _handleAPIError(apiError, request: request, responseHandlers: responseHandlers)
            didSucceed = false
        case .backgroundSessionExpired(let request):
            Logger.log(.info, "\(APIClientQueueProcessor.self): Background session expired. Will reschedule request.")
            await self.delegate?.prepend(request)
            didSucceed = false
        }

        if didSucceed {
            await self.scheduler.requestDidSucceed()
        } else {
            await self.scheduler.requestDidFail()
        }
    }

    private func _handleAPIError(_ apiError: APIError, request: APIClientQueueRequest, responseHandlers: [APIClientQueueProcessorResponseHandler]) async {

        let removeRequestsMatching: (@escaping (APIClientQueueRequest) -> Bool) async -> Void = { criteria in
            /// Any requests in the queue that expect to fail and not retry on .networkConnectionFailure should be sent the failure right away.
            if let requestsToCancel = await self.delegate?.removeRequests(matching: criteria) {
                Logger.log(.info, "\(APIClientQueueProcessor.self): Removing \(requestsToCancel.count) from the queue on network or timeout error.")
                for requestToCancel in requestsToCancel {
                    self.forwardDidReceiveResponseToHandlers(.apiError(apiError, requestToCancel), handlers: responseHandlers)
                }
            }
        }

        switch apiError {
        case .network(.networkConnectionFailure(.networkConnectionLost)),
             .network(.networkConnectionFailure(.notConnectedToInternet)):
            Logger.log(.info, "\(APIClientQueueProcessor.self): Not connected to network. Will reschedule request and cancel non-retrying \requests in the queue.")
            await removeRequestsMatching({ $0.retryOnNetworkInterrupt == false })
            if request.retryOnNetworkInterrupt {
                await delegate?.prepend(request)
            } else {
                Logger.log(.error, "\(APIClientQueueProcessor.self): Request: \(client.description(for: request.wrapped.config)) failed and won't be retried: \(apiError)")
            }
        case .network(.networkConnectionFailure(.requestTimedOut)) where request.retryOnRequestTimeout:
            if request.isBarrier {
                await removeRequestsMatching({ $0.retryOnRequestTimeout == false })
            }
            await delegate?.prepend(request)
        case .network(.other(let error)):
            if let retryErrorCodes = request.retryErrorCodes, retryErrorCodes.contains(error.code) {
                await delegate?.prepend(request)
            } else if let doNotRetryErrorCodes = request.doNotRetryErrorCodes, doNotRetryErrorCodes.contains(error.code) == false {
                await delegate?.prepend(request)
            } else {
                Logger.log(.error, "\(APIClientQueueProcessor.self): Request: \(client.description(for: request.wrapped.config)) failed and won't be retried: \(apiError)")
            }
        case .api,
             .deserialization,
             .network,
             .networkingProtocolIsNotHTTP,
             .url,
             .other:
            Logger.log(.error, "\(APIClientQueueProcessor.self): Request: \(client.description(for: request.wrapped.config)) failed and won't be retried: \(apiError)")
        }
    }

    private func forwardDidReceiveResponseToHandlers(_ result: ProcessingResult, handlers: [APIClientQueueProcessorResponseHandler]) {
        for handler in handlers {
            switch result {
            case .backgroundSessionExpired:
                return
            case .success(let response, let request):
                handler(.success(response), request)
            case .aborted(let request):
                handler(.aborted, request)
            case .apiError(let error, let request):
                switch error {
                case .network(.networkConnectionFailure(.networkConnectionLost)) where request.retryOnNetworkInterrupt,
                     .network(.networkConnectionFailure(.notConnectedToInternet)) where request.retryOnNetworkInterrupt,
                     .network(.networkConnectionFailure(.requestTimedOut)) where request.retryOnRequestTimeout:
                    return
                case .api,
                     .deserialization,
                     .network,
                     .networkingProtocolIsNotHTTP,
                     .url,
                     .other:
                    handler(.failure(error), request)
                }
            }
        }
    }
}

// MARK: - Merging

public extension APIClientQueuing {

    func merge<ID>(with entityIdentifier: ID) async where ID: RemoteIdentifier {
        await map { $0.merging(with: entityIdentifier) }
    }
}

private extension APIClientQueueRequest {

    func merging<ID>(with entityIdentifier: ID) -> APIClientQueueRequest where ID: RemoteIdentifier {
        var request = self
        request.wrapped.config.path = request.wrapped.config.path.merging(with: entityIdentifier)
        request.wrapped.config.query = request.wrapped.config.query.merging(with: entityIdentifier)
        return request
    }
}

private extension APIRequestConfig.Path {

    func merging<ID>(with entityIdentifier: ID) -> APIRequestConfig.Path where ID: RemoteIdentifier {
        guard let localValue = entityIdentifier.value.localValue?.description else { return self }

        switch self {
        case .identifier(entityIdentifier.identifierTypeID, localValue):
            return entityIdentifier.pathComponent
        case .path(let lhs, let rhs):
            return .path(parent: lhs.merging(with: entityIdentifier), child: rhs.merging(with: entityIdentifier))
        case .component,
             .identifier:
            return self
        }
    }
}

private extension OrderedDictionary where Key == String, Value == APIRequestConfig.QueryValue {

    func merging<ID>(with entityIdentifier: ID) -> OrderedDictionary<String, APIRequestConfig.QueryValue> where ID: RemoteIdentifier {
        return OrderedDictionary(map { (key, value) in
            return (key, value.merging(with: entityIdentifier))
        })
    }
}

private extension APIRequestConfig.QueryValue {

    func merging<ID>(with entityIdentifier: ID) -> APIRequestConfig.QueryValue where ID: RemoteIdentifier {
        guard let localValue = entityIdentifier.value.localValue?.description else { return self }

        switch self {
        case .identifier(entityIdentifier.identifierTypeID, localValue):
            return entityIdentifier.queryValue
        case ._array(let values):
            return ._array(values.map { $0.merging(with: entityIdentifier) })
        case .identifier,
             ._value:
            return self
        }
    }
}
