//
//  APIClientQueue.swift
//  Lucid
//
//  Created by Stephane Magne on 3/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
import UIKit
import ReactiveKit

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

    public var retryOnInternetConnectionFailures: Bool {
        return wrapped.config.queueingStrategy.retryOnInternetConnectionFailure
    }

    public init(wrapping request: APIRequest<Data>, identifiers: Data? = nil) {
        self.wrapped = request
        self.identifiers = identifiers
        self.timestamp = timestampInNanoseconds()
        self.token = UUID()
    }
}

// MARK: - Handler

/// Object in charge of handling the response of a request.
public protocol APIClientQueueResponseHandler: AnyObject {

    /// Called by the `APIClientQueueProcessor` when a response has been received for a specific request.
    ///
    /// - Parameters:
    ///     - clientQueue: Client queue which has received the response.
    ///     - result: Either the responded data or an error.
    ///     - request: `APIClientQueueRequest` associated to the response.
    func clientQueue(_ clientQueue: APIClientQueuing,
                     didReceiveResponse result: Result<APIClientResponse<Data>, APIError>,
                     for request: APIClientQueueRequest,
                     completion: @escaping () -> Void)
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
    func append(_ request: APIClientQueueRequest)

    /// Registers a response handler which will be notified when the client received a response.
    ///
    /// - Parameters:
    ///     - handler: `APIClientQueueResponseHandler` to register.
    /// - Returns: The handler's registration token.
    @discardableResult
    func register(_ handler: APIClientQueueResponseHandler) -> APIClientQueueResponseHandlerToken

    /// Unregister a response handler based on its token.
    ///
    /// - Parameters:
    ///     - token: Token of the handler to unregister.
    func unregister(_ token: APIClientQueueResponseHandlerToken)

    /// Transform each elements of the queue.
    ///
    /// - Parameters:
    ///     - transform: Block performing the transformation.
    func map(_ transform: @escaping (APIClientQueueRequest) -> APIClientQueueRequest)
}

protocol APIClientPriorityQueuing {

    /// Adds a request to the front of the queue. This should only be called to reschedule the request after a send failure.
    ///
    /// - Parameters:
    ///     - request: `APIRequest` to add in front of the queue.
    func prepend(_ request: APIClientQueueRequest)

    /// Remove requests from the queue based on a passed in filter.
    ///
    /// - Parameters:
    ///     - filter: Logical filter to identify requests to remove. Return true to remove.
    /// - Returns: The removed requests
    func removeRequests(matching: @escaping (APIClientQueueRequest) -> Bool) -> [APIClientQueueRequest]
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
    func flush()
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
        case `default`(DiskQueue<APIClientQueueRequest>)
        case uniquing(DiskCaching<OrderedSet<String>>, DiskCaching<APIClientQueueRequest>, DispatchQueue, UniquingFunction)
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

        switch cache {
        case .default:
            break
        case .uniquing(_, _, let dataQueue, _):
            if dataQueue === DispatchQueue.main {
                Logger.log(.error, "\(APIClientQueue.self) should not assign the main queue as the data queue.", assert: true)
            }
        }
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
                        let dataQueue = DispatchQueue(label: "\(APIClientQueue.self)_uniquing_data_queue")
                        return .uniquing(orderingSetCache.caching,
                                         valueCache.caching,
                                         dataQueue,
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

    public func append(_ request: APIClientQueueRequest) {
        switch cache {
        case .default(let queue):
            queue.append(request)
            processor.didEnqueueNewRequest()
        case .uniquing(let orderingSetCache, let valueCache, let dataQueue, let uniquingFunction):
            let key = uniquingFunction(request)
            dataQueue.async(flags: .barrier) {
                var orderingSet = orderingSetCache[APIClientQueue.uniquingCacheKey] ?? OrderedSet<String>()
                orderingSet.append(key)
                orderingSetCache[APIClientQueue.uniquingCacheKey] = orderingSet
                valueCache[key] = request
                self.processor.didEnqueueNewRequest()
            }
        }
    }

    @discardableResult
    public func register(_ handler: APIClientQueueResponseHandler) -> APIClientQueueResponseHandlerToken {
        return processor.register { [weak self] response, request, completion in
            guard let strongSelf = self else { return }
            handler.clientQueue(strongSelf, didReceiveResponse: response, for: request, completion: completion)
        }
    }

    public func unregister(_ token: APIClientQueueResponseHandlerToken) {
        processor.unregister(token)
    }

    public func map(_ transform: @escaping (APIClientQueueRequest) -> APIClientQueueRequest) {
        switch cache {
        case .default(let queue):
            queue.map(transform)
        case .uniquing(let orderingSetCache, let valueCache, let dataQueue, let uniquingFunction):
            dataQueue.async(flags: .barrier) {

                let orderingSet = orderingSetCache[APIClientQueue.uniquingCacheKey] ?? OrderedSet<String>()
                guard orderingSet.isEmpty == false else { return }

                var newOrderingSet = OrderedSet<String>()
                for key in orderingSet {
                    guard let value = valueCache[key] else {
                        Logger.log(.error, "\(APIClientQueue.self) found no cached value", assert: true)
                        continue
                    }
                    valueCache[key] = nil
                    let newValue = transform(value)
                    let newKey = uniquingFunction(newValue)
                    valueCache[newKey] = newValue
                    newOrderingSet.append(newKey)
                }
                orderingSetCache[APIClientQueue.uniquingCacheKey] = newOrderingSet
            }
        }
    }
}

// MARK: APIClientPriorityQueuing

extension APIClientQueue: APIClientPriorityQueuing {

    func prepend(_ request: APIClientQueueRequest) {
        switch cache {
        case .default(let queue):
            queue.prepend(request)
        case .uniquing(let orderingSetCache, let valueCache, let dataQueue, let uniquingFunction):
            let key = uniquingFunction(request)
            dataQueue.async(flags: .barrier) {
                var orderingSet = orderingSetCache[APIClientQueue.uniquingCacheKey] ?? OrderedSet<String>()
                guard orderingSet.contains(key) == false else { return }
                orderingSet.prepend(key)
                orderingSetCache[APIClientQueue.uniquingCacheKey] = orderingSet
                valueCache[key] = request
            }
        }
    }

    func removeRequests(matching: (APIClientQueueRequest) -> Bool) -> [APIClientQueueRequest] {
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
        case .uniquing(let orderingSetCache, let valueCache, let dataQueue, _):
            dataQueue.sync(flags: .barrier) {
                var orderingSet = orderingSetCache[APIClientQueue.uniquingCacheKey] ?? OrderedSet<String>()
                for key in orderingSet {
                    guard let request = valueCache[key] else { continue }
                    guard matching(request) else { continue }
                    removedElements.append(request)
                    orderingSet.remove(key)
                    valueCache[key] = nil
                }
                orderingSetCache[APIClientQueue.uniquingCacheKey] = orderingSet
            }
        }

        return removedElements
    }
}

// MARK: APIClientQueueFlushing

extension APIClientQueue: APIClientQueueFlushing {

    public func flush() {
        self.processor.flush()
    }
}

// MARK: APIClientQueueProcessorDelegate

extension APIClientQueue: APIClientQueueProcessorDelegate {

    func nextRequest() -> APIClientQueueRequest? {
        switch cache {
        case .default(let queue):
            return queue.dropFirst()
        case .uniquing(let orderingSetCache, let valueCache, let dataQueue, _):
            return dataQueue.sync(flags: .barrier) {
                guard var orderingSet = orderingSetCache[APIClientQueue.uniquingCacheKey],
                    let key = orderingSet.popFirst() else { return nil }

                orderingSetCache[APIClientQueue.uniquingCacheKey] = orderingSet

                guard let value = valueCache[key] else {
                    Logger.log(.error, "\(APIClientQueue.self) found no cached value", assert: true)
                    return nil
                }
                valueCache[key] = nil
                return value
            }
        }
    }
}

// MARK: - Processor

/// A mechanism that will process API requests one at a time.
/// The timing is handled by an injected scheduler.
///
/// - Warning:
///     - Make sure `APIClient`'s implementation handles `APIError.internetConnectionFailure`
///       correctly since it's used by the queueing retry strategy.
protocol APIClientQueueProcessing: AnyObject {

    func didEnqueueNewRequest()

    func flush()

    func register(_ handler: @escaping APIClientQueueProcessorResponseHandler) -> APIClientQueueProcessorResponseHandlerToken

    func unregister(_ token: APIClientQueueProcessorResponseHandlerToken)

    var delegate: APIClientQueueProcessorDelegate? { get set }
}

typealias APIClientQueueProcessorResponseHandlerToken = UUID
typealias APIClientQueueProcessorResponseHandler = (
    _ result: Result<APIClientResponse<Data>, APIError>,
    _ request: APIClientQueueRequest,
    _ completion: @escaping () -> Void
) -> Void

protocol APIClientQueueProcessorDelegate: AnyObject, APIClientPriorityQueuing {

    func nextRequest() -> APIClientQueueRequest?
}

final class APIClientQueueProcessor {

    private let client: APIClient
    private let scheduler: APIClientQueueScheduling
    private let diskCache: DiskCaching<APIClientQueueRequest>

    private var _responseHandlers: OrderedDictionary<APIClientQueueProcessorResponseHandlerToken, APIClientQueueProcessorResponseHandler>

    private let processingQueue: DispatchQueue

    private let operationQueue: AsyncOperationQueue

    private let lock = NSRecursiveLock(name: "\(APIClientQueueProcessor.self)")

    #if os(iOS)
    private let _backgroundTaskManager: BackgroundTaskManaging
    #endif

    weak var delegate: APIClientQueueProcessorDelegate? {
        didSet {
            guard let delegate = delegate else { return }
            lock.lock()
            defer { lock.unlock() }

            let keys = diskCache.keys()
            for key in keys {
                guard let cachedRequest = diskCache[key] else { continue }
                delegate.prepend(cachedRequest)
                diskCache[key] = nil
            }
        }
    }

    #if os(iOS)

    init(client: APIClient,
         backgroundTaskManager: BackgroundTaskManaging,
         scheduler: APIClientQueueScheduling,
         diskCache: DiskCaching<APIClientQueueRequest>,
         responseHandlers: [APIClientQueueProcessorResponseHandler],
         processingQueue: DispatchQueue = DispatchQueue(label: "\(APIClientQueueProcessor.self)_processing_queue"),
         operationQueue: AsyncOperationQueue = AsyncOperationQueue()) {

        self.client = client
        self._backgroundTaskManager = backgroundTaskManager
        self.scheduler = scheduler
        self.diskCache = diskCache
        self._responseHandlers = OrderedDictionary(responseHandlers.map { (UUID(), $0) })
        if processingQueue === DispatchQueue.main {
            Logger.log(.error, "\(APIClientQueueProcessor.self) should not assign the main queue as the processing queue.", assert: true)
        }
        self.processingQueue = processingQueue
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
                  backgroundTaskManager: UIApplication.shared,
                  scheduler: scheduler,
                  diskCache: diskCache.caching,
                  responseHandlers: responseHandlers)
    }

    #elseif os(watchOS)

    init(client: APIClient,
         scheduler: APIClientQueueScheduling,
         diskCache: DiskCaching<APIClientQueueRequest>,
         responseHandlers: [APIClientQueueProcessorResponseHandler],
         processingQueue: DispatchQueue = DispatchQueue(label: "\(APIClientQueueProcessor.self)_processing_queue"),
         operationQueue: AsyncOperationQueue = AsyncOperationQueue()) {

        self.client = client
        self.scheduler = scheduler
        self.diskCache = diskCache
        self._responseHandlers = OrderedDictionary(responseHandlers.map { (UUID(), $0) })
        if processingQueue === DispatchQueue.main {
            Logger.log(.error, "\(APIClientQueueProcessor.self) should not assign the main queue as the processing queue.", assert: true)
        }
        self.processingQueue = processingQueue
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

    func register(_ handler: @escaping APIClientQueueProcessorResponseHandler) -> APIClientQueueProcessorResponseHandlerToken {
        lock.lock()
        defer { lock.unlock() }

        let token = UUID()
        _responseHandlers.append(key: token, value: handler)
        return token
    }

    func unregister(_ token: APIClientQueueProcessorResponseHandlerToken) {
        lock.lock()
        defer { lock.unlock() }

        _responseHandlers[token] = nil
    }

    func didEnqueueNewRequest() {
        scheduler.didEnqueueNewRequest()
    }

    func flush() {
        scheduler.flush()
    }
}

// MARK: APIClientQueueSchedulerDelegate

extension APIClientQueueProcessor: APIClientQueueSchedulerDelegate {

    @discardableResult
    func processNext() -> APIClientQueueSchedulerProcessNextResult {
        lock.lock()
        defer { lock.unlock() }

        guard operationQueue.last?.barrier != .some(true) else {
            return .didNotProcess
        }

        guard let request = delegate?.nextRequest() else {
            return .didNotProcess
        }

        diskCache[request.token.uuidString] = request

        let requestOperation = AsyncOperation(on: processingQueue, title: request.token.uuidString, barrier: request.isBarrier) { completion in
            let operationCompletion = {
                self.diskCache[request.token.uuidString] = nil
                completion()
            }
            self._process(request, operationCompletion)
        }

        operationQueue.run(operation: requestOperation)

        if request.isBarrier {
            return .processedBarrier
        } else {
            return .processedConcurrent
        }
    }
}

// MARK: Private

private extension APIClientQueueProcessor {

    func _process(_ request: APIClientQueueRequest, _ operationCompletion: @escaping () -> Void) {

        #if os(iOS)
        let backgroundTaskID: Property<UIBackgroundTaskIdentifier> = request.wrapped.config.background ? _backgroundTaskManager.beginBackgroundTask(expirationHandler: {
            self.lock.lock()
            defer { self.lock.unlock() }

            Logger.log(.warning, "\(APIClientQueueProcessor.self): Background task expired.")
            self._complete(.backgroundSessionExpired(request), operationCompletion)
        }) : Property(.invalid)
        #endif

        let requestDescription = client.description(for: request.wrapped.config)
        Logger.log(.info, "\(APIClientQueueProcessor.self): Processing request: \(requestDescription)...")
        client.send(request: request.wrapped) { result in
            self.lock.lock()
            defer { self.lock.unlock() }

            #if os(iOS)
            if request.wrapped.config.background {
                if backgroundTaskID.value != .invalid {
                    self._backgroundTaskManager.endBackgroundTask(backgroundTaskID.value)
                } else {
                    Logger.log(.warning, "\(APIClientQueueProcessor.self): Received response from server after background task expired.")
                    return
                }
            }
            #endif

            switch result {
            case .success(let response):
                Logger.log(.info, "\(APIClientQueueProcessor.self): Request succeeded: \(requestDescription).")
                self._complete(.success(response, request), operationCompletion)

            case .failure(let apiError):
                Logger.log(.info, "\(APIClientQueueProcessor.self): Request \(requestDescription) failed: \(apiError).")
                self._complete(.apiError(apiError, request), operationCompletion)
            }
        }
    }

    func cacheRequest(_ request: APIClientQueueRequest) {
        diskCache[Constants.cacheKey] = request
    }

    private enum ProcessingResult {
        case success(_ response: APIClientResponse<Data>, _ request: APIClientQueueRequest)
        case apiError(_ apiError: APIError, _ request: APIClientQueueRequest)
        case backgroundSessionExpired(_ request: APIClientQueueRequest)
    }

    private func _complete(_ result: ProcessingResult, _ operationCompletion: @escaping () -> Void) {

        forwardDidReceiveResponseToHandlers(result, handlers: _responseHandlers.orderedKeyValues.map { $0.1 }) {}

        let didSucceed: Bool
        switch result {
        case .success:
            didSucceed = true
        case .apiError(let apiError, let request):
            self._handleAPIError(apiError, request: request)
            didSucceed = false
        case .backgroundSessionExpired(let request):
            Logger.log(.info, "\(APIClientQueueProcessor.self): Background session expired. Will reschedule request.")
            self.delegate?.prepend(request)
            didSucceed = false
        }

        operationCompletion()

        if didSucceed {
            self.scheduler.requestDidSucceed()
        } else {
            self.scheduler.requestDidFail()
        }
    }

    private func _handleAPIError(_ apiError: APIError, request: APIClientQueueRequest) {
        switch apiError {
        case .internetConnectionFailure:
            Logger.log(.info, "\(APIClientQueueProcessor.self): Not connected to internet. Will reschedule request and cancel non-retrying \requests in the queue.")
            /// Any requests in the queue that expect to fail and not retry on .internetConnectionFailure should be sent the failure right away.
            if let requestsToCancel = delegate?.removeRequests(matching: { $0.retryOnInternetConnectionFailures == false }) {
                let responseHandlers = _responseHandlers.orderedKeyValues.map { $0.1 }
                for requestToCancel in requestsToCancel {
                    forwardDidReceiveResponseToHandlers(.apiError(apiError, requestToCancel), handlers: responseHandlers, completion: { })
                }
            }
            delegate?.prepend(request)
        case .api,
             .deserialization,
             .emptyBodyResponse,
             .sessionKeyMismatch,
             .network,
             .networkingProtocolIsNotHTTP,
             .url:
            Logger.log(.error, "\(APIClientQueueProcessor.self): Request: \(client.description(for: request.wrapped.config)) failed and won't be retried: \(apiError).")
        }
    }

    private func forwardDidReceiveResponseToHandlers(_ result: ProcessingResult,
                                                     handlers: [APIClientQueueProcessorResponseHandler],
                                                     completion: @escaping () -> Void) {
        guard let handler = handlers.first else {
            completion()
            return
        }

        let forwardToNextHandler = {
            self.forwardDidReceiveResponseToHandlers(result,
                                                     handlers: handlers.dropFirst().array,
                                                     completion: completion)
        }

        switch result {
        case .backgroundSessionExpired:
            forwardToNextHandler()
        case .success(let response, let request):
            handler(.success(response), request, forwardToNextHandler)
        case .apiError(let error, let request):
            switch error {
            case .internetConnectionFailure where request.retryOnInternetConnectionFailures:
                forwardToNextHandler()
            case .api,
                 .deserialization,
                 .emptyBodyResponse,
                 .internetConnectionFailure,
                 .network,
                 .networkingProtocolIsNotHTTP,
                 .sessionKeyMismatch,
                 .url:
                handler(.failure(error), request, forwardToNextHandler)
            }
        }
    }
}

// MARK: - Merging

public extension APIClientQueuing {

    func merge<ID>(with entityIdentifier: ID) where ID: RemoteIdentifier {
        map { $0.merging(with: entityIdentifier) }
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
