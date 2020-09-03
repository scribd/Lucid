//
// CoreManagerContainer.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid
import Combine

// MARK: - Response Handler

protocol CoreManagerContainerClientQueueResponseHandler: APIClientQueueResponseHandler {
    var managers: CoreManagerContainer? { get set } // Should be declared weak in order to avoid a retain cycle
}
// MARK: - Resolvers

typealias CoreManagerResolver = GenreCoreManagerProviding &
                                MovieCoreManagerProviding

protocol GenreCoreManagerProviding {
    var genreManager: CoreManaging<Genre, AppAnyEntity> { get }
}

protocol MovieCoreManagerProviding {
    var movieManager: CoreManaging<Movie, AppAnyEntity> { get }
}


// MARK: - Container

public final class CoreManagerContainer {

    private let _responseHandler: CoreManagerContainerClientQueueResponseHandler? = nil
    public var responseHandler: APIClientQueueResponseHandler? {
        return _responseHandler
    }

    public let coreDataManager: CoreDataManager

    public let clientQueues: Set<APIClientQueue>
    public let mainClientQueue: APIClientQueue

    private var cancellableStore = Set<AnyCancellable>()

    private let _genreManager: CoreManager<Genre>
    private lazy var _genreRelationshipManager = CoreManaging<Genre, AppAnyEntity>.RelationshipManager(self)
    var genreManager: CoreManaging<Genre, AppAnyEntity> {
        return _genreManager.managing(_genreRelationshipManager)
    }

    private let _movieManager: CoreManager<Movie>
    private lazy var _movieRelationshipManager = CoreManaging<Movie, AppAnyEntity>.RelationshipManager(self)
    var movieManager: CoreManaging<Movie, AppAnyEntity> {
        return _movieManager.managing(_movieRelationshipManager)
    }

    public init(cacheLimit: Int,
                client: APIClient,
                coreDataManager: CoreDataManager = CoreDataManager(modelName: "Sample", in: Bundle(for: CoreManagerContainer.self), migrations: [])) {

        self.coreDataManager = coreDataManager

        var clientQueues = Set<APIClientQueue>()
        var clientQueue: APIClientQueue

        let mainClientQueue = APIClientQueue.clientQueue(
            for: "\(CoreManagerContainer.self)_api_client_queue",
            client: client,
            scheduler: APIClientQueueDefaultScheduler()
        )

        clientQueue = mainClientQueue
        _genreManager = CoreManager(
            stores: Genre.stores(
                with: client,
                clientQueue: &clientQueue,
                coreDataManager: coreDataManager,
                cacheLimit: cacheLimit
            )
        )
        clientQueues.insert(clientQueue)

        clientQueue = mainClientQueue
        _movieManager = CoreManager(
            stores: Movie.stores(
                with: client,
                clientQueue: &clientQueue,
                coreDataManager: coreDataManager,
                cacheLimit: cacheLimit
            )
        )
        clientQueues.insert(clientQueue)

        if let responseHandler = _responseHandler {
            clientQueues.forEach { $0.register(responseHandler) }
        }
        self.clientQueues = clientQueues
        self.mainClientQueue = mainClientQueue

        // Init of lazy vars for thread-safety.
        _ = _genreRelationshipManager
        _ = _movieRelationshipManager

        _responseHandler?.managers = self
    }
}

extension CoreManagerContainer: CoreManagerResolver {
}

// MARK: - Relationship Manager

extension CoreManagerContainer: RelationshipCoreManaging {

    public func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
                    entityType: String,
                    in context: _ReadContext<EndpointResultPayload>) -> AnyPublisher<AnySequence<AppAnyEntity>, ManagerError> {
        switch entityType {
        case GenreIdentifier.entityTypeUID:
            return genreManager.get(
                byIDs: DualHashSet(identifiers.lazy.compactMap { $0.toRelationshipID() }),
                in: context
            ).once.map { $0.lazy.map { .genre($0) }.any }.eraseToAnyPublisher()
        case MovieIdentifier.entityTypeUID:
            return movieManager.get(
                byIDs: DualHashSet(identifiers.lazy.compactMap { $0.toRelationshipID() }),
                in: context
            ).once.map { $0.lazy.map { .movie($0) }.any }.eraseToAnyPublisher()
        default:
            return Fail(error: .notSupported).eraseToAnyPublisher()
        }
    }
}

// MARK: - Persistence Manager

extension CoreManagerContainer: RemoteStoreCachePayloadPersistenceManaging {

    public func persistEntities(from payload: AnyResultPayloadConvertible,
                                accessValidator: Optional<UserAccessValidating>) {

        genreManager
            .set(payload.allEntities(), in: WriteContext(dataTarget: .local, accessValidator: accessValidator))
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellableStore)

        movieManager
            .set(payload.allEntities(), in: WriteContext(dataTarget: .local, accessValidator: accessValidator))
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellableStore)
    }
}

// MARK: - Default Entity Stores

/// Manually add the function:
/// ```
/// static func stores(with client: APIClient,
///                    clientQueue: inout APIClientQueue,
///                    coreDataManager: CoreDataManager,
///                    cacheLimit: Int) -> Array<Storing<Self>>
/// ```
/// to an individual class adopting the Entity protocol to provide custom functionality

extension LocalEntity {
    static func stores(with client: APIClient,
                       clientQueue: inout APIClientQueue,
                       coreDataManager: CoreDataManager,
                       cacheLimit: Int) -> Array<Storing<Self>> {
        let localStore = LRUStore<Self>(store: InMemoryStore().storing, limit: cacheLimit)
        return Array(arrayLiteral: localStore.storing)
    }
}

extension CoreDataEntity {
    static func stores(with client: APIClient,
                       clientQueue: inout APIClientQueue,
                       coreDataManager: CoreDataManager,
                       cacheLimit: Int) -> Array<Storing<Self>> {
        let localStore = CacheStore<Self>(
            keyValueStore: LRUStore(store: InMemoryStore().storing, limit: cacheLimit).storing,
            persistentStore: CoreDataStore(coreDataManager: coreDataManager).storing
        )
        return Array(arrayLiteral: localStore.storing)
    }
}

extension RemoteEntity {
    static func stores(with client: APIClient,
                       clientQueue: inout APIClientQueue,
                       coreDataManager: CoreDataManager,
                       cacheLimit: Int) -> Array<Storing<Self>> {
        let remoteStore = RemoteStore<Self>(client: client, clientQueue: clientQueue)
        return Array(arrayLiteral: remoteStore.storing)
    }
}

extension RemoteEntity where Self : CoreDataEntity {
    static func stores(with client: APIClient,
                       clientQueue: inout APIClientQueue,
                       coreDataManager: CoreDataManager,
                       cacheLimit: Int) -> Array<Storing<Self>> {
        let remoteStore = RemoteStore<Self>(client: client, clientQueue: clientQueue)
        let localStore = CacheStore<Self>(
            keyValueStore: LRUStore(store: InMemoryStore().storing, limit: cacheLimit).storing,
            persistentStore: CoreDataStore(coreDataManager: coreDataManager).storing
        )
        return Array(arrayLiteral: remoteStore.storing, localStore.storing)
    }
}
