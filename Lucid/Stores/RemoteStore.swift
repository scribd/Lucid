//
//  RemoteStore.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/21/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

// MARK: - RemoteEntity

public extension RemoteEntity {

    static func request(for remotePath: RemotePath<Self>, or cachedRequest: APIRequestConfig?) -> APIRequest<Data>? {

        switch (Self.requestConfig(for: remotePath), cachedRequest) {
        case (.some(let config), _),
             (nil, .some(let config)):
            return APIRequest<Data>(config)

        default:
            Logger.log(.error, "\(Self.self): ReadPath: \(remotePath) is not supported.")
            return nil
        }
    }
}

// MARK: - Store

// swiftlint:disable type_body_length
public final class RemoteStore<E>: StoringConvertible where E: RemoteEntity {

    // MARK: - Dependencies

    public let level: StoreLevel = .remote

    private let clientQueue: APIClientQueuing & APIClientQueueFlushing

    /// - Warning: This queue shall only be used for decoding computation.
    ///            It shall never be used for work deferring to other queues synchronously or it would
    ///            introduce a risk of thread pool starvation (no more threads available), leading to a crash.
    private let decodingAsyncQueue = AsyncTaskQueue()

    // MARK: - Inits

    public init(clientQueue: APIClientQueuing & APIClientQueueFlushing) {
        self.clientQueue = clientQueue
    }

    // MARK: - API

    public func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        Task {
            let result = await self.get(withQuery: query, in: context)
            completion(result)
        }
    }

    public func get(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        guard let identifier = query.identifier else {
            return .failure(.identifierNotFound)
        }

        let request: APIRequest<Data>
        let hasCachedResponse: Bool

        let path = RemotePath<E>.get(identifier)

        switch context.dataSource {
        case ._remote(.derivedFromEntityType, _, _, _):
            guard let newRequest = E.request(for: path, or: context.remoteStoreCache.payloadRequest) else {
                Logger.log(.error, "\(Self.self): Remote store could not build valid API request from context \(context)", assert: true)
                return .failure(.invalidContext)
            }

            request = newRequest
            hasCachedResponse = context.hasCachedResponse(for: request.config)

        case ._remote(.request(let requestConfig, _), _, _, _):
            request = APIRequest<Data>(requestConfig)
            hasCachedResponse = context.hasCachedResponse(for: request.config)

        case .local,
             .localOr,
             .localThen:
            Logger.log(.error, "\(Self.self): Remote store should not be attempting to handle data source \(context.dataSource).", assert: true)
            return .failure(.invalidContext)
        }

        guard request.config.query.hasUnsyncedIdentifiers == false else {
            return .failure(.identifierNotSynced)
        }

        if hasCachedResponse == false {

            let requestCompletion: (APIClientQueueResult<Data, APIError>) -> Void = { result in
                switch result {
                case .success(let response):

                    let source: RemoteResponseSource = response.cachedResponse ? .urlCache(.empty) : .server(.empty)

                    if response.isNotModified {
                        context.set(payloadResult: .success(nil), source: source, for: request.config)
                        return
                    }

                    Task {
                        do {
                            try await self.decodingAsyncQueue.enqueue {
                                switch context.dataSource {
                                case ._remote(.request(_, let endpoint), _, _, _):
                                    let payload = try E.ResultPayload(from: response.data,
                                                                      endpoint: endpoint,
                                                                      decoder: response.jsonCoderConfig.decoder)
                                    context.set(payloadResult: .success(payload), source: source, for: request.config)

                                case ._remote(.derivedFromEntityType, _, _, _):
                                    let payload = try E.ResultPayload(from: response.data,
                                                                      endpoint: try E.unwrappedEndpoint(for: path),
                                                                      decoder: response.jsonCoderConfig.decoder)
                                    context.set(payloadResult: .success(payload), source: source, for: request.config)

                                case .local,
                                        .localOr,
                                        .localThen:
                                    Logger.log(.error, "\(Self.self): Remote store should not be attempting to handle data source \(context.dataSource).", assert: true)
                                    return
                                }
                            }
                        } catch {
                            Logger.log(.error, "\(RemoteStore.self) found error while enqueuing async task: \(error)")
                            context.set(payloadResult: .failure(.deserialization(error)), source: source, for: request.config)
                        }
                    }

                case .aborted:
                    context.set(payloadResult: .failure(.network(.cancelled)), source: nil, for: request.config)

                case .failure(let error):
                    context.set(payloadResult: .failure(error), source: nil, for: request.config)
                }
            }

            Task {
                let identifiers = query.identifiers?.array ?? []
                let clientQueueRequest = APIClientQueueRequest(wrapping: request, identifiers: identifiers)
                await completeOnClientQueueResponse(for: [clientQueueRequest]) { result in
                    requestCompletion(result)
                }
                await clientQueue.append(clientQueueRequest)
            }
        }

        return await withCheckedContinuation { continuation in
            context.addListener(for: request.config) { result in
                switch result {
                case .success(.some(let payload as E.ResultPayload)):
                    if let entity: E = payload.getEntity(for: identifier) {
                        let metadata = Metadata<E>(payload.metadata)
                        continuation.resume(returning: .success(QueryResult(from: entity, metadata: metadata)))
                    } else {
                        continuation.resume(returning: .failure(.notFoundInPayload))
                    }

                case .success(.some(let payload)):
                    Logger.log(.error, "\(RemoteStore.self): Could not convert \(type(of: payload)) to \(E.ResultPayload.self).", assert: true)
                    continuation.resume(returning: .failure(.invalidContext))

                case .success(.none):
                    continuation.resume(returning: .failure(.emptyResponse))

                case .failure(.api(httpStatusCode: 404, _, _)):
                    continuation.resume(returning: .success(.empty()))

                case .failure(let error):
                    let error = StoreError.api(error)
                    Logger.log(.error, "\(RemoteStore.self): Error occurred for request path: \(request.config.path): \(error)")
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    private func coreSearch(withQuery query: Query<E>,
                            in context: ReadContext<E>) async -> Result<(result: QueryResult<E>, isFromCache: Bool), StoreError> {

        let request: APIRequest<Data>
        let hasCachedResponse: Bool

        switch context.dataSource {
        case ._remote(.derivedFromEntityType, _, _, _):
            let path = RemotePath<E>.search(query)
            guard let newRequest = E.request(for: path, or: context.remoteStoreCache.payloadRequest) else {
                Logger.log(.error, "\(Self.self): could not build valid request.", assert: true)
                return .failure(.invalidContext)
            }

            request = newRequest
            hasCachedResponse = context.hasCachedResponse(for: request.config)

        case ._remote(.request(let requestConfig, _), _, _, _):
            request = APIRequest<Data>(requestConfig)
            hasCachedResponse = context.hasCachedResponse(for: request.config)

        case .local,
             .localOr,
             .localThen:
            Logger.log(.error, "\(Self.self): Remote store should not be attempting to handle data source \(context.dataSource).", assert: true)
            return .failure(.invalidContext)
        }

        if hasCachedResponse == false {

            guard request.config.query.hasUnsyncedIdentifiers == false else {
                return .failure(.identifierNotSynced)
            }

            let requestCompletion: (APIClientQueueResult<Data, APIError>) -> Void = { result in
                switch result {
                case .success(let response):

                    let source: RemoteResponseSource = response.cachedResponse ? .urlCache(response.header) : .server(response.header)

                    if response.isNotModified {
                        context.set(payloadResult: .success(nil), source: source, for: request.config)
                        return
                    }

                    Task {
                        do {
                            try await self.decodingAsyncQueue.enqueue {
                                switch context.dataSource {
                                case ._remote(.request(_, let endpoint), _, _, _):

                                    let payload = try E.ResultPayload(from: response.data,
                                                                      endpoint: endpoint,
                                                                      decoder: response.jsonCoderConfig.decoder)
                                    context.set(payloadResult: .success(payload), source: source, for: request.config)

                                case ._remote(.derivedFromEntityType, _, _, _):
                                    let path = RemotePath<E>.search(query)
                                    let payload = try E.ResultPayload(from: response.data,
                                                                      endpoint: try E.unwrappedEndpoint(for: path),
                                                                      decoder: response.jsonCoderConfig.decoder)
                                    context.set(payloadResult: .success(payload), source: source, for: request.config)

                                case .local,
                                        .localOr,
                                        .localThen:
                                    Logger.log(.error, "\(Self.self): Remote store should not be attempting to handle data source \(context.dataSource).", assert: true)
                                    return
                                }
                            }
                        } catch {
                            Logger.log(.error, "\(RemoteStore.self) found error while enqueuing async task: \(error)")
                            context.set(payloadResult: .failure(.deserialization(error)), source: source, for: request.config)
                        }
                    }

                case .aborted:
                    context.set(payloadResult: .failure(.network(.cancelled)), source: nil, for: request.config)

                case .failure(let error):
                    context.set(payloadResult: .failure(error), source: nil, for: request.config)
                }
            }

            Task {
                let identifiers = query.identifiers?.array ?? []
                let clientQueueRequest = APIClientQueueRequest(wrapping: request, identifiers: identifiers)
                await completeOnClientQueueResponse(for: [clientQueueRequest]) { result in
                    requestCompletion(result)
                }
                await clientQueue.append(clientQueueRequest)
            }
        }

        return await withCheckedContinuation { continuation in
            context.addListener(for: request.config) { result in
                switch result {
                case .success(.some(let payload as E.ResultPayload)):
                    let entities: AnySequence<E>
                    let alreadyFiltered: Bool = context.trustRemoteFiltering && hasCachedResponse == false
                    if alreadyFiltered {
                        entities = payload.allEntities()
                    } else {
                        entities = payload.allEntities().filter(with: query.filter)
                    }
                    let searchResult = QueryResult(
                        from: entities,
                        for: query,
                        alreadyPaginated: alreadyFiltered,
                        metadata: Metadata<E>(payload.metadata)
                    )
                    continuation.resume(returning: .success((searchResult, hasCachedResponse)))

                case .success(.some(let payload)):
                    Logger.log(.error, "\(RemoteStore.self): Could not convert \(type(of: payload)) to \(E.ResultPayload.self)", assert: true)
                    continuation.resume(returning: .failure(.invalidContext))

                case .success(.none):
                    continuation.resume(returning: .failure(.emptyResponse))

                case .failure(let error):
                    let error = StoreError.api(error)
                    Logger.log(.error, "\(RemoteStore.self): Error occurred for request path: \(request.config.path): \(error)")
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    public func search(withQuery query: Query<E>,
                       in context: ReadContext<E>,
                       completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        Task {
            let result = await self.search(withQuery: query, in: context)
            completion(result)
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        // Some payloads need to filter out entities which aren't meant to be at their root level.
        // This is due to the fact that payloads made of a tree structure get their data automatically flattened.
        let result = await coreSearch(withQuery: query, in: context)
        switch result {
        case .success(let response):

            guard let allItems = response.result.metadata?.allItems else {
                return .success(response.result)
            }

            let rootIdentifiers = DualHashSet<E.Identifier>(allItems.lazy.compactMap { $0.entityIdentifier() })
            guard rootIdentifiers.isEmpty == false else {
                return .success(response.result)
            }

            guard response.isFromCache == false else {
                return .success(response.result)
            }

            let filteredEntities = response.result.filter { rootIdentifiers.contains($0.identifier) }

            return .success(QueryResult<E>(fromProcessedEntities: filteredEntities,
                                           for: query,
                                           metadata: response.result.metadata))

        case .failure(let error):
            return .failure(error)
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {
        Task {
            let result = await set(entities, in: context)
            completion(result)
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>) async -> Result<AnySequence<E>, StoreError>? where S : Sequence, E == S.Element {
        var countMismatch = false

        let requests: [APIClientQueueRequest]

        switch context.dataTarget {
        case .localAndRemote(.derivedFromEntityType),
             .remote(.derivedFromEntityType):
            requests = entities.compactMap { entity in
                let setPath: RemoteSetPath<E> = entity.identifier.hasBeenPushedToClientQueue ? .update(entity) : .create(entity)
                let path: RemotePath<E> = .set(setPath)
                guard let request = E.request(for: path, or: nil) else {
                    countMismatch = true
                    return nil
                }
                return APIClientQueueRequest(wrapping: request, identifiers: [entity.identifier])
            }

        case .localAndRemote(.derivedFromPath(let builder)),
             .remote(.derivedFromPath(let builder)):
            requests = entities.compactMap { entity in
                let setPath: RemoteSetPath<E> = entity.identifier.hasBeenPushedToClientQueue ? .update(entity) : .create(entity)
                guard let config = builder(setPath) else {
                    countMismatch = true
                    return nil
                }
                let request = APIRequest<Data>(config)
                return APIClientQueueRequest(wrapping: request, identifiers: [entity.identifier])
            }

        case .localAndRemote(.request(let config)),
             .remote(.request(let config)):
            let request = APIRequest<Data>(config)
            requests = [APIClientQueueRequest(wrapping: request, identifiers: entities.map { $0.identifier })]

        case .local:
            Logger.log(.error, "\(Self.self): Remote store should not be attempting to handle data target \(context.dataTarget).", assert: true)
            return .failure(.invalidContext)
        }

        guard countMismatch == false else {
            return .failure(.notSupported)
        }

        for entity in entities {
            entity.identifier.willBePushedToClientQueue()
        }

        Task {
            await withTaskGroup(of: Void.self) { group in
                for request in requests {
                    group.addTask {
                        await self.clientQueue.append(request)
                    }
                }
            }
        }

        return await withCheckedContinuation { continuation in
            continuation.resume(returning: nil)
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {
        Task {
            let result = await removeAll(withQuery: query, in: context)
            completion(result)
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>) async -> Result<AnySequence<E.Identifier>, StoreError>? {
        let path = RemotePath<E>.removeAll(query)
        let identifiers = query.identifiers?.array ?? []
        let clientQueueRequest: APIClientQueueRequest

        switch context.dataTarget {
        case .localAndRemote(.derivedFromEntityType),
             .remote(.derivedFromEntityType):
            guard let request = E.request(for: path, or: nil) else {
                return .failure(.notSupported)
            }

            let identifiers = query.identifiers?.array ?? []
            clientQueueRequest = APIClientQueueRequest(wrapping: request, identifiers: identifiers)

        case .localAndRemote(.derivedFromPath),
             .remote(.derivedFromPath):
            Logger.log(.error, "\(Self.self): For .removeAll, use endpoint .request instead.", assert: true)
            return .failure(.notSupported)

        case .localAndRemote(.request(let config)),
             .remote(.request(let config)):
            let request = APIRequest<Data>(config)
            clientQueueRequest = APIClientQueueRequest(wrapping: request, identifiers: identifiers)

        case .local:
            Logger.log(.error, "\(Self.self): Remote store should not be attempting to handle data target \(context.dataTarget).", assert: true)
            return .failure(.notSupported)
        }

        await completeOnClientQueueResponse(for: [clientQueueRequest]) { _ in }

        await clientQueue.append(clientQueueRequest)

        return nil
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {

        Task {
            let result = await remove(identifiers, in: context)
            completion(result)
        }
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>) async -> Result<Void, StoreError>? where S : Sequence, S.Element == E.Identifier {
        var countMismatch = false
        let requests = identifiers.compactMap { (identifier: E.Identifier) -> APIClientQueueRequest? in

            let path = RemotePath<E>.remove(identifier)
            switch context.dataTarget {
            case .localAndRemote(.derivedFromEntityType),
                 .remote(.derivedFromEntityType):
                if let request = E.request(for: path, or: nil) {
                    return APIClientQueueRequest(wrapping: request, identifiers: [identifier])
                } else {
                    countMismatch = true
                    return nil
                }

            case .localAndRemote(.derivedFromPath),
                 .remote(.derivedFromPath):
                Logger.log(.error, "\(Self.self): For .remove, use .localAndRemote instead.", assert: true)
                return nil

            case .localAndRemote(.request(let config)),
                 .remote(.request(let config)):
                if identifiers.array.count > 1 {
                    Logger.log(.error, "\(Self.self): Data target \(context.dataTarget) does not support multiple entities at once. Use endpoint .derivedFromEntityType or .derivedFromPath instead.", assert: true)
                }
                let request = APIRequest<Data>(config)
                return APIClientQueueRequest(wrapping: request, identifiers: [identifier])

            case .local:
                Logger.log(.error, "\(Self.self): Remote store should not be attempting to handle data target \(context.dataTarget).", assert: true)
                return nil
            }
        }

        guard countMismatch == false else {
            return .failure(.notSupported)
        }

        Task {
            await withTaskGroup(of: Void.self) { group in
                for request in requests {
                    group.addTask {
                        await self.clientQueue.append(request)
                    }
                }
            }
        }

        return await withCheckedContinuation { continuation in
            await self.completeOnClientQueueResponse(for: requests) { _ in
                continuation.resume(returning: nil)
            }
        }
    }
}

// MARK: - Utils

private extension Query {

    var emptyResult: QueryResult<E> {
        if groupedBy != nil {
            return .groups(DualHashDictionary())
        } else {
            return .entities(AnySequence.empty)
        }
    }
}

extension APIClientQueueRequest {

    init<I>(wrapping request: APIRequest<Data>, identifiers: [I]) where I: Encodable {
        do {
            let jsonEncoder = JSONEncoder()
            jsonEncoder.set(context: .clientQueueRequest)
            self.init(wrapping: request, identifiers: try jsonEncoder.encode(identifiers))
        } catch {
            Logger.log(.error, "\(APIClientQueueRequest.self): Could not encode mutable identifier: \(error).", assert: true)
            self.init(wrapping: request, identifiers: nil)
        }
    }
}

// MARK: - ClientQueueResponseHandler

private extension RemoteStore {

    final class ClientQueueResponseHandler: APIClientQueueResponseHandler {

        private let requestTokensQueue = DispatchQueue(label: "\(ClientQueueResponseHandler.self)_requests")
        private var _requestTokens: Set<UUID>

        private let resultHandler: (APIClientQueueResult<Data, APIError>) -> Void

        init<S>(_ requests: S, _ resultHandler: @escaping (APIClientQueueResult<Data, APIError>) -> Void) where S: Sequence, S.Element == APIClientQueueRequest {
            _requestTokens = Set(requests.lazy.map { $0.token })
            self.resultHandler = resultHandler
        }

        func clientQueue(_ clientQueue: APIClientQueuing,
                         didReceiveResponse result: APIClientQueueResult<Data, APIError>,
                         for request: APIClientQueueRequest) {

            requestTokensQueue.async {
                guard self._requestTokens.contains(request.token) else { return }
                self._requestTokens.remove(request.token)

                if self._requestTokens.isEmpty {
                    self.resultHandler(result)
                }
            }
        }
    }

    func completeOnClientQueueResponse<S>(for requests: S, completion: @escaping (APIClientQueueResult<Data, APIError>) -> Void) async where S: Sequence, S.Element == APIClientQueueRequest {
        var responseHandlerToken: APIClientQueueResponseHandlerToken?
        responseHandlerToken = await clientQueue.register(
            ClientQueueResponseHandler(requests) { result in
                if let token = responseHandlerToken {
                    Task {
                        await self.clientQueue.unregister(token)
                    }
                }
                completion(result)
            }
        )
    }
}

// MARK: - Synchronization State

private extension RemoteIdentifier {

    var hasBeenPushedToClientQueue: Bool {
        switch _remoteSynchronizationState.value {
        case .pending,
             .synced:
            return true
        case .outOfSync:
            return false
        }
    }

    func willBePushedToClientQueue() {
        guard hasBeenPushedToClientQueue == false else { return }
        _remoteSynchronizationState.value = .pending
    }
}

private extension OrderedDictionary where Value == APIRequestConfig.QueryValue {

    var hasUnsyncedIdentifiers: Bool {
        return orderedValues.contains { $0.hasUnsyncedIdentifiers }
    }
}

private extension APIRequestConfig.QueryValue {

    var hasUnsyncedIdentifiers: Bool {
        switch self {
        case .identifier:
            return true
        case ._value:
            return false
        case ._array(let values):
            return values.contains { $0.hasUnsyncedIdentifiers }
        }
    }
}
