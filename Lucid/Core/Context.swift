//
//  Context.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/24/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Combine
import Foundation

// MARK: - V3 Parameters

/// Determines if the result of a remote fetch should be persisted to local stores.
///
/// - Note
/// - `persist`: Persist to local stores.
/// - `doNotPersist`: Do not persist to local stores.
public enum PersistenceStrategy {

    /// Determines what to do in case there's a delta between a local and a remote data set.
    ///
    /// - Note
    /// - `discardExtraLocalData`: Applies all remote data **and removes extra local data**.
    /// - `retainExtraLocalData`: Applies all remote data, **but doesn't remove extra local data**.
    public enum DeltaStrategy {
        case discardExtraLocalData
        case retainExtraLocalData
    }

    case persist(DeltaStrategy)
    case doNotPersist
}

// MARK: - UserLogin

public protocol UserAccessValidating {
    var userAccess: UserAccess { get }
}

public enum UserAccess {
    case remoteAccess
    case localAccess
    case noAccess
}

// MARK: EmptyContextProviding

/// Protocol that guarantees an empty context state. This allows the state to be non-optional.
public protocol EmptyContextProviding: CaseIterable {
    static var empty: Self { get }
}

// MARK: - EndpointResponseListener

typealias EndpointResponseListener = (Result<AnyResultPayloadConvertible?, APIError>) -> Void

// MARK: - ReadContext

public typealias ReadContext<E: Entity> = _ReadContext<E.ResultPayload>

/// Transaction shared between queries performed from the same context.
public final class _ReadContext<ResultPayload> where ResultPayload: ResultPayloadConvertible {

    public enum Endpoint {
        case request(APIRequestConfig, resultPayload: ResultPayload.Endpoint)
        case derivedFromEntityType
    }

    public enum DataSource {
        case _remote(endpoint: Endpoint, persistenceStrategy: PersistenceStrategy, orLocal: Bool, trustRemoteFiltering: Bool)
        case local
        indirect case localThen(DataSource)
        indirect case localOr(DataSource)

        public static func remote(endpoint: Endpoint = .derivedFromEntityType,
                                  persistenceStrategy: PersistenceStrategy = .persist(.retainExtraLocalData),
                                  trustRemoteFiltering: Bool = false) -> DataSource {
            return ._remote(endpoint: endpoint,
                            persistenceStrategy: persistenceStrategy,
                            orLocal: false,
                            trustRemoteFiltering: trustRemoteFiltering)
        }
        public static func remoteOrLocal(endpoint: Endpoint = .derivedFromEntityType,
                                         persistenceStrategy: PersistenceStrategy = .persist(.retainExtraLocalData),
                                         trustRemoteFiltering: Bool = false) -> DataSource {
            return ._remote(endpoint: endpoint,
                            persistenceStrategy: persistenceStrategy,
                            orLocal: true,
                            trustRemoteFiltering: trustRemoteFiltering)
        }
    }

    public let dataSource: DataSource

    public let contract: EntityContract

    public let accessValidator: UserAccessValidating?

    /// Cache used to deduplicate API request to endpoints serving payloads with nested entities.
    let remoteStoreCache: RemoteStoreCache

    init(dataSource: DataSource,
         contract: EntityContract,
         accessValidator: UserAccessValidating?,
         remoteStoreCache: RemoteStoreCache) {
        self.dataSource = dataSource.validating()
        self.contract = contract
        self.accessValidator = accessValidator
        self.remoteStoreCache = remoteStoreCache
    }

    public convenience init(dataSource: DataSource = .local,
                            contract: EntityContract = AlwaysValidContract(),
                            accessValidator: UserAccessValidating? = nil,
                            payloadPersistenceManager: RemoteStoreCachePayloadPersistenceManaging? = nil) {

        let _payloadPersistenceManager: RemoteStoreCachePayloadPersistenceManaging?
        switch dataSource.persistenceStrategy {
        case .doNotPersist:
            _payloadPersistenceManager = nil
        case .persist:
            _payloadPersistenceManager = payloadPersistenceManager
        }

        self.init(dataSource: dataSource,
                  contract: contract,
                  accessValidator: accessValidator,
                  remoteStoreCache: RemoteStoreCache(payloadPersistenceManager: _payloadPersistenceManager, accessValidator: accessValidator))
    }

    // RemoteCache Accessors

    /// Check to see if a request already has a cached response, this is dependent on the existence of a cached entry.
    ///
    /// - Parameters:
    ///     - request: The APIRequestConfig returned from a previous request.
    func hasCachedResponse(for request: APIRequestConfig?) -> Bool {
        guard let request = request else { return false }
        return remoteStoreCache.hasCachedResponse(for: request)
    }

    /// Add a listener to notify each time a payload with a matching request is set.
    ///
    /// - Parameters:
    ///     - request: The APIRequestConfig returned from a previous request.
    ///     - listener: Block being stored and called when writing to cache for the given key.
    func addListener(for request: APIRequestConfig, listener: @escaping EndpointResponseListener) {
        remoteStoreCache.addListener(for: request, listener: listener)
    }

    /// Write a payload in the cache for a request.
    ///
    /// - Parameters:
    ///     - payloadResult: Either an error or the payload to store.
    ///     - request: maps to Cache key.
    func set(payloadResult: Result<AnyResultPayloadConvertible?, APIError>,
             source: RemoteResponseSource?,
             for request: APIRequestConfig) {

        remoteStoreCache.set(payloadResult: payloadResult, source: source, for: request)
    }

    /// Erase all entries from the cache.
    func clearCache() {
        remoteStoreCache.clear()
    }

    public var persistenceStrategy: PersistenceStrategy {
        return dataSource.persistenceStrategy
    }

    public var responseHeader: APIResponseHeader? {
        switch remoteStoreCache.remoteResponseSource {
        case .some(.server(let header)),
             .some(.urlCache(let header)):
            return header
        case .none:
            return nil
        }
    }

    public var endpointResultMetadata: EndpointResultMetadata? {
        return remoteStoreCache.resultPayload?.metadata
    }
}

// MARK: - Debug Description

extension _ReadContext: CustomDebugStringConvertible {

    public var debugDescription: String {
        return "ReadContext: \(dataSource.debugDescription)"
    }
}

extension _ReadContext.DataSource: CustomDebugStringConvertible {

    public var debugDescription: String {
        switch self {
        case ._remote(.request(let request, let payload), let persistenceStrategy, let orLocal, let trustRemoteFiltering):
            return "remote: \(request.path) -> \(payload): \(persistenceStrategy.debugDescription)\(orLocal ? " or local" : String()): trustsRemoteFiltering \(trustRemoteFiltering)"
        case ._remote(.derivedFromEntityType, let persistenceStrategy, let orLocal, let trustRemoteFiltering):
            return "remote RESTful: \(persistenceStrategy.debugDescription)\(orLocal ? " or local" : String()): trustsRemoteFiltering \(trustRemoteFiltering)"
        case .local:
            return "local"
        case .localOr(let dataSource):
            return "local or: \(dataSource.debugDescription)"
        case .localThen(let dataSource):
            return "local then: \(dataSource.debugDescription)"
        }
    }
}

// MARK: - Persistence

extension PersistenceStrategy: CustomDebugStringConvertible {

    public var debugDescription: String {
        switch self {
        case .doNotPersist:
            return "do not persist"
        case .persist(.discardExtraLocalData):
            return "persit & discard extra local data"
        case .persist(.retainExtraLocalData):
            return "persist & retain extra local data"
        }
    }
}

// MARK: - Copy & Update

extension _ReadContext {

    public func updateForRelationshipController<Graph>(at path: [Graph.AnyEntity.IndexName], graph: Graph, deltaStrategy: PersistenceStrategy.DeltaStrategy) -> _ReadContext where Graph: MutableGraph {

        let updatedContract: EntityContract
        if let graphContract = contract as? EntityGraphContract {
            updatedContract = graphContract.contract(at: path, for: graph)
        } else {
            Logger.log(.error, "\(_ReadContext.self) contract used to build graph must conform to \(EntityGraphContract.self). Defaulting to \(AlwaysValidContract.self) instead.", assert: true)
            updatedContract = AlwaysValidContract()
        }

        switch dataSource {
        case ._remote(let endpoint, .persist, let orLocal, let trustRemoteFiltering):

            return _ReadContext(dataSource: ._remote(endpoint: endpoint, persistenceStrategy: .persist(deltaStrategy),
                                                     orLocal: orLocal,
                                                     trustRemoteFiltering: trustRemoteFiltering),
                                contract: updatedContract,
                                accessValidator: accessValidator,
                                remoteStoreCache: remoteStoreCache)
        case ._remote,
             .local,
             .localThen,
             .localOr:
            return _ReadContext(dataSource: dataSource,
                                contract: updatedContract,
                                accessValidator: accessValidator,
                                remoteStoreCache: remoteStoreCache)
        }
    }

    public func updatingDataSource(_ dataSource: DataSource) -> _ReadContext {
        return _ReadContext(dataSource: dataSource,
                            contract: contract,
                            accessValidator: accessValidator,
                            remoteStoreCache: remoteStoreCache)
    }
}

// MARK: - WriteContext

/// Transaction shared between queries performed from the same context.
public final class WriteContext<E: Entity> {

    public enum Endpoint {
        case request(APIRequestConfig)
        case derivedFromPath(builder: (RemoteSetPath<E>) -> APIRequestConfig?)
        case derivedFromEntityType
    }

    public enum DataTarget {
        case remote(endpoint: Endpoint)
        case localAndRemote(endpoint: Endpoint)
        case local
    }

    public let dataTarget: DataTarget

    public let remoteSyncState: RemoteSyncState?

    public let accessValidator: UserAccessValidating?

    public enum RemoteSyncState {
        case createResponse(UInt64)
        case mergeIdentifier
    }

    init(dataTarget: DataTarget,
         remoteSyncState: RemoteSyncState?,
         accessValidator: UserAccessValidating? = nil) {

        self.dataTarget = dataTarget
        self.remoteSyncState = remoteSyncState
        self.accessValidator = accessValidator
    }

    public convenience init(dataTarget: DataTarget,
                            accessValidator: UserAccessValidating? = nil) {

        self.init(dataTarget: dataTarget,
                  remoteSyncState: nil,
                  accessValidator: accessValidator)
    }
}

// MARK: - CoreManager Helpers

extension _ReadContext {

    var remoteContextAfterMakingLocalRequest: _ReadContext? {
        switch dataSource {
        case .localThen(let remoteDataSource),
             .localOr(let remoteDataSource):
            return _ReadContext(dataSource: remoteDataSource,
                                contract: contract,
                                accessValidator: accessValidator,
                                remoteStoreCache: remoteStoreCache)
        case ._remote,
             .local:
            return nil
        }
    }

    var shouldOverwriteInLocalStores: Bool {
        switch (dataSource.persistenceStrategy, userAccess) {
        case (.persist, .remoteAccess):
            return true
        case (.persist, _),
             (.doNotPersist, _):
            return false
        }
    }

    var shouldFetchFromRemoteWhileFetchingFromLocalStore: Bool {
        switch dataSource {
        case .localThen:
            return true
        case ._remote,
             .local,
             .localOr:
            return false
        }
    }

    var returnsCompleteResultSet: Bool {
        return dataSource.returnsCompleteResultSet
    }

    var trustRemoteFiltering: Bool {
        return dataSource.trustRemoteFiltering
    }
}

extension _ReadContext.DataSource {

    fileprivate func validating() -> _ReadContext.DataSource {
        switch self {
        case .localOr(let dataSource),
             .localThen(let dataSource):

            switch dataSource {
            case ._remote:
                return self

            case .local:
                Logger.log(.error, "\(_ReadContext.DataSource.self): Invalid data source \(self). Will fall back to 'local'.")
                return .local

            case .localThen(let dataSource),
                 .localOr(let dataSource):
                Logger.log(.error, "\(_ReadContext.DataSource.self): Invalid data source \(self). Ignoring unecessary 'then' / 'or'.")
                return dataSource.validating()
            }

        case ._remote,
             .local:
            return self
        }
    }

    var persistenceStrategy: PersistenceStrategy {
        switch self {
        case ._remote(_, let persistenceStrategy, _, _):
            return persistenceStrategy
        case .local:
            return .doNotPersist
        case .localThen(let dataSource),
             .localOr(let dataSource):
            return dataSource.persistenceStrategy
        }
    }

    var returnsCompleteResultSet: Bool {
        switch self {
        case .local:
            return true
        case ._remote(_, .persist(.discardExtraLocalData), _, _):
            return true
        case ._remote:
            return false
        case .localThen(let dataSource),
             .localOr(let dataSource):
            return dataSource.returnsCompleteResultSet
        }
    }

    var trustRemoteFiltering: Bool {
        switch self {
        case ._remote(_, _, _, let trust):
            return trust
        case .local:
            return false
        case .localThen(let dataSource),
             .localOr(let dataSource):
            return dataSource.trustRemoteFiltering
        }
    }
}

extension WriteContext {

    var originTimestamp: UInt64? {
        switch remoteSyncState {
        case .some(.createResponse(let timestamp)):
            return timestamp
        case .some(.mergeIdentifier),
             .none:
            return nil
        }
    }
}

extension UserAccess {

    var allowsStoreRequest: Bool {
        switch self {
        case .remoteAccess,
             .localAccess:
            return true
        case .noAccess:
            return false
        }
    }
}

// MARK: - UserAccess

extension _ReadContext {

    public var userAccess: UserAccess {
        guard let accessValidator = accessValidator else {
            return .remoteAccess
        }
        return accessValidator.userAccess
    }

    var requestAllowedForAccessLevel: Bool {
        return userAccess.allowsStoreRequest
    }

    var responseAllowedForAccessLevel: Bool {
        switch userAccess {
        case .remoteAccess:
            return true
        case .localAccess where remoteStoreCache.remoteResponseSource != nil:
            return false
        case .localAccess:
            return true
        case .noAccess:
            return false
        }
    }
}

extension WriteContext {

    public var userAccess: UserAccess {
        guard let accessValidator = accessValidator else {
            return .remoteAccess
        }
        return accessValidator.userAccess
    }

    var requestAllowedForAccessLevel: Bool {
        return userAccess.allowsStoreRequest
    }

    var responseAllowedForAccessLevel: Bool {
        return userAccess.allowsStoreRequest
    }
}

// MARK: - Source

public enum RemoteResponseSource {
    case urlCache(_ header: APIResponseHeader)
    case server(_ header: APIResponseHeader)
}

// MARK: - Persistence Manager

/// In charge of persisting the the entities they contained in the payloads passing through `RemoteStoreCache`.
public protocol RemoteStoreCachePayloadPersistenceManaging: AnyObject {

    /// Persists the entities contained in a given payload.
    /// - Parameters:
    ///   - payload: Payload which just came from a server.
    ///   - accessValidator: Validates that the entities are permitted to be stored in the current user session.
    func persistEntities(from payload: AnyResultPayloadConvertible, accessValidator: UserAccessValidating?)
}

// MARK: - Cache

/// Cache used to deduplicate API requests to endpoints serving payloads with nested entities.
///
/// E.g. When using the endpoint `/home/v2`, which returns the following payload:
///
/// ```
///  {
///   "status": {
///     "code": 0,
///     "message": "OK"
///   },
///   "result": {
///     "modules": [
///       {
///         "documents": [
///           {
///             "id": 390624136,
///             "title": "Becoming",
///             "document_type": "audiobook",
///             "reader_type": "audiobook",
///             "publisher": {
///               "id": 260115982,
///               "name": "Findaway",
///               ...
///             },
///             "authors": [
///               {
///                 "id": 229969068,
///                 "name": "Michelle Obama",
///                 ...
///               }
///             ],
///             "series_membership": "standalone",
///             "badges": 4,
///             "global_rating": {
///               "average_rating": 4.692610844955069,
///               "ratings_count": 1015,
///               "current_user_rating": 0,
///               "up_count": 931,
///               "down_count": 48
///             },
///             ...
///           },
///           ...
///         ],
///         "title": "Today's Top Pick",
///         "subtitle": "An intimate, powerful, ...",
///         ...
///       },
///       ...
///     ]
///   }
/// }
/// ```
///
/// This payload is then cached into the `RemoteStoreCache`. Since documents are being
/// requested in this example, `RemoteStore` extracts the documents contained in this
/// payload, filters them by module id and serves them.
///
/// This mechanism is key so that entities can be provided in a RESTful manner even when using
/// non flat payloads and without loosing scalability.
final class RemoteStoreCache {

    fileprivate struct Payload {
        let result: Result<AnyResultPayloadConvertible?, APIError>
        let source: RemoteResponseSource?
    }

    private static let dispatchQueue = DispatchQueue(label: "\(RemoteStoreCache.self)_id_incrementer")

    private let dispatchQueue: DispatchQueue = DispatchQueue(label: "\(RemoteStoreCache.self)_dispatch_queue")
    private let broadcastQueue: DispatchQueue = DispatchQueue(label: "\(RemoteStoreCache.self)_broadcast_queue")

    private let payloadPersistenceManager: RemoteStoreCachePayloadPersistenceManaging?
    private let accessValidator: UserAccessValidating?

    private var _payloadRequest: APIRequestConfig?
    var payloadRequest: APIRequestConfig? {
        return dispatchQueue.sync { _payloadRequest }
    }

    private var payload: Payload?
    private var listeners = [EndpointResponseListener]()

    init(payloadPersistenceManager: RemoteStoreCachePayloadPersistenceManaging?,
         accessValidator: UserAccessValidating?) {
        self.payloadPersistenceManager = payloadPersistenceManager
        self.accessValidator = accessValidator
    }

    /// Check to see if a request already has a cached response, this is dependent on the existence of a cached entry.
    ///
    /// - Parameters:
    ///     - request: The APIRequestConfig returned from a previous request.
    fileprivate func hasCachedResponse(for request: APIRequestConfig) -> Bool {
        return dispatchQueue.sync {
            return _payloadRequest == request
        }
    }

    /// Add a listener to notify each time a payload with a matching request is set.
    ///
    /// - Parameters:
    ///     - request: The APIRequestConfig returned from a previous request.
    ///     - listener: Block being stored and called when writing to cache for the given key.
    fileprivate func addListener(for request: APIRequestConfig, listener: @escaping EndpointResponseListener) {
        dispatchQueue.async {
            guard self._payloadRequest == nil || self._payloadRequest == request else {
                let message = "Attempting to add listener for mismatched token."
                Logger.log(.error, "\(RemoteStoreCache.self): \(message)", assert: true)
                listener(.failure(.other(message)))
                return
            }

            if self._payloadRequest == nil {
                self._payloadRequest = request
            }

            if let payloadResult = self.payload?.result {
                self.broadcastQueue.async {
                    listener(payloadResult)
                }
            } else {
                self.listeners.append(listener)
            }
        }
    }

    /// Write a payload in the cache for a request.
    ///
    /// - Parameters:
    ///     - payloadResult: Either an error or the payload to store.
    ///     - request: The APIRequestConfig returned from a previous request.
    fileprivate func set(payloadResult: Result<AnyResultPayloadConvertible?, APIError>,
                         source: RemoteResponseSource?,
                         for request: APIRequestConfig) {

        dispatchQueue.async {
            guard self.payload == nil else {
                Logger.log(.error, "\(RemoteStoreCache.self) a cached payload already exists. You are attempting to use a single context for multiple remote calls.", assert: true)
                return
            }

            if self._payloadRequest != nil && self._payloadRequest != request {
                Logger.log(.error, "\(RemoteStoreCache.self) a listener has been previously added for a mismatched token. The response will never be sent.", assert: true)
            }

            self._payloadRequest = request
            self.payload = Payload(result: payloadResult, source: source)

            if let payload = payloadResult.value?._unbox {
                self.payloadPersistenceManager?.persistEntities(from: payload, accessValidator: self.accessValidator)
            }

            let existingListeners = self.listeners
            self.listeners = []
            self.broadcastQueue.async {
                for listener in existingListeners {
                    listener(payloadResult)
                }
            }
        }
    }

    /// Erase all entries from the cache.
    fileprivate func clear() {
        dispatchQueue.async {
            self.payload = nil
        }
    }

    fileprivate var remoteResponseSource: RemoteResponseSource? {
        return dispatchQueue.sync { payload?.source }
    }

    fileprivate var resultPayload: AnyResultPayloadConvertible? {
        return dispatchQueue.sync {
            switch payload?.result {
            case .some(.success(let payloadResult)):
                return payloadResult
            case .some,
                 .none:
                return nil
            }
        }
    }
}
