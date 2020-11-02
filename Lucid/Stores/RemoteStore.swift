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
    private let decodingQueue = DispatchQueue(label: "\(RemoteStore.self):decoding", attributes: .concurrent)

    // MARK: - Inits

    public init(clientQueue: APIClientQueuing & APIClientQueueFlushing) {
        self.clientQueue = clientQueue
    }

    // MARK: - API

    public func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        guard let identifier = query.identifier else {
            completion(.failure(.identifierNotFound))
            return
        }

        let request: APIRequest<Data>
        let hasCachedResponse: Bool

        let path = RemotePath<E>.get(identifier)

        switch context.dataSource {
        case ._remote(.derivedFromEntityType, _, _, _):
            guard let newRequest = E.request(for: path, or: context.remoteStoreCache.payloadRequest) else {
                Logger.log(.error, "\(Self.self): Remote store could not build valid API request from context \(context)", assert: true)
                completion(.failure(.invalidContext))
                return
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
            completion(.failure(.invalidContext))
            return
        }

        guard request.config.query.hasUnsyncedIdentifiers == false else {
            completion(.failure(.identifierNotSynced))
            return
        }

        context.addListener(for: request.config) { result in
            switch result {
            case .success(.some(let payload as E.ResultPayload)):
                if let entity: E = payload.getEntity(for: identifier) {
                    let metadata = Metadata<E>(payload.metadata)
                    completion(.success(QueryResult(from: entity, metadata: metadata)))
                } else {
                    completion(.failure(.notFoundInPayload))
                }

            case .success(.some(let payload)):
                Logger.log(.error, "\(RemoteStore.self): Could not convert \(type(of: payload)) to \(E.ResultPayload.self).", assert: true)
                completion(.failure(.invalidContext))

            case .success(.none):
                completion(.failure(.emptyResponse))

            case .failure(.api(httpStatusCode: 404, _, _)):
                completion(.success(.empty()))

            case .failure(let error):
                let error = StoreError.api(error)
                Logger.log(.error, "\(RemoteStore.self): Error occurred for request path: \(request.config.path): \(error)")
                completion(.failure(error))
            }
        }

        guard hasCachedResponse == false else { return }

        let requestCompletion: (APIClientQueueResult<Data, APIError>) -> Void = { result in
            switch result {
            case .success(let response):

                let source: RemoteResponseSource = response.cachedResponse ? .urlCache(.empty) : .server(.empty)

                if response.isNotModified {
                    context.set(payloadResult: .success(nil), source: source, for: request.config)
                    return
                }

                self.decodingQueue.async {
                    do {
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

                    } catch {
                        context.set(payloadResult: .failure(.deserialization(error)), source: source, for: request.config)
                    }
                }

            case .aborted:
                context.set(payloadResult: .failure(.network(.cancelled)), source: nil, for: request.config)

            case .failure(let error):
                context.set(payloadResult: .failure(error), source: nil, for: request.config)
            }
        }

        let identifiers = query.identifiers?.array ?? []
        let clientQueueRequest = APIClientQueueRequest(wrapping: request, identifiers: identifiers)
        completeOnClientQueueResponse(for: [clientQueueRequest]) { result in
            requestCompletion(result)
        }
        clientQueue.append(clientQueueRequest)
    }

    private func coreSearch(withQuery query: Query<E>,
                            in context: ReadContext<E>,
                            completion: @escaping (Result<(result: QueryResult<E>, isFromCache: Bool), StoreError>) -> Void) {

        let request: APIRequest<Data>
        let hasCachedResponse: Bool

        switch context.dataSource {
        case ._remote(.derivedFromEntityType, _, _, _):
            let path = RemotePath<E>.search(query)
            guard let newRequest = E.request(for: path, or: context.remoteStoreCache.payloadRequest) else {
                Logger.log(.error, "\(Self.self): could not build valid request.", assert: true)
                completion(.failure(.invalidContext))
                return
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
            completion(.failure(.invalidContext))
            return
        }

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
                completion(.success((searchResult, hasCachedResponse)))

            case .success(.some(let payload)):
                Logger.log(.error, "\(RemoteStore.self): Could not convert \(type(of: payload)) to \(E.ResultPayload.self)", assert: true)
                completion(.failure(.invalidContext))

            case .success(.none):
                completion(.failure(.emptyResponse))

            case .failure(let error):
                let error = StoreError.api(error)
                Logger.log(.error, "\(RemoteStore.self): Error occurred for request path: \(request.config.path): \(error)")
                completion(.failure(error))
            }
        }

        guard hasCachedResponse == false else { return }

        guard request.config.query.hasUnsyncedIdentifiers == false else {
            completion(.failure(.identifierNotSynced))
            return
        }

        let requestCompletion: (APIClientQueueResult<Data, APIError>) -> Void = { result in
            switch result {
            case .success(let response):

                let source: RemoteResponseSource = response.cachedResponse ? .urlCache(response.header) : .server(response.header)

                if response.isNotModified {
                    context.set(payloadResult: .success(nil), source: source, for: request.config)
                    return
                }

                self.decodingQueue.async {
                    do {
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
                    } catch {
                        context.set(payloadResult: .failure(.deserialization(error)), source: source, for: request.config)
                    }
                }

            case .aborted:
                context.set(payloadResult: .failure(.network(.cancelled)), source: nil, for: request.config)

            case .failure(let error):
                context.set(payloadResult: .failure(error), source: nil, for: request.config)
            }
        }

        let identifiers = query.identifiers?.array ?? []
        let clientQueueRequest = APIClientQueueRequest(wrapping: request, identifiers: identifiers)
        completeOnClientQueueResponse(for: [clientQueueRequest]) { result in
            requestCompletion(result)
        }
        clientQueue.append(clientQueueRequest)
    }

    public func search(withQuery query: Query<E>,
                       in context: ReadContext<E>,
                       completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        // Some payloads need to filter out entities which aren't meant to be at their root level.
        // This is due to the fact that payloads made of a tree structure get their data automatically flattened.
        coreSearch(withQuery: query, in: context) { result in
            switch result {
            case .success(let response):

                guard let allItems = response.result.metadata?.allItems else {
                    completion(.success(response.result))
                    return
                }

                let rootIdentifiers = DualHashSet<E.Identifier>(allItems.lazy.compactMap { $0.entityIdentifier() })
                guard rootIdentifiers.isEmpty == false else {
                    completion(.success(response.result))
                    return
                }

                guard response.isFromCache == false else {
                    completion(.success(response.result))
                    return
                }

                let filteredEntities = response.result.filter { rootIdentifiers.contains($0.identifier) }

                completion(.success(QueryResult<E>(fromProcessedEntities: filteredEntities,
                                                   for: query,
                                                   metadata: response.result.metadata)))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {

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
            completion(.failure(.invalidContext))
            return
        }

        guard countMismatch == false else {
            completion(.failure(.notSupported))
            return
        }

        for entity in entities {
            entity.identifier.willBePushedToClientQueue()
        }

        completeOnClientQueueResponse(for: requests) { _ in
            completion(nil)
        }

        for request in requests {
            clientQueue.append(request)
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {

        let path = RemotePath<E>.removeAll(query)
        let identifiers = query.identifiers?.array ?? []
        let clientQueueRequest: APIClientQueueRequest

        switch context.dataTarget {
        case .localAndRemote(.derivedFromEntityType),
             .remote(.derivedFromEntityType):
            guard let request = E.request(for: path, or: nil) else {
                completion(.failure(.notSupported))
                return
            }

            let identifiers = query.identifiers?.array ?? []
            clientQueueRequest = APIClientQueueRequest(wrapping: request, identifiers: identifiers)

        case .localAndRemote(.derivedFromPath),
             .remote(.derivedFromPath):
            Logger.log(.error, "\(Self.self): For .removeAll, use endpoint .request instead.", assert: true)
            return

        case .localAndRemote(.request(let config)),
             .remote(.request(let config)):
            let request = APIRequest<Data>(config)
            clientQueueRequest = APIClientQueueRequest(wrapping: request, identifiers: identifiers)

        case .local:
            Logger.log(.error, "\(Self.self): Remote store should not be attempting to handle data target \(context.dataTarget).", assert: true)
            return
        }

        completeOnClientQueueResponse(for: [clientQueueRequest]) { _ in
            completion(nil)
        }

        clientQueue.append(clientQueueRequest)
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {

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
            completion(.failure(.notSupported))
            return
        }

        completeOnClientQueueResponse(for: requests) { _ in
            completion(nil)
        }

        for request in requests {
            clientQueue.append(request)
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

    func completeOnClientQueueResponse<S>(for requests: S, completion: @escaping (APIClientQueueResult<Data, APIError>) -> Void) where S: Sequence, S.Element == APIClientQueueRequest {
        var responseHandlerToken: APIClientQueueResponseHandlerToken?
        responseHandlerToken = clientQueue.register(
            ClientQueueResponseHandler(requests) { result in
                if let token = responseHandlerToken {
                    self.clientQueue.unregister(token)
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
