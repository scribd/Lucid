//
//  CoreManager.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/21/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import Combine

// MARK: - Error

public enum ManagerError: Error, Equatable {
    case store(StoreError)
    case conflict // Write operation was conflicting with another write operation.
    case notSupported // Operation is not supported.
    case logicalError(description: String?) // CoreManager encountered a logical conflict, e.g. missing or broken data where no error was raised.
    case userAccessInvalid // Operation requires correct user permission.
}

// MARK: - CoreManaging

/// Interface type of a `CoreManager`.
///
/// A `CoreManager` is in charge of synchronizing one type of entities' reads and writes.
///
/// E.g. Querying documents and listening for changes:
/// ```
/// let context = ReadContext<E>(dataSource: .local)
/// documentManager.search(withQuery: .filter(.title ~= ".*Foo.*"), in: context).once.observe { event in
///     ...
/// }.dispose(in: disposeBag)
/// ```
///
/// - Important: Managers are designed to be the entry point of the data layer, thus, any public interaction
///              with an `Entity` needs to pass through its associated `CoreManager`.
///
/// - Requires: Thread-safety
///
/// - Note: Only operations processed on the same instance of a manager are synchronized.
///
/// - Note: A struct is used as a protocol in order to be able to carry the `Entity` type `E`
///         without the limitation of using an `associatedtype`.
public final class CoreManaging<E, AnyEntityType> where E: Entity, AnyEntityType: EntityConvertible {

    // MARK: - Method Types

    public typealias GetEntity = (
        _ query: Query<E>,
        _ context: ReadContext<E>
    ) -> AnyPublisher<QueryResult<E>, ManagerError>

    public typealias SearchEntities = (
        _ query: Query<E>,
        _ context: ReadContext<E>
    ) -> (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnyPublisher<QueryResult<E>, Never>)

    public typealias SetEntity = (
        _ entity: E,
        _ context: WriteContext<E>
    ) -> AnyPublisher<E, ManagerError>

    public typealias SetEntities = (
        _ entities: AnySequence<E>,
        _ context: WriteContext<E>
    ) -> AnyPublisher<AnySequence<E>, ManagerError>

    public typealias RemoveAllEntities = (
        _ query: Query<E>,
        _ context: WriteContext<E>
    ) -> AnyPublisher<AnySequence<E.Identifier>, ManagerError>

    public typealias RemoveEntity = (
        _ identifier: E.Identifier,
        _ context: WriteContext<E>
    ) -> AnyPublisher<Void, ManagerError>

    public typealias RemoveEntities = (
        _ identifiers: AnySequence<E.Identifier>,
        _ context: WriteContext<E>
    ) -> AnyPublisher<Void, ManagerError>

    // MARK: - Async Methor Types

    public typealias GetEntityAsync = (
        _ query: Query<E>,
        _ context: ReadContext<E>
    ) async throws -> QueryResult<E>

    public typealias SearchEntitiesAsync = (
        _ query: Query<E>,
        _ context: ReadContext<E>
    ) async throws -> (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>)

    public typealias SetEntityAsync = (
        _ entity: E,
        _ context: WriteContext<E>
    ) async throws -> E

    public typealias SetEntitiesAsync = (
        _ entities: AnySequence<E>,
        _ context: WriteContext<E>
    ) async throws -> AnySequence<E>

    public typealias RemoveAllEntitiesAsync = (
        _ query: Query<E>,
        _ context: WriteContext<E>
    ) async throws -> AnySequence<E.Identifier>

    public typealias RemoveEntityAsync = (
        _ identifier: E.Identifier,
        _ context: WriteContext<E>
    ) async throws -> Void

    public typealias RemoveEntitiesAsync = (
        _ identifiers: AnySequence<E.Identifier>,
        _ context: WriteContext<E>
    ) async throws -> Void

    // MARK: - Methods

    private let getEntity: GetEntity
    private let getEntityAsync: GetEntityAsync
    private let searchEntities: SearchEntities
    private let searchEntitiesAsync: SearchEntitiesAsync
    private let setEntity: SetEntity
    private let setEntityAsync: SetEntityAsync
    private let setEntities: SetEntities
    private let setEntitiesAsync: SetEntitiesAsync
    private let removeAllEntities: RemoveAllEntities
    private let removeAllEntitiesAsync: RemoveAllEntitiesAsync
    private let removeEntity: RemoveEntity
    private let removeEntityAsync: RemoveEntityAsync
    private let removeEntities: RemoveEntities
    private let removeEntitiesAsync: RemoveEntitiesAsync
    private weak var relationshipManager: RelationshipManager?

    public init(getEntity: @escaping GetEntity,
                getEntityAsync: @escaping GetEntityAsync,
                searchEntities: @escaping SearchEntities,
                searchEntitiesAsync: @escaping SearchEntitiesAsync,
                setEntity: @escaping SetEntity,
                setEntityAsync: @escaping SetEntityAsync,
                setEntities: @escaping SetEntities,
                setEntitiesAsync: @escaping SetEntitiesAsync,
                removeAllEntities: @escaping RemoveAllEntities,
                removeAllEntitiesAsync: @escaping RemoveAllEntitiesAsync,
                removeEntity: @escaping RemoveEntity,
                removeEntityAsync: @escaping RemoveEntityAsync,
                removeEntities: @escaping RemoveEntities,
                removeEntitiesAsync: @escaping RemoveEntitiesAsync,
                relationshipManager: RelationshipManager?) {

        self.getEntity = getEntity
        self.getEntityAsync = getEntityAsync
        self.searchEntities = searchEntities
        self.searchEntitiesAsync = searchEntitiesAsync
        self.setEntity = setEntity
        self.setEntityAsync = setEntityAsync
        self.setEntities = setEntities
        self.setEntitiesAsync = setEntitiesAsync
        self.removeAllEntities = removeAllEntities
        self.removeAllEntitiesAsync = removeAllEntitiesAsync
        self.removeEntity = removeEntity
        self.removeEntityAsync = removeEntityAsync
        self.removeEntities = removeEntities
        self.removeEntitiesAsync = removeEntitiesAsync
        self.relationshipManager = relationshipManager
    }

    // MARK: - API

    /// Retrieve an entity based on its identifier.
    ///
    /// - Parameters:
    ///     - identifier: Entity's identifier.
    ///     - context: Inter queries data pass through.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `Entity` or `ManagerError`.
    ///
    /// - Note: If a new or updated `Entity` is retrieved, elected providers are notified.
    /// - Note: The signal response can be called from a different thread than main.
    public func get(byID identifier: E.Identifier,
                    in context: ReadContext<E> = ReadContext<E>()) -> AnyPublisher<QueryResult<E>, ManagerError> {
        let query = Query<E>.identifier(identifier)
        return getEntity(query, context)
    }

    public func get(byID identifier: E.Identifier, in context: ReadContext<E> = ReadContext<E>()) async throws -> QueryResult<E> {
        let query = Query<E>.identifier(identifier)
        return try await getEntityAsync(query, context)
    }

    /// Run a search query resulting with a filtered/ordered set of entities.
    ///
    /// - Parameters:
    ///     - query: `Query` to run.
    ///     - context: Inter queries data pass through.
    ///
    /// - Returns:
    ///     - Two Signals, `once` and `continuous`.
    ///     - `once` will return a single response of either `QueryResult` or `ManagerError`.
    ///     - `continuous` will return a response of either `QueryResult` or `ManagerError` every time changes occur that
    ///        match the query. It will never be completed and will be retained until you release the dispose bag.
    ///
    /// - Note: For any new or updated retrieved `Entity`, elected providers are notified.
    /// - Note: The signal response can be called from a different thread than main.
    public func search(withQuery query: Query<E>,
                       in context: ReadContext<E> = ReadContext<E>()) -> (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnyPublisher<QueryResult<E>, Never>) {
        return searchEntities(query, context)
    }

    public func search(withQuery query: Query<E>,
                       in context: ReadContext<E> = ReadContext<E>()) async throws -> (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>) {
        return try await searchEntitiesAsync(query, context)
    }

    /// Write an `Entity` to the `Store`.
    ///
    /// - Parameters:
    ///     - entity: `Entity` to write.
    ///     - context: Inter queries data pass through.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `Entity` or `ManagerError`.
    ///
    /// - Note: If the given entity is new or updated, elected providers are notified.
    /// - Note: The signal response can be called from a different thread than main.
    @discardableResult
    public func set(_ entity: E,
                    in context: WriteContext<E>) -> AnyPublisher<E, ManagerError> {
        return setEntity(entity, context)
    }

    @discardableResult
    public func set(_ entity: E,
                    in context: WriteContext<E>) async throws -> E {
        return try await setEntityAsync(entity, context)
    }

    /// Bulk write an array of entities to the `Store`.
    ///
    /// - Parameters:
    ///     - entities: Entities to write.
    ///     - context: Inter queries data pass through.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `[Entity]` or `ManagerError`.
    ///
    /// - Note: The signal response can be called from a different thread than main.
    @discardableResult
    public func set<S>(_ entities: S,
                       in context: WriteContext<E>) -> AnyPublisher<AnySequence<E>, ManagerError> where S: Sequence, S.Element == E {
        return setEntities(entities.any, context)
    }

    @discardableResult
    public func set<S>(_ entities: S,
                       in context: WriteContext<E>) async throws -> AnySequence<E> where S: Sequence, S.Element == E {
        return try await setEntitiesAsync(entities.any, context)
    }

    /// Delete all `Entity` objects that match the query.
    ///
    /// - Parameters:
    ///     - query: `Query` that defines matching entities to be deleted.
    ///     - context: Inter queries data pass through.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `[E.Identifier]` or `ManagerError`.
    ///
    /// - Note: When succeeding, elected providers are notified.
    /// - Note: The signal response can be called from a different thread than main.
    ///
    /// - Warning: `removeAll` needs to perform additional operations in order to ensure the stores' integrity.
    ///            Using `remove(_:in:options:)` is usually preferable.
    @discardableResult
    public func removeAll(withQuery query: Query<E>,
                          in context: WriteContext<E>) -> AnyPublisher<AnySequence<E.Identifier>, ManagerError> {
        return removeAllEntities(query, context)
    }

    @discardableResult
    public func removeAll(withQuery query: Query<E>,
                          in context: WriteContext<E>) async throws -> AnySequence<E.Identifier> {
        return try await removeAllEntitiesAsync(query, context)
    }

    /// Delete an `Entity` based on its identifier.
    ///
    /// - Parameters:
    ///     - identifier: Entity's identifier.
    ///     - context: Inter queries data pass through.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `Void` or `ManagerError`.
    ///
    /// - Note: When succeeding, elected providers are notified.
    /// - Note: The signal response can be called from a different thread than main.
    @discardableResult
    public func remove(atID identifier: E.Identifier,
                       in context: WriteContext<E>) -> AnyPublisher<Void, ManagerError> {
        return removeEntity(identifier, context)
    }

    public func remove(atID identifier: E.Identifier,
                       in context: WriteContext<E>) async throws {
        try await removeEntityAsync(identifier, context)
    }

    /// Bulk delete an `Entity` based on its identifier.
    ///
    /// - Parameters:
    ///     - identifier: Entities' identifiers.
    ///     - context: Inter queries data pass through.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `Void` or `ManagerError`.
    ///
    /// - Note: The signal response can be called from a different thread than main.
    @discardableResult
    public func remove<S>(_ identifiers: S,
                          in context: WriteContext<E>) -> AnyPublisher<Void, ManagerError> where S: Sequence, S.Element == E.Identifier {
        return removeEntities(identifiers.any, context)
    }

    public func remove<S>(_ identifiers: S,
                          in context: WriteContext<E>) async throws where S: Sequence, S.Element == E.Identifier {
        try await removeEntitiesAsync(identifiers.any, context)
    }
}

public extension CoreManaging {

    /// Retrieve entities from the core manager based on a given query.
    ///
    /// - Parameters:
    ///     - context: Context associated to the query.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `[Entity]` or `ManagerError`.
    func all(in context: ReadContext<E> = ReadContext<E>()) -> AnyPublisher<QueryResult<E>, ManagerError> {
        return search(withQuery: .all, in: context).once
    }

    func all(in context: ReadContext<E> = ReadContext<E>()) async throws -> QueryResult<E> {
        return try await search(withQuery: .all, in: context).once
    }

    /// Retrieve the first entity found from the core manager based on a given query.
    ///
    /// - Parameters:
    ///     - query: Criteria to run the search query.
    ///     - context: Context associated to the query.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `Entity` or `ManagerError`.
    func first(for query: Query<E> = .all,
               in context: ReadContext<E> = ReadContext<E>()) -> AnyPublisher<E?, ManagerError> {
        return search(withQuery: query, in: context).once.map { $0.first }.eraseToAnyPublisher()
    }

    func first(for query: Query<E> = .all,
               in context: ReadContext<E> = ReadContext<E>()) async throws -> E? {
        return try await search(withQuery: query, in: context).once.first
    }

    /// Retrieve entities that match one of the given identifiers.
    ///
    /// - Parameters:
    ///     - identifiers: List of identifiers used to build an OR query.
    ///     - context: Context associated to the query.
    ///
    /// - Returns:
    ///     - Two Signals, `once` and `continuous`.
    ///     - `once` will return a single response of either `QueryResult<Entity>` or `ManagerError`.
    ///     - `continuous` will return a response of either `[Entity]` or `ManagerError` every time changes occur that
    ///        match the query. It will never be completed and will be retained until you release the dispose bag.
    func get<S>(byIDs identifiers: S,
                in context: ReadContext<E> = ReadContext<E>()) -> (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnyPublisher<QueryResult<E>, Never>)
        where S: Sequence, S.Element == E.Identifier {

            return search(withQuery: .identifiers(identifiers.any), in: context)
    }

    func get<S>(byIDs identifiers: S,
                in context: ReadContext<E> = ReadContext<E>()) async throws -> (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>)
        where S: Sequence, S.Element == E.Identifier {

            let query = Query<E>.filter(.identifier >> identifiers).order([.identifiers(identifiers.any)])

            return try await search(withQuery: query, in: context)
    }
}

public extension CoreManaging where E: RemoteEntity {

    /// Retrieve the first entity, with associated metadata, found from the core manager based on a given query.
    ///
    /// - Parameters:
    ///     - query: Criteria to run the search query.
    ///     - context: Context associated to the query.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `(Entity, Metadata)` or `ManagerError`.
    func firstWithMetadata(for query: Query<E>? = .all,
                           in context: ReadContext<E> = ReadContext<E>()) -> AnyPublisher<QueryResult<E>, ManagerError> {

        let signals = search(withQuery: query ?? .all, in: context)
        return signals.once.map { result -> QueryResult<E> in
            guard let entity = result.entity, let metadata = result.metadata else { return .empty() }
            return QueryResult<E>(from: entity, metadata: metadata)
        }.eraseToAnyPublisher()
    }

    func firstWithMetadata(for query: Query<E>? = .all,
                           in context: ReadContext<E> = ReadContext<E>()) async throws -> QueryResult<E> {

        let result = try await search(withQuery: query ?? .all, in: context).once
        guard let entity = result.entity, let metadata = result.metadata else { return .empty() }
        return QueryResult<E>(from: entity, metadata: metadata)
    }
}

public extension CoreManaging where E.Identifier == VoidEntityIdentifier {

    func get(in context: ReadContext<E> = ReadContext<E>()) -> AnyPublisher<QueryResult<E>, ManagerError> {
        return getEntity(Query.identifier(VoidEntityIdentifier()), context)
    }

    func get(in context: ReadContext<E> = ReadContext<E>()) async throws -> QueryResult<E> {
        return try await getEntityAsync(Query.identifier(VoidEntityIdentifier()), context)
    }
}

// MARK: - CoreManager

public final class CoreManager<E> where E: Entity {

    // MARK: - Dependencies

    private let stores: [Storing<E>]
    private let storeStackQueues = StoreStackQueues<E>()
    private let localStore: StoreStack<E>

    private let operationTaskQueue = AsyncTaskQueue()
    private let raiseEventsTaskQueue = AsyncTaskQueue()

    private let propertyCache = PropertyCache()

    private let combineOperationQueue: AsyncOperationQueue
    private let updatesMetadataQueue = DispatchQueue(label: "\(CoreManager.self):updates_metadata")
    private var _updatesMetadata = DualHashDictionary<E.Identifier, UpdateTime>()

    // MARK: - Inits

    convenience public init(stores: [Storing<E>]) {
        self.init(stores: stores, dispatchQueue: DispatchQueue(label: "\(CoreManager<E>.self):combine_operations"))
    }

    init(stores: [Storing<E>], dispatchQueue: DispatchQueue) {
        self.stores = stores
        self.combineOperationQueue = AsyncOperationQueue(dispatchQueue: dispatchQueue)
        localStore = StoreStack(stores: stores.local(), queues: storeStackQueues)
    }

    public func managing<AnyEntityType>(_ relationshipManager: CoreManaging<E, AnyEntityType>.RelationshipManager? = nil) -> CoreManaging<E, AnyEntityType> where AnyEntityType: EntityConvertible {
        return CoreManaging(getEntity: { self.get(withQuery: $0, in: $1) },
                            getEntityAsync: { try await self.get(withQuery: $0, in: $1) },
                            searchEntities: { self.search(withQuery: $0, in: $1) },
                            searchEntitiesAsync: { try await self.search(withQuery: $0, in: $1) },
                            setEntity: { self.set($0, in: $1) },
                            setEntityAsync: { try await self.set($0, in: $1) },
                            setEntities: { self.set($0, in: $1) },
                            setEntitiesAsync: { try await self.set($0, in: $1) },
                            removeAllEntities: { self.removeAll(withQuery: $0, in: $1) },
                            removeAllEntitiesAsync: { try await self.removeAll(withQuery: $0, in: $1) },
                            removeEntity: { self.remove(atID: $0, in: $1) },
                            removeEntityAsync: { try await self.remove(atID: $0, in: $1) },
                            removeEntities: { self.remove($0, in: $1) },
                            removeEntitiesAsync: { try await self.remove($0, in: $1) },
                            relationshipManager: relationshipManager)
    }
}

private extension CoreManager {

    // MARK: - API

    ///
    /// - Note: Performs a local/remote fetch depending on how the data source is configured.
    ///
    /// - `localThenRemote` -> Performs local fetch then remote fetch if local result isn't found. Always provide the result coming from the local store.
    /// - `localOrRemote` -> Performs local fetch. If a result is found, provide that result. If no result is found, fetch from remote and provide the remote result instead.
    /// - `remoteOrLocal` -> Perform a remote fetch. If any error arises (connectivity, wrong request, ...), fallbacks to local.
    /// - `remote` -> Performs a remote fetch only.
    /// - `local` -> Performs a local fetch only.
    ///
    func get(withQuery query: Query<E>,
             in context: ReadContext<E>) -> AnyPublisher<QueryResult<E>, ManagerError> {

        return Publishers.QueuedReplayOnce(combineOperationQueue) { promise, completion in
            Task(priority: .low) {
                do {
                    async let result = try await self.get(withQuery: query, in: context)
                    Task(priority: .low) {
                        try? await Task.sleep(nanoseconds: NSEC_PER_MSEC / 10) // 0.1 milliseconds
                        completion()
                    }
                    try await promise(.success(result))
                } catch let error as ManagerError {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func get(withQuery query: Query<E>,
             in context: ReadContext<E>) async throws -> QueryResult<E> {
        let queryIdentifiers = query.identifiers?.array ?? []
        if queryIdentifiers.count != 1 {
            Logger.log(.error, "\(CoreManager.self) get must be called with a single identifier. Instead found \(queryIdentifiers.count)", assert: true)
        }

        guard let identifier = queryIdentifiers.first else {
            Logger.log(.error, "\(CoreManager.self) can not perform get without valid identifier", assert: true)
            throw ManagerError.notSupported
        }

        if let remoteContext = context.remoteContextAfterMakingLocalRequest {
            let localContext = ReadContext<E>(dataSource: .local, contract: context.contract, accessValidator: context.accessValidator)
            let localResult: QueryResult<E>
            do {
                localResult = try await self.get(withQuery: query, in: localContext)
            } catch {
                localResult = .empty()
            }

            if localResult.entity != nil {
                if context.shouldFetchFromRemoteWhileFetchingFromLocalStore {
                    Task(priority: .high) {
                        _ = try? await self.get(withQuery: query, in: remoteContext)
                    }
                }
                return localResult
            } else {
                do {
                    let remoteResult = try await self.get(withQuery: query, in: remoteContext)
                    return remoteResult
                } catch let error as ManagerError {
                    if error.shouldFallBackToLocalStore {
                        // if we can't reach the remote store, return local results
                        return localResult
                    } else {
                        throw error
                    }
                }
            }
        } else {
            guard context.requestAllowedForAccessLevel else {
                throw ManagerError.userAccessInvalid
            }

            let initialUserAccess = context.userAccess

            let result = try await self.operationTaskQueue.enqueueBarrier { operationCompletion in
                let time = UpdateTime()
                let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)

                operationCompletion()

                let result = await storeStack.get(withQuery: query, in: context)
                switch result {
                case .success(let queryResult):

                    if context.shouldOverwriteInLocalStores {
                        guard self.canUpdate(identifier: identifier, basedOn: time) else {
                            return queryResult
                        }
                        self.setUpdateTime(time, for: identifier)

                        if let entity = queryResult.entity {
                            let result = await self.localStore.set(entity, in: WriteContext(dataTarget: .local))
                            switch result {
                            case .failure(let error):
                                Logger.log(.error, "\(CoreManager.self): An error occurred while writing entity: \(error)", assert: true)
                            case .success,
                                 .none:
                                break
                            }
                            self.raiseUpdateEvents(withQuery: .identifier(identifier),
                                                   results: .entities([entity]),
                                                   returnsCompleteResultSet: context.returnsCompleteResultSet)
                            return queryResult
                        } else {
                            let result = await self.localStore.remove(atID: identifier, in: WriteContext(dataTarget: .local))
                            switch result {
                            case .failure(let error):
                                Logger.log(.error, "\(CoreManager.self): An error occurred while deleting entity: \(error)", assert: true)
                            case .success,
                                 .none:
                                break
                            }
                            self.raiseDeleteEvents(DualHashSet([identifier]))
                            return .empty()
                        }
                    } else {
                        return queryResult
                    }

                case .failure(let error):
                    if error.shouldFallBackToLocalStore {
                        Logger.log(.debug, "\(CoreManager.self): Did not receive data while getting entity: \(error). Will fall back to local store if possible.")
                    } else {
                        Logger.log(.error, "\(CoreManager.self): An error occurred while getting entity: \(error)", assert: true)
                    }
                    throw ManagerError.store(error)
                }
            }

            guard context.responseAllowedForAccessLevel,
                initialUserAccess == context.userAccess else {
                throw ManagerError.userAccessInvalid
            }
            return result
        }
    }

    ///
    /// - Note: Performs a local/remote fetch depending on how the data source is configured.
    ///
    /// - `localThenRemote` -> Performs local fetch then remote fetch if local result isn't satisfying (1). Always provide the result coming from the local store.
    /// - `localOrRemote` -> Performs local fetch. If a result is found, provide that result. If no result is found, fetch from remote and provide the remote result instead.
    /// - `remote` -> Performs a remote fetch only.
    /// - `local` -> Performs a local fetch only.
    ///
    /// (1) A result is considered unsatisfying if the query is only composed of identifiers and some of these identifiers aren't contained in the result.
    ///
    func search(withQuery query: Query<E>,
                in context: ReadContext<E>) -> (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnySafePublisher<QueryResult<E>>) {

        let signals: () async throws -> (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>) =  {
            return try await self.search(withQuery: query, in: context)
        }

        let asyncToCombine = CoreManagerAsyncToCombineProperty<E, ManagerError>(combineOperationQueue, signals)

        return (
            once: asyncToCombine.once.eraseToAnyPublisher(),
            continuous: asyncToCombine.continuous.eraseToAnyPublisher()
        )
    }

    private typealias SearchResult = (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>)

    func search(withQuery query: Query<E>,
                in context: ReadContext<E>) async throws -> (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>) {

        if let remoteContext = context.remoteContextAfterMakingLocalRequest {
            let localContext = ReadContext<E>(dataSource: .local, contract: context.contract, accessValidator: context.accessValidator)

            let overwriteSearches: (SearchResult?) async throws -> SearchResult = { localResults in
                do {
                    let result = try await self.search(withQuery: query, in: remoteContext)
                    return result
                } catch let error as ManagerError {
                    if error.shouldFallBackToLocalStore, let localResults = localResults {
                        // if we can't reach the remote store, return local results
                        return localResults
                    } else {
                        throw error
                    }
                }
            }

            let localResults: SearchResult
            do {
                localResults = try await search(withQuery: query, in: localContext)
            } catch {
                return try await overwriteSearches(nil)
            }

            let searchIdentifierCount = query.filter?.extractOrIdentifiers?.map { $0 }.count ?? 0
            let entityResultCount = localResults.once.count

            let hasAllIdentifiersLocally = searchIdentifierCount > 0 && entityResultCount >= searchIdentifierCount
            let hasResultsForComplexSearch = searchIdentifierCount == 0 && entityResultCount > 0

            if hasAllIdentifiersLocally || hasResultsForComplexSearch {
                if context.shouldFetchFromRemoteWhileFetchingFromLocalStore {
                    Task(priority: .high) {
                        _ = try await overwriteSearches(nil).once
                    }
                }
                return localResults
            } else {
                return try await overwriteSearches(localResults)
            }
        }

        let property = await propertyCache.preparePropertiesForSearchUpdate(forQuery: query, context: context)

        guard context.requestAllowedForAccessLevel else {
            throw ManagerError.userAccessInvalid
        }

        let initialUserAccess = context.userAccess

        let time = UpdateTime()
        let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)

        let once: () async throws -> QueryResult<E> = {

            let result: QueryResult<E> = try await self.operationTaskQueue.enqueueBarrier { operationCompletion in
                operationCompletion()

                let result = await storeStack.search(withQuery: query, in: context)
                switch result {
                case .success(let remoteResults):
                    let remoteResults = remoteResults.materialized

                    if context.shouldOverwriteInLocalStores {

                        let localResult = await self.localStore.search(withQuery: query.order([]), in: context)
                        switch localResult {
                        case .success(let localResults):
                            var identifiersToDelete: [E.Identifier] = []
                            if context.returnsCompleteResultSet {
                                var identifiersToDeleteSet = DualHashSet(localResults.lazy.compactMap {
                                    $0.identifier.remoteSynchronizationState == .synced ? $0.identifier : nil
                                })
                                identifiersToDeleteSet.subtract(DualHashSet(remoteResults.lazy.map { $0.identifier }))
                                identifiersToDelete = self.filter(identifiers: identifiersToDeleteSet.lazy.map { $0 }, basedOn: time).compactMap { $0 }
                            }

                            let entitiesToUpdate = self.filter(entities: remoteResults, basedOn: time).compactMap { $0 }
                            guard entitiesToUpdate.count + identifiersToDelete.count > 0 else {
                                return remoteResults
                            }
                            self.setUpdateTime(time, for: entitiesToUpdate.map { $0.identifier } + identifiersToDelete)

                            // Create immutable versions to use within Tasks
                            let finalIdentifiersToDelete = identifiersToDelete
                            let finalEntitiesToUpdate = entitiesToUpdate
                            await withTaskGroup(of: Void.self) { group in
                                if finalEntitiesToUpdate.isEmpty == false {
                                    group.addTask(priority: .high) {
                                        let result = await self.localStore.set(finalEntitiesToUpdate, in: WriteContext(dataTarget: .local))
                                        if let error = result?.error {
                                            Logger.log(.error, "\(CoreManager.self): An error occurred while writing entities: \(error)", assert: true)
                                        }
                                    }
                                }

                                if finalIdentifiersToDelete.isEmpty == false {
                                    group.addTask(priority: .high) {
                                        let result = await self.localStore.remove(finalIdentifiersToDelete, in: WriteContext(dataTarget: .local))
                                        if let error = result?.error {
                                            Logger.log(.error, "\(CoreManager.self): An error occurred while deleting entities: \(error)", assert: true)
                                        }
                                    }
                                }

                                self.raiseUpdateEvents(withQuery: query,
                                                       results: remoteResults,
                                                       returnsCompleteResultSet: context.returnsCompleteResultSet)
                            }
                            return remoteResults

                        case .failure(let error):
                            Logger.log(.error, "\(CoreManager.self): An error occurred while searching entities: \(error)", assert: true)

                            let entitiesToUpdate = self.filter(entities: remoteResults, basedOn: time).compactMap { $0 }
                            guard entitiesToUpdate.isEmpty == false else {
                                return remoteResults
                            }
                            self.setUpdateTime(time, for: entitiesToUpdate.lazy.map { $0.identifier })

                            let result = await self.localStore.set(entitiesToUpdate, in: WriteContext(dataTarget: .local))
                            if let error = result?.error {
                                Logger.log(.error, "\(CoreManager.self): An error occurred while writing entities: \(error)", assert: true)
                            }
                            self.raiseUpdateEvents(withQuery: query,
                                                   results: remoteResults,
                                                   returnsCompleteResultSet: context.returnsCompleteResultSet)
                            return remoteResults
                        }
                    } else {
                        Task(priority: .high) {
                            await property.update(with: remoteResults)
                        }
                        return remoteResults
                    }

                case .failure(let error):
                    if error.shouldFallBackToLocalStore {
                        Logger.log(.debug, "\(CoreManager.self): Did not receive data while searching entities: \(error). Will fall back to local store if possible.")
                    } else {
                        Logger.log(.error, "\(CoreManager.self): An error occurred while searching entities: \(error)", assert: true)
                    }
                    throw ManagerError.store(error)
                }
            }

            guard context.responseAllowedForAccessLevel,
                  initialUserAccess == context.userAccess else {
                throw ManagerError.userAccessInvalid
            }
            
            return result
        }

        let continuous = AsyncStream<QueryResult<E>>() { continuation in

            let iterator = property.stream.makeAsyncIterator()
            let task = Task(priority: .high) {
                for try await value in iterator {
                    guard let value = (value ?? nil) else { continue }
                    continuation.yield(value)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                Task(priority: .high) {
                    await property.stream.cancelIterator(iterator)
                }
            }
        }

        return (
            once: try await once(),
            continuous: continuous
        )
    }

    func set(_ entity: E,
             in context: WriteContext<E>) -> AnyPublisher<E, ManagerError> {

        return Publishers.QueuedReplayOnce(combineOperationQueue) { promise, completion in
            Task(priority: .low) {
                do {
                    async let result = try await self.set(entity, in: context)
                    Task(priority: .low) {
                        try? await Task.sleep(nanoseconds: NSEC_PER_MSEC / 10) // 0.1 milliseconds
                        completion()
                    }
                    try await promise(.success(result))
                } catch let error as ManagerError {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func set(_ entity: E,
             in context: WriteContext<E>) async throws -> E {

        guard context.requestAllowedForAccessLevel else {
            throw ManagerError.userAccessInvalid
        }

        let initialUserAccess = context.userAccess

        let result = try await self.operationTaskQueue.enqueueBarrier { operationCompletion in
            let time = UpdateTime(timestamp: context.originTimestamp)

            guard self.canUpdate(identifier: entity.identifier, basedOn: time) else {
                operationCompletion()
                let result = await self.localStore.get(withQuery: Query.identifier(entity.identifier), in: ReadContext<E>())
                switch result {
                case .success(let queryResult):
                    if let entity = queryResult.entity {
                        return entity
                    } else {
                        throw ManagerError.conflict
                    }
                case .failure(let error):
                    Logger.log(.error, "\(CoreManager.self): An error occurred while setting entity: \(error)")
                    throw ManagerError.store(error)
                }
            }

            self.setUpdateTime(time, for: entity.identifier)
            let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)

            operationCompletion()
            let result = await storeStack.set(entity, in: context, localStoresCompletion: { result in
                guard let updatedEntity = result?.value else { return }
                self.raiseUpdateEvents(withQuery: .identifier(updatedEntity.identifier), results: .entities([updatedEntity]))
            })

            switch result {
            case .success(let updatedEntity):
                self.raiseUpdateEvents(withQuery: .identifier(updatedEntity.identifier), results: .entities([updatedEntity]))
                return updatedEntity

            case .none:
                self.raiseUpdateEvents(withQuery: .identifier(entity.identifier), results: .entities([entity]))
                return entity

            case .failure(let error):
                Logger.log(.error, "\(CoreManager.self): An error occurred while setting entity: \(error)")
                throw ManagerError.store(error)
            }
        }

        guard context.responseAllowedForAccessLevel,
            initialUserAccess == context.userAccess else {
            throw ManagerError.userAccessInvalid
        }

        return result
    }

    func set<S>(_ entities: S,
                in context: WriteContext<E>) -> AnyPublisher<AnySequence<E>, ManagerError> where S: Sequence, S.Element == E {

        let entities = Array(entities)

        return Publishers.QueuedReplayOnce(combineOperationQueue) { promise, completion in
            Task(priority: .low) {
                do {
                    async let result = try await self.set(entities, in: context)
                    Task(priority: .low) {
                        try? await Task.sleep(nanoseconds: NSEC_PER_MSEC / 10) // 0.1 milliseconds
                        completion()
                    }
                    try await promise(.success(result))
                } catch let error as ManagerError {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func set<S>(_ entities: S,
                in context: WriteContext<E>) async throws -> AnySequence<E> where S: Sequence, S.Element == E {
        let entities = Array(entities)

        guard context.requestAllowedForAccessLevel else {
            throw ManagerError.userAccessInvalid
        }

        let initialUserAccess = context.userAccess

        let result: AnySequence<E> = try await self.operationTaskQueue.enqueueBarrier { operationCompletion in
            let time = UpdateTime(timestamp: context.originTimestamp)
            var entitiesToUpdate = OrderedDualHashDictionary(
                self.updateTime(for: entities.lazy.map { $0.identifier })
                    .enumerated()
                    .map { (index, updateTime) -> (E.Identifier, E?) in
                        let entity = entities[index]
                        if UpdateTime.isChronological(updateTime, time) {
                            return (entity.identifier, entity)
                        } else {
                            return (entity.identifier, nil)
                        }
                    }
            )

            guard entitiesToUpdate.isEmpty == false else {
                operationCompletion()
                return .empty
            }

            self.setUpdateTime(time, for: entitiesToUpdate.lazy.compactMap { $0.1?.identifier })

            let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)

            operationCompletion()

            let result = await storeStack.set(entitiesToUpdate.lazy.compactMap { $0.1 }, in: context, localStoresCompletion: { result in
                guard let updatedEntities = result?.value else { return }
                self.raiseUpdateEvents(withQuery: .filter(.identifier >> updatedEntities.lazy.map { $0.identifier }),
                                       results: .entities(updatedEntities))
            })
            switch result {
            case .success(let updatedEntities):
                for entity in updatedEntities {
                    entitiesToUpdate[entity.identifier] = entity
                }
                for entity in entities where entitiesToUpdate[entity.identifier] == nil {
                    entitiesToUpdate[entity.identifier] = entity
                }
                self.raiseUpdateEvents(withQuery: .filter(.identifier >> updatedEntities.lazy.map { $0.identifier }),
                                       results: .entities(updatedEntities))
                return entitiesToUpdate.lazy.compactMap { $0.1 }.any

            case .none:
                self.raiseUpdateEvents(withQuery: .filter(.identifier >> entities.lazy.map { $0.identifier }),
                                       results: .entities(entities))
                return entities.any

            case .failure(let error):
                Logger.log(.error, "\(CoreManager.self): An error occurred while setting entities: \(error)")
                throw ManagerError.store(error)
            }
        }

        guard context.responseAllowedForAccessLevel,
            initialUserAccess == context.userAccess else {
            throw ManagerError.userAccessInvalid
        }

        return result
    }

    func removeAll(withQuery query: Query<E>,
                   in context: WriteContext<E>) -> AnyPublisher<AnySequence<E.Identifier>, ManagerError> {

        return Publishers.QueuedReplayOnce(combineOperationQueue) { promise, completion in
            Task(priority: .low) {
                do {
                    async let result = try await self.removeAll(withQuery: query, in: context)
                    Task(priority: .low) {
                        try? await Task.sleep(nanoseconds: NSEC_PER_MSEC / 10) // 0.1 milliseconds
                        completion()
                    }
                    try await promise(.success(result))
                } catch let error as ManagerError {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func removeAll(withQuery query: Query<E>,
                   in context: WriteContext<E>) async throws -> AnySequence<E.Identifier> {
        guard context.requestAllowedForAccessLevel else {
            throw ManagerError.userAccessInvalid
        }

        let initialUserAccess = context.userAccess

        let result = try await self.operationTaskQueue.enqueueBarrier { operationCompletion in
            let time = UpdateTime(timestamp: context.originTimestamp)

            operationCompletion()

            let result = await self.localStore.search(withQuery: query, in: ReadContext<E>())
            switch result {
            case .success(var results):
                results.materialize()

                let entitiesToRemove = self.filter(entities: results.any, basedOn: time).compactMap { $0 }
                guard entitiesToRemove.isEmpty == false else {
                    return AnySequence<E.Identifier>.empty
                }
                let identifiersToRemove = entitiesToRemove.lazy.map { $0.identifier }
                self.setUpdateTime(time, for: identifiersToRemove)

                let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)
                if entitiesToRemove.count == results.count {
                    let result = await storeStack.removeAll(withQuery: query, in: context, localStoresCompletion: { result in
                        guard let removedIdentifiers = result?.value else { return }
                        self.raiseDeleteEvents(DualHashSet(removedIdentifiers))
                    })
                    switch result {
                    case .success(let removedIdentifiers):
                        self.raiseDeleteEvents(DualHashSet(removedIdentifiers))
                        return removedIdentifiers

                    case .none:
                        let removedIdentifiers = entitiesToRemove.map { $0.identifier }.any
                        self.raiseDeleteEvents(DualHashSet(removedIdentifiers))
                        return removedIdentifiers

                    case .failure(let error):
                        Logger.log(.error, "\(CoreManager.self): An error occurred while removing all entities in query: \(error)")
                        throw ManagerError.store(error)
                    }
                } else {
                    let result = await storeStack.remove(identifiersToRemove, in: context, localStoresCompletion: { result in
                        guard result?.error == nil else { return }
                        self.raiseDeleteEvents(DualHashSet(identifiersToRemove))
                    })
                    switch result {
                    case .success, .none:
                        self.raiseDeleteEvents(DualHashSet(identifiersToRemove))
                        return identifiersToRemove.any

                    case .failure(let error):
                        Logger.log(.error, "\(CoreManager.self): An error occurred while removing entities for identifiers: \(error)")
                        throw ManagerError.store(error)
                    }
                }

            case .failure(let error):
                Logger.log(.error, "\(CoreManager.self): An error occurred while searching for entities to remove all: \(error)")
                throw ManagerError.store(error)
            }
        }

        guard context.responseAllowedForAccessLevel,
            initialUserAccess == context.userAccess else {
            throw ManagerError.userAccessInvalid
        }
        return result
    }

    func remove(atID identifier: E.Identifier,
                in context: WriteContext<E>) -> AnyPublisher<Void, ManagerError> {

        return Publishers.QueuedReplayOnce(combineOperationQueue) { promise, completion in
            Task(priority: .low) {
                do {
                    async let result: Void = try await self.remove(atID: identifier, in: context)
                    Task(priority: .low) {
                        try? await Task.sleep(nanoseconds: NSEC_PER_MSEC / 10) // 0.1 milliseconds
                        completion()
                    }
                    try await result
                    promise(.success(()))
                } catch let error as ManagerError {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func remove(atID identifier: E.Identifier,
                in context: WriteContext<E>) async throws {

        guard context.requestAllowedForAccessLevel else {
            throw ManagerError.userAccessInvalid
        }

        let initialUserAccess = context.userAccess

        try await operationTaskQueue.enqueueBarrier { operationCompletion in
            let time = UpdateTime(timestamp: context.originTimestamp)
            guard self.canUpdate(identifier: identifier, basedOn: time) else {
                operationCompletion()
                return
            }
            self.setUpdateTime(time, for: identifier)

            let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)

            operationCompletion()

            let result = await storeStack.remove(atID: identifier, in: context, localStoresCompletion: { result in
                guard result?.error == nil else { return }
                self.raiseDeleteEvents(DualHashSet([identifier]))
            })
            switch result {
            case .success,
                 .none:
                self.raiseDeleteEvents(DualHashSet([identifier]))

            case .failure(let error):
                Logger.log(.error, "\(CoreManager.self): An error occurred while removing entity: \(error)")
            }
        }

        guard context.responseAllowedForAccessLevel,
            initialUserAccess == context.userAccess else {
            throw ManagerError.userAccessInvalid
        }
    }

    func remove<S>(_ identifiers: S,
                   in context: WriteContext<E>) -> AnyPublisher<Void, ManagerError> where S: Sequence, S.Element == E.Identifier {

        return Publishers.QueuedReplayOnce(combineOperationQueue) { promise, completion in
            Task(priority: .low) {
                do {
                    async let result: Void = try await self.remove(identifiers, in: context)
                    Task(priority: .low) {
                        try? await Task.sleep(nanoseconds: NSEC_PER_MSEC / 10) // 0.1 milliseconds
                        completion()
                    }
                    try await result
                    promise(.success(()))
                } catch let error as ManagerError {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func remove<S>(_ identifiers: S,
                   in context: WriteContext<E>) async throws where S: Sequence, S.Element == E.Identifier {

        guard context.requestAllowedForAccessLevel else {
            throw ManagerError.userAccessInvalid
        }

        let initialUserAccess = context.userAccess

        try await operationTaskQueue.enqueueBarrier { operationCompletion in

            let time = UpdateTime(timestamp: context.originTimestamp)
            let identifiersToRemove = self.filter(identifiers: identifiers, basedOn: time).lazy.compactMap { $0 }

            self.setUpdateTime(time, for: identifiersToRemove)

            let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)

            operationCompletion()

            guard identifiersToRemove.isEmpty == false else {
                return
            }

            let result = await storeStack.remove(identifiersToRemove, in: context, localStoresCompletion: { result in
                guard result?.error == nil else { return }
                self.raiseDeleteEvents(DualHashSet(identifiersToRemove))
            })
            switch result {
            case .success,
                 .none:
                self.raiseDeleteEvents(DualHashSet(identifiersToRemove))

            case .failure(let error):
                Logger.log(.error, "\(CoreManager.self): An error occurred while removing entities: \(error)")
            }
        }

        guard context.responseAllowedForAccessLevel,
            initialUserAccess == context.userAccess else {
            throw ManagerError.userAccessInvalid
        }
    }
}

// MARK: - MutableEntity Actions

extension CoreManaging where E: MutableEntity {

    public func setAndUpdateIdentifierInLocalStores(_ entity: E, originTimestamp: UInt64) -> AnySafePublisher<Void> {
        let context = WriteContext<E>(dataTarget: .local, remoteSyncState: .createResponse(originTimestamp))
        return set(entity, in: context)
            .flatMap { storedResult -> AnyPublisher<Void, ManagerError> in
                storedResult.merge(identifier: entity.identifier)
                let context = WriteContext<E>(dataTarget: .local, remoteSyncState: .mergeIdentifier)
                return self.set(storedResult, in: context).map { _ in }.eraseToAnyPublisher()
            }
            .replaceError(with: ())
            .eraseToAnyPublisher()
    }

    public func setAndUpdateIdentifierInLocalStores(_ entity: E, originTimestamp: UInt64) async {
        let context = WriteContext<E>(dataTarget: .local, remoteSyncState: .createResponse(originTimestamp))
        do {
            let storedResult = try await set(entity, in: context)
            storedResult.merge(identifier: entity.identifier)
            let mergeContext = WriteContext<E>(dataTarget: .local, remoteSyncState: .mergeIdentifier)
            _ = try await self.set(storedResult, in: mergeContext)
        } catch {
            Logger.log(.error, "\(CoreManaging.self) failed to set and update entity identifier locally")
        }
    }

    public func removeFromLocalStores(_ identifier: E.Identifier, originTimestamp: UInt64) -> AnySafePublisher<Void> {
        let context = WriteContext<E>(dataTarget: .local, remoteSyncState: .createResponse(originTimestamp))
        return remove(atID: identifier, in: context)
            .map { _ in }
            .replaceError(with: ())
            .eraseToAnyPublisher()
    }

    public func removeFromLocalStores(_ identifier: E.Identifier, originTimestamp: UInt64) async {
        let context = WriteContext<E>(dataTarget: .local, remoteSyncState: .createResponse(originTimestamp))
        do {
            _ = try await remove(atID: identifier, in: context)
        } catch {
            Logger.log(.error, "\(CoreManaging.self) failed to remove entity locally")
        }
    }
}

// MARK: - Updates Synchronization

private extension CoreManager {

    struct UpdateTime {
        var timestamp: UInt64 = timestampInNanoseconds()

        init(timestamp: UInt64? = nil) {
            self.timestamp = timestamp ?? timestampInNanoseconds()
        }

        static func isChronological(_ previous: UpdateTime?, _ current: UpdateTime) -> Bool {
            guard let previous = previous else { return true }
            guard current.timestamp != .max, previous.timestamp != .max else { return true }
            return current.timestamp > previous.timestamp
        }
    }

    func updateTime(for identifier: E.Identifier) -> UpdateTime? {
        return updatesMetadataQueue.sync { _updatesMetadata[identifier] }
    }

    func updateTime<S>(for identifiers: S) -> [UpdateTime?] where S: Sequence, S.Element == E.Identifier {
        return updatesMetadataQueue.sync { identifiers.map { _updatesMetadata[$0] } }
    }

    func canUpdate(identifier: E.Identifier, basedOn time: UpdateTime) -> Bool {
        return UpdateTime.isChronological(updateTime(for: identifier), time)
    }

    func filter<S>(entities: S, basedOn time: UpdateTime) -> AnySequence<E?> where S: Sequence, S.Element == E {
        let entities = Array(entities)
        return filter(identifiers: entities.lazy.map { $0.identifier }, basedOn: time).lazy.enumerated().map { (index, identifier) in
            identifier == nil ? nil : entities[index]
        }.any
    }

    func filter<S>(identifiers: S, basedOn time: UpdateTime) -> AnySequence<E.Identifier?> where S: Sequence, S.Element == E.Identifier {
        let identifiers = Array(identifiers)
        return updateTime(for: identifiers).lazy.enumerated().map { (index, updateTime) -> E.Identifier? in
            if UpdateTime.isChronological(updateTime, time) {
                return identifiers[index]
            } else {
                return nil
            }
        }.any
    }

    func setUpdateTime(_ updateTime: UpdateTime, for identifier: E.Identifier) {
        updatesMetadataQueue.async(flags: .barrier) {
            self._setUpdateTime(updateTime, for: identifier)
        }
    }

    func setUpdateTime<S>(_ updateTime: UpdateTime, for identifiers: S) where S: Sequence, S.Element == E.Identifier {
        updatesMetadataQueue.async(flags: .barrier) {
            for identifier in identifiers {
                self._setUpdateTime(updateTime, for: identifier)
            }
        }
    }

    private func _setUpdateTime(_ updateTime: UpdateTime, for identifier: E.Identifier) {
        if let savedUpdateTime = self._updatesMetadata[identifier] {
            self._updatesMetadata[identifier] = savedUpdateTime.timestamp > updateTime.timestamp ? savedUpdateTime : updateTime
        } else {
            self._updatesMetadata[identifier] = updateTime
        }
    }
}

// MARK: - PropertyEntry

private extension CoreManager {

    final actor PropertyCache {

        private(set) var properties: [PropertyEntry] = []

        private func removeEntry(_ entry: PropertyEntry) async {
            if let index = properties.firstIndex(where: { $0 === entry }) {
                properties.remove(at: index)
            }
        }

        func preparePropertiesForSearchUpdate(forQuery query: Query<E>, context: ReadContext<E>) async -> CoreManagerProperty<QueryResult<E>> {

            if let property = await properties.first(where: { $0.query == query })?.property {
                return property
            }

            let property = await CoreManagerProperty<QueryResult<E>>()
            let entry = PropertyEntry(query, property: property, contract: context.contract, accessValidator: context.accessValidator)
            properties.append(entry)

            // As soon as the last observer is removed from `property`, the `entry` gets released.
            await property.setDidRemoveLastObserver { [weak self, weak entry] in
                guard let self = self, let entry = entry else { return }
                await self.removeEntry(entry)
            }

            return property
        }
    }

    final actor PropertyEntry {

        let query: Query<E>
        private let contract: EntityContract
        private let accessValidator: UserAccessValidating?

        private(set) var property: CoreManagerProperty<QueryResult<E>>?

        init(_ query: Query<E>,
             property: CoreManagerProperty<QueryResult<E>>,
             contract: EntityContract,
             accessValidator: UserAccessValidating?) {
            self.query = query
            self.property = property
            self.contract = contract
            self.accessValidator = accessValidator
        }

        func update(with queryResult: QueryResult<E>) async {
            await property?.update(with: queryResult.validatingContract(contract, with: query).result.materialized)
        }

        func shouldAllowUpdate() async -> Bool {
            let shouldAllowUpdate = accessValidator?.userAccess.allowsStoreRequest ?? true
            guard shouldAllowUpdate else {
                await property?.update(with: .entities([]))
                return false
            }
            return true
        }
    }
}

// MARK: - CacheStrategy

private extension ReadContext {

    func storeStack<E: Entity>(with stores: [Storing<E>], queues: StoreStackQueues<E>) -> StoreStack<E> {
        var filteredStores: [Storing<E>]
        switch dataSource {
        case ._remote(_, _, orLocal: true, _):
            filteredStores = stores.sorted { $0.level > $1.level }

        case ._remote:
            filteredStores = stores.remote()

        case .local:
            filteredStores = stores.local().sorted { $0.level < $1.level }

        case .localThen,
             .localOr:
            Logger.log(.error, "\(Self.self): \(self) shouldn't be converted to a store stack.", assert: true)
            filteredStores = []
        }

        switch userAccess {
        case .remoteAccess:
            break
        case .localAccess:
            filteredStores = filteredStores.local()
        case .noAccess:
            filteredStores = []
        }

        return StoreStack(stores: filteredStores, queues: queues)
    }
}

private extension WriteContext {

    func storeStack<T: Entity>(with stores: [Storing<T>], queues: StoreStackQueues<T>) -> StoreStack<T> {

        var filteredStores: [Storing<T>]
        switch dataTarget {
        case .remote:
            filteredStores = stores.remote()

        case .localAndRemote:
            filteredStores = stores.sorted { $0.level > $1.level }

        case .local:
            filteredStores = stores.local()
        }

        switch userAccess {
        case .remoteAccess:
            break
        case .localAccess:
            filteredStores = filteredStores.local()
        case .noAccess:
            filteredStores = []
        }

        return StoreStack(stores: filteredStores, queues: queues)
    }
}

private extension Array {

    func local<E: Entity>() -> [Element] where Element == Storing<E> {
        return filter { $0.level.isLocal }
    }

    func remote<E: Entity>() -> [Element] where Element == Storing<E> {
        return filter { $0.level.isRemote }
    }
}

// MARK: - Update Events

private extension CoreManager {

    /// Raises an update for the elected providers.
    ///
    /// - Note:
    ///   - A provider is elected if:
    ///     - Its search query exactly matches with the performed query.
    ///     - Its former search results contains entities which are also contained in the performed search results.
    ///     - Its search query filter is nil.
    ///   - An update event is raised when:
    ///     - At least one entity in the search results changed.
    ///     - The search results has less entities than before.
    ///     - The search results has more entities than before, ONLY when the order IS DETERMINISTIC.
    func raiseUpdateEvents(withQuery query: Query<E>,
                           results: QueryResult<E>,
                           returnsCompleteResultSet: Bool = true) {

        let results = results.materialized

        Task(priority: .high) {
            do {
                try await self.raiseEventsTaskQueue.enqueueBarrier { operationCompletion in
                    defer { operationCompletion() }

                    let properties = await self.propertyCache.properties

                    var _newEntitiesByID: DualHashDictionary<E.Identifier, E>?
                    let lazyNewEntitiesByID = { () -> DualHashDictionary<E.Identifier, E> in
                        if let newEntitiesByID = _newEntitiesByID { return newEntitiesByID }
                        let newEntitiesByID = results.reduce(into: DualHashDictionary<E.Identifier, E>()) { $0[$1.identifier] = $1 }
                        _newEntitiesByID = newEntitiesByID
                        return newEntitiesByID
                    }

                    for element in properties where await element.shouldAllowUpdate() {

                        if element.query != query, let filter = element.query.filter {
                            let newEntitiesUnion = results.lazy.filter(with: filter)
                            let newEntitiesUnionsByID = newEntitiesUnion.reduce(into: DualHashDictionary<E.Identifier, E>()) { $0[$1.identifier] = $1 }

                            var newEntities: AnySequence<E>
                            if let previousPropertyValue = await element.property?.value() {
                                newEntities = previousPropertyValue.update(byReplacingOrAdding: newEntitiesUnionsByID).any
                                if element.query.order.contains(where: { $0.isDeterministic }) {
                                    newEntities = newEntities.order(with: element.query.order).any
                                }
                            } else {
                                newEntities = newEntitiesUnion
                            }

                            let newEntityIDsExclusion = DualHashSet(results.lazy.filter(with: !filter).map { $0.identifier })
                            newEntities = newEntities.lazy.filter { newEntityIDsExclusion.contains($0.identifier) == false }.any

                            let newValue = QueryResult(fromProcessedEntities: newEntities, for: element.query)
                            await element.update(with: newValue)
                        } else if element.query == query || query.filter == .all {
                            if returnsCompleteResultSet == false,
                               let propertyValue = await element.property?.value() {
                                var newEntities = propertyValue.update(byReplacingOrAdding: lazyNewEntitiesByID())
                                if query.order.contains(where: { $0.isDeterministic }) {
                                    newEntities = newEntities.order(with: query.order)
                                }
                                let newValue = QueryResult(fromProcessedEntities: newEntities, for: query)
                                await element.update(with: newValue)
                            } else if element.query.order != query.order, element.query.order.contains(where: { $0.isDeterministic }) {
                                let orderedEntities = results.order(with: element.query.order)
                                let orderedResults = QueryResult(fromProcessedEntities: orderedEntities, for: element.query)
                                await element.update(with: orderedResults)
                            } else {
                                await element.update(with: results)
                            }
                        } else if let propertyValue = await element.property?.value() {
                            var newEntities = element.query.filter == .all ?
                            propertyValue.update(byReplacingOrAdding: lazyNewEntitiesByID()) :
                            propertyValue.update(byReplacing: lazyNewEntitiesByID())

                            if element.query.order.contains(where: { $0.isDeterministic }) {
                                newEntities = newEntities.order(with: element.query.order)
                            }
                            let newValue = QueryResult(fromProcessedEntities: newEntities, for: element.query)
                            await element.update(with: newValue)
                        }
                    }
                }
            } catch {
                Logger.log(.error, "\(CoreManager.self) failed to raise update events for query \(query).", assert: true)
            }
        }
    }

    func raiseDeleteEvents(_ deletedIDs: DualHashSet<E.Identifier>) {
        Task(priority: .high) {
            do {
                try await self.raiseEventsTaskQueue.enqueueBarrier { operationCompletion in
                    defer { operationCompletion() }

                    let properties = await self.propertyCache.properties
                    for element in properties {
                        if let propertyValue = await element.property?.value() {
                            let newEntities = propertyValue.filter { deletedIDs.contains($0.identifier) == false }
                            guard propertyValue.count != newEntities.count else { continue }
                            let newValue = QueryResult(fromProcessedEntities: newEntities, for: element.query)
                            await element.update(with: newValue)
                        }
                    }
                }
            } catch {
                Logger.log(.error, "\(CoreManager.self) failed to raise delete events for ids \(deletedIDs.array).", assert: true)
            }
        }
    }
}

// MARK: - Relationships

public extension CoreManaging {

    final class RelationshipManager: RelationshipCoreManaging {

        public typealias ResultPayload = E.ResultPayload

        public typealias AnyEntity = AnyEntityType

        public typealias GetByIDs = (
            _ identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
            _ entityType: String,
            _ context: _ReadContext<ResultPayload>
        ) -> AnyPublisher<AnySequence<AnyEntity>, ManagerError>

        public typealias GetByIDsAsync = (
            _ identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
            _ entityType: String,
            _ context: _ReadContext<ResultPayload>
        ) async throws -> AnySequence<AnyEntity>

        private let getByIDs: GetByIDs

        private let getByIDsAsync: GetByIDsAsync

        public init<CoreManager>(_ coreManager: CoreManager)
            where CoreManager: RelationshipCoreManaging, CoreManager.AnyEntity == AnyEntity, CoreManager.ResultPayload == ResultPayload {

            getByIDs = { identifiers, entityType, context in
                return coreManager.get(byIDs: identifiers, entityType: entityType, in: context)
            }

            getByIDsAsync = { identifiers, entityType, context in
                return try await coreManager.get(byIDs: identifiers, entityType: entityType, in: context)
            }
        }

        public func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>, entityType: String, in context: _ReadContext<ResultPayload>) -> AnyPublisher<AnySequence<AnyEntity>, ManagerError> {
            return getByIDs(identifiers, entityType, context)
        }

        public func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>, entityType: String, in context: _ReadContext<ResultPayload>) async throws -> AnySequence<AnyEntity> {
            return try await getByIDsAsync(identifiers, entityType, context)
        }
    }

    func rootEntity<Graph>(byID identifier: E.Identifier,
                           in context: ReadContext<E>) async throws -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery<E>
        where Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {

            let once = try await self.get(byID: identifier, in: context)
            let continuous = AsyncStream<QueryResult<E>>() { _ in }

            return RelationshipController.RelationshipQuery(rootEntities: (once: once, continuous: continuous),
                                                            in: context,
                                                            relationshipManager: relationshipManager)
    }

    func rootEntities<S, Graph>(for identifiers: S,
                                in context: ReadContext<E>) async throws -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery<E>
        where S: Sequence, S.Element == E.Identifier, Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {

            return try await RelationshipController.RelationshipQuery(rootEntities: get(byIDs: identifiers, in: context),
                                                                      in: context,
                                                                      relationshipManager: relationshipManager)
    }

    func rootEntities<Graph>(for query: Query<E> = .all,
                             in context: ReadContext<E>) async throws -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery<E>
        where Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {

            return try await RelationshipController.RelationshipQuery(rootEntities: search(withQuery: query, in: context),
                                                                      in: context,
                                                                      relationshipManager: relationshipManager)
    }
}

public extension CoreManaging where E: RemoteEntity {

    func rootEntity<Graph>(byID identifier: E.Identifier,
                           in context: ReadContext<E>) async throws -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery<E>
        where Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {

            let once = try await self.get(byID: identifier, in: context)
            let continuous = AsyncStream<QueryResult<E>>() { _ in }

            return RelationshipController.RelationshipQuery(rootEntities: (once: once, continuous: continuous),
                                                            in: context,
                                                            relationshipManager: relationshipManager)
    }

    func rootEntities<S, Graph>(for identifiers: S,
                                in context: ReadContext<E>) async throws -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery<E>
        where S: Sequence, S.Element == E.Identifier, Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {

            return try await RelationshipController.RelationshipQuery(rootEntities: get(byIDs: identifiers, in: context),
                                                                      in: context,
                                                                      relationshipManager: relationshipManager)
    }
}

public extension CoreManaging where E.Identifier == VoidEntityIdentifier {

    func rootEntity<Graph>(in context: ReadContext<E>) async throws -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery<E>
        where Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {

            return try await rootEntity(byID: VoidEntityIdentifier(), in: context)
    }
}
