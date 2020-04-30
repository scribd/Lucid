//
//  CoreManager.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/21/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import ReactiveKit

// MARK: - Error

public enum ManagerError: Error, Equatable {
    case store(StoreError)
    case conflict // Write operation was conflicting with another write operation.
    case notSupported // Operation is not supported.
    case logicalError(description: String?) // CoreManager encountered a logical conflict, e.g. missing or broken data where no error was raised.
    case userAccessInvalid // Operation requires correct user permission.
}

extension Array: Error where Element: Error { }

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

    typealias GetEntity = (
        _ identifier: E.Identifier,
        _ context: ReadContext<E>
    ) -> Signal<QueryResult<E>, ManagerError>

    typealias SearchEntities = (
        _ query: Query<E>,
        _ context: ReadContext<E>
    ) -> (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>)

    typealias SetEntity = (
        _ entity: E,
        _ context: WriteContext<E>
    ) -> Signal<E, ManagerError>
    
    typealias SetEntities = (
        _ entities: AnySequence<E>,
        _ context: WriteContext<E>
    ) -> Signal<AnySequence<E>, ManagerError>

    typealias RemoveAllEntities = (
        _ query: Query<E>,
        _ context: WriteContext<E>
    ) -> Signal<AnySequence<E.Identifier>, ManagerError>

    typealias RemoveEntity = (
        _ identifier: E.Identifier,
        _ context: WriteContext<E>
    ) -> Signal<Void, ManagerError>

    typealias RemoveEntities = (
        _ identifiers: AnySequence<E.Identifier>,
        _ context: WriteContext<E>
    ) -> Signal<Void, ManagerError>

    // MARK: - Methods
    
    private let getEntity: GetEntity
    private let searchEntities: SearchEntities
    private let setEntity: SetEntity
    private let setEntities: SetEntities
    private let removeAllEntities: RemoveAllEntities
    private let removeEntity: RemoveEntity
    private let removeEntities: RemoveEntities
    private weak var relationshipManager: RelationshipManager?

    init(getEntity: @escaping GetEntity,
         searchEntities: @escaping SearchEntities,
         setEntity: @escaping SetEntity,
         setEntities: @escaping SetEntities,
         removeAllEntities: @escaping RemoveAllEntities,
         removeEntity: @escaping RemoveEntity,
         removeEntities: @escaping RemoveEntities,
         relationshipManager: RelationshipManager?) {

        self.getEntity = getEntity
        self.searchEntities = searchEntities
        self.setEntity = setEntity
        self.setEntities = setEntities
        self.removeAllEntities = removeAllEntities
        self.removeEntity = removeEntity
        self.removeEntities = removeEntities
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
                    in context: ReadContext<E> = ReadContext<E>()) -> Signal<QueryResult<E>, ManagerError> {
        return getEntity(identifier, context)
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
                       in context: ReadContext<E> = ReadContext<E>()) -> (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>) {
        return searchEntities(query, context)
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
                    in context: WriteContext<E>) -> Signal<E, ManagerError> {
        return setEntity(entity, context)
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
                       in context: WriteContext<E>) -> Signal<AnySequence<E>, ManagerError> where S: Sequence, S.Element == E {
        return setEntities(entities.any, context)
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
                          in context: WriteContext<E>) -> Signal<AnySequence<E.Identifier>, ManagerError> {
        return removeAllEntities(query, context)
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
                       in context: WriteContext<E>) -> Signal<Void, ManagerError> {
        return removeEntity(identifier, context)
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
                          in context: WriteContext<E>) -> Signal<Void, ManagerError> where S: Sequence, S.Element == E.Identifier {
        return removeEntities(identifiers.any, context)
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
    func all(in context: ReadContext<E>) -> Signal<QueryResult<E>, ManagerError> {
        return search(withQuery: .all, in: context).once
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
               in context: ReadContext<E> = ReadContext<E>()) -> Signal<E?, ManagerError> {
        
        return search(withQuery: query, in: context).once.map { $0.first }
    }
    
    /// Retrieve entities that match one of the given identifiers.
    ///
    /// - Parameters:
    ///     - identifiers: List of identifiers used to build a OR query.
    ///     - context: Context associated to the query.
    ///
    /// - Returns:
    ///     - Two Signals, `once` and `continuous`.
    ///     - `once` will return a single response of either `QueryResult<Entity>` or `ManagerError`.
    ///     - `continuous` will return a response of either `[Entity]` or `ManagerError` every time changes occur that
    ///        match the query. It will never be completed and will be retained until you release the dispose bag.
    func get<S>(byIDs identifiers: S,
                in context: ReadContext<E>) -> (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>)
        where S: Sequence, S.Element == E.Identifier {

            let query = Query<E>.filter(.identifier >> identifiers).order([.identifiers(identifiers.any)])

            return search(withQuery: query, in: context)
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
                           in context: ReadContext<E>) -> Signal<QueryResult<E>, ManagerError> {

        let signals = search(withQuery: query ?? .all, in: context)
        return signals.once.map { result -> QueryResult<E> in
            guard let entity = result.entity, let metadata = result.metadata else { return .empty() }
            return QueryResult<E>(from: entity, metadata: metadata)
        }
    }
    
    /// Retrieve entities that match one of the given identifiers.
    ///
    /// - Parameters:
    ///     - identifiers: List of identifiers used to build a OR query.
    ///     - context: Context associated to the query.
    ///
    /// - Returns:
    ///     - Two Signals, `once` and `continuous`.
    ///     - `once` will return a single response of either `QueryResult<Entity>` or `ManagerError`.
    ///     - `continuous` will return a response of either `[Entity]` or `ManagerError` every time changes occur that
    ///        match the query. It will never be completed and will be retained until you release the dispose bag.
    func get<S>(byIDs identifiers: S,
                in context: ReadContext<E>) -> (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>)
        where S: Sequence, S.Element == E.Identifier {
            
            let query = Query<E>.filter(.identifier >> identifiers).order([.identifiers(identifiers.any)])
            
            return search(withQuery: query, in: context)
    }
}

public extension CoreManaging where E.Identifier == VoidEntityIdentifier {
    
    func get(in context: ReadContext<E> = ReadContext<E>()) -> Signal<QueryResult<E>, ManagerError> {
        return getEntity(VoidEntityIdentifier(), context)
    }
}

// MARK: - CoreManager

public final class CoreManager<E> where E: Entity {
    
    // MARK: - Dependencies
    
    private let stores: [Storing<E>]
    private let storeStackQueues = StoreStackQueues<E>()
    private let operationQueue = AsyncOperationQueue()
    
    private let localStore: StoreStack<E>
    
    private let propertiesQueue = DispatchQueue(label: "\(CoreManager.self):properties", attributes: .concurrent)
    private let raiseEventsQueue = DispatchQueue(label: "\(CoreManager.self):raise_events")
    private var _pendingProperties = [PropertyEntry]()
    private var _properties = [PropertyEntry]()
    
    private let updatesMetadataQueue = DispatchQueue(label: "\(CoreManager.self):updates_metadata", attributes: .concurrent)
    private var _updatesMetadata = DualHashDictionary<E.Identifier, UpdateTime>()

    // MARK: - Inits
    
    public init(stores: [Storing<E>]) {
        self.stores = stores
        localStore = StoreStack(stores: stores.local(), queues: storeStackQueues)
    }

    public func managing<AnyEntityType>(_ relationshipManager: CoreManaging<E, AnyEntityType>.RelationshipManager? = nil) -> CoreManaging<E, AnyEntityType> where AnyEntityType: EntityConvertible {
        return CoreManaging(getEntity: { self.get(byID: $0, in: $1) },
                            searchEntities: { self.search(withQuery: $0, in: $1) },
                            setEntity: { self.set($0, in: $1) },
                            setEntities: { self.set($0, in: $1) },
                            removeAllEntities: { self.removeAll(withQuery: $0, in: $1) },
                            removeEntity: { self.remove(atID: $0, in: $1)},
                            removeEntities: { self.remove($0, in: $1) },
                            relationshipManager: relationshipManager)
    }
}

public extension CoreManager {

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
    func get(byID identifier: E.Identifier,
             in context: ReadContext<E>) -> Signal<QueryResult<E>, ManagerError> {
        
        if let remoteContext = context.remoteContextAfterMakingLocalRequest {
            let localContext = ReadContext<E>(dataSource: .local, accessValidator: context.accessValidator)
            return get(byID: identifier, in: localContext)
                .flatMapError { _ -> Signal<QueryResult<E>, ManagerError> in
                    return Signal(just: .empty())
                }
                .flatMapLatest { result -> Signal<QueryResult<E>, ManagerError> in
                    if result.entity != nil {
                        if context.shouldFetchFromRemoteWhileFetchingFromLocalStore {
                            self.get(byID: identifier, in: remoteContext).discardResult()
                        }
                        return Signal(just: result)
                    } else {
                        return self.get(byID: identifier, in: remoteContext)
                    }
                }

        } else {
            
            return FutureSubject { promise in

                guard context.requestAllowedForAccessLevel else {
                    promise(.failure(.userAccessInvalid))
                    return
                }

                let initialUserAccess = context.userAccess
                let guardedPromise: (Result<QueryResult<E>, ManagerError>) -> Void = { result in
                    guard context.responseAllowedForAccessLevel,
                        initialUserAccess == context.userAccess else {
                        promise(.failure(.userAccessInvalid))
                        return
                    }
                    promise(result)
                }

                self.operationQueue.run(title: "\(CoreManager.self):get_by_id") { operationCompletion in
                    defer { operationCompletion() }

                    let time = UpdateTime()
                    let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)

                    storeStack.get(byID: identifier, in: context) { result in

                        switch result {
                        case .success(let queryResult):
                            if context.shouldOverwriteInLocalStores {
                                guard self.canUpdate(identifier: identifier, basedOn: time) else {
                                    guardedPromise(.success(queryResult))
                                    return
                                }
                                self.setUpdateTime(time, for: identifier)
                                
                                if let entity = queryResult.entity {
                                    self.localStore.set(entity, in: WriteContext(dataTarget: .local)) { result in
                                        switch result {
                                        case .failure(let error):
                                            Logger.log(.error, "\(CoreManager.self): An error occurred while writing entity to local stores: \(error)", assert: true)
                                        case .success,
                                             .none:
                                            break
                                        }
                                        guardedPromise(.success(queryResult))
                                        self.raiseUpdateEvents(withQuery: .identifier(identifier), results: .entities([entity]), returnsCompleteResultSet: context.returnsCompleteResultSet)
                                    }
                                } else {
                                    self.localStore.remove(atID: identifier, in: WriteContext(dataTarget: .local)) { result in
                                        switch result {
                                        case .failure(let error):
                                            Logger.log(.error, "\(CoreManager.self): An error occurred while deleting entity from local stores: \(error)", assert: true)
                                        case .success,
                                             .none:
                                            break
                                        }
                                        guardedPromise(.success(.empty()))
                                        self.raiseDeleteEvents(DualHashSet([identifier]))
                                    }
                                }
                            } else {
                                guardedPromise(.success(queryResult))
                            }
                            
                        case .failure(let error):
                            Logger.log(.error, "\(CoreManager.self): An error occurred while getting entity from local stores: \(error)")
                            guardedPromise(.failure(.store(error)))
                        }
                    }
                }
            }.toSignal()
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
                in context: ReadContext<E>) -> (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>) {

        if let remoteContext = context.remoteContextAfterMakingLocalRequest {
            let localContext = ReadContext<E>(dataSource: .local, accessValidator: context.accessValidator)
            let cacheSearches = search(withQuery: query, in: localContext)

            let dispatchQueue = DispatchQueue(label: "\(CoreManager.self)_search_prefer_cache_synchronization_queue")
            var overwriteSignal: Signal<QueryResult<E>, ManagerError>?

            let overwriteSearch: () -> Signal<QueryResult<E>, ManagerError> = {
                return dispatchQueue.sync {
                    if let overwriteSignal = overwriteSignal {
                        return overwriteSignal
                    }
                    let signal = self.search(withQuery: query, in: remoteContext).once
                    overwriteSignal = signal
                    return signal
                }
            }

            if context.shouldFetchFromRemoteWhileFetchingFromLocalStore {
                operationQueue.run(title: "\(CoreManager.self):search:1") { operationCompletion in
                    defer { operationCompletion() }
                    overwriteSearch().discardResult()
                }
            }

            return (
                once: cacheSearches.once
                    .flatMapError { _ -> Signal<QueryResult<E>, ManagerError> in
                        return Signal(just: QueryResult<E>(fromOrderedEntities: [], for: query))
                    }
                    .flatMapLatest { element -> Signal<QueryResult<E>, ManagerError> in
                        let searchIdentifierCount = query.filter?.extractOrIdentifiers?.map { $0 }.count ?? 0
                        let entityResultCount = element.count

                        let hasAllIdentifiersLocally = searchIdentifierCount > 0 && entityResultCount == searchIdentifierCount
                        let hasResultsForComplexSearch = searchIdentifierCount == 0 && entityResultCount > 0

                        if hasAllIdentifiersLocally || hasResultsForComplexSearch {
                            return Signal(just: element)
                        } else {
                            return overwriteSearch()
                        }
                },
                continuous: cacheSearches.continuous)
        }

        let property = preparePropertiesForSearchUpdate(forQuery: query, accessValidator: context.accessValidator)

        let future = FutureSubject<QueryResult<E>, ManagerError> { promise in

            guard context.requestAllowedForAccessLevel else {
                promise(.failure(.userAccessInvalid))
                return
            }

            let initialUserAccess = context.userAccess
            let guardedPromise: (Result<QueryResult<E>, ManagerError>) -> Void = { result in
                guard context.responseAllowedForAccessLevel,
                    initialUserAccess == context.userAccess else {
                    promise(.failure(.userAccessInvalid))
                    return
                }
                promise(result)
            }

            self.operationQueue.run(title: "\(CoreManager.self):search:2") { operationCompletion in
                defer { operationCompletion() }

                let time = UpdateTime()
                let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)

                storeStack.search(withQuery: query, in: context) { result in

                    switch result {
                    case .success(let results):
                        if context.shouldOverwriteInLocalStores {
                            self.localStore.search(withQuery: query, in: context) { localResult in

                                switch localResult {
                                case .success(let localResults):
                                    let remoteResults = results.materialized

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
                                        guardedPromise(.success(remoteResults))
                                        return
                                    }
                                    self.setUpdateTime(time, for: entitiesToUpdate.map { $0.identifier } + identifiersToDelete)

                                    let dispatchGroup = DispatchGroup()

                                    if entitiesToUpdate.isEmpty == false {
                                        dispatchGroup.enter()
                                        self.localStore.set(entitiesToUpdate, in: WriteContext(dataTarget: .local)) { result in
                                            if let error = result?.error {
                                                Logger.log(.error, "\(CoreManager.self): An error occurred while writing entities to local stores: \(error)", assert: true)
                                            }
                                            dispatchGroup.leave()
                                        }
                                    }

                                    if identifiersToDelete.isEmpty == false {
                                        dispatchGroup.enter()
                                        self.localStore.remove(identifiersToDelete, in: WriteContext(dataTarget: .local)) { result in
                                            if let error = result?.error {
                                                Logger.log(.error, "\(CoreManager.self): An error occurred while deleting entities to local stores: \(error)", assert: true)
                                            }
                                            dispatchGroup.leave()
                                        }
                                    }

                                    dispatchGroup.notify(queue: self.storeStackQueues.writeResultsQueue) {
                                        guardedPromise(.success(remoteResults))
                                        self.raiseUpdateEvents(withQuery: query, results: remoteResults, returnsCompleteResultSet: context.returnsCompleteResultSet)
                                    }

                                case .failure(let error):
                                    Logger.log(.error, "\(CoreManager.self): An error occurred while searching entities from local stores: \(error)", assert: true)

                                    let entitiesToUpdate = self.filter(entities: results, basedOn: time).compactMap { $0 }
                                    guard entitiesToUpdate.isEmpty == false else {
                                        guardedPromise(.success(results))
                                        return
                                    }
                                    self.setUpdateTime(time, for: entitiesToUpdate.lazy.map { $0.identifier })

                                    self.localStore.set(entitiesToUpdate, in: WriteContext(dataTarget: .local)) { result in
                                        if let error = result?.error {
                                            Logger.log(.error, "\(CoreManager.self): An error occurred while writing entities to local stores: \(error)", assert: true)
                                        }
                                        guardedPromise(.success(results))
                                        self.raiseUpdateEvents(withQuery: query, results: results, returnsCompleteResultSet: context.returnsCompleteResultSet)
                                    }
                                }
                            }
                        } else {
                            guardedPromise(.success(results))
                            property.update(with: results)
                        }

                    case .failure(let error):
                        Logger.log(.error, "\(CoreManager.self): An error occurred while searching entities from local stores: \(error)", assert: error.isNetworkConnectionFailure == false)
                        guardedPromise(.failure(.store(error)))
                    }
                }
            }
        }

        return (
            once: future.toSignal(),
            continuous: property.compactMap { $0 }
        )
    }

    func set(_ entity: E,
             in context: WriteContext<E>) -> Signal<E, ManagerError> {
        
        return FutureSubject { promise in

            guard context.requestAllowedForAccessLevel else {
                promise(.failure(.userAccessInvalid))
                return
            }

            let initialUserAccess = context.userAccess
            let guardedPromise: (Result<E, ManagerError>) -> Void = { result in
                guard context.responseAllowedForAccessLevel,
                    initialUserAccess == context.userAccess else {
                    promise(.failure(.userAccessInvalid))
                    return
                }
                promise(result)
            }

            self.operationQueue.run(title: "\(CoreManager.self):set") { operationCompletion in
                defer { operationCompletion() }
                
                let time = UpdateTime(timestamp: context.originTimestamp)
                guard self.canUpdate(identifier: entity.identifier, basedOn: time) else {
                    self.localStore.get(byID: entity.identifier, in: ReadContext<E>()) { result in
                        switch result {
                        case .success(let queryResult):
                            if let entity = queryResult.entity {
                                guardedPromise(.success(entity))
                            } else {
                                guardedPromise(.failure(.conflict))
                            }
                        case .failure(let error):
                            Logger.log(.error, "\(CoreManager.self): An error occurred while setting entity to local stores: \(error)")
                            guardedPromise(.failure(.store(error)))
                        }
                    }
                    return
                }
                self.setUpdateTime(time, for: entity.identifier)
                
                let raiseUpdateEventsBox = ProcessOnceEntityBox<E> { updatedEntity in
                    guard let updatedEntity = updatedEntity.first else { return }
                    self.raiseUpdateEvents(withQuery: .identifier(updatedEntity.identifier), results: .entities([updatedEntity]))
                }
                let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)

                storeStack.set(
                    entity,
                    in: context,
                    localStoresCompletion: { result in
                        guard let updatedEntity = result?.value else { return }
                        raiseUpdateEventsBox.process([updatedEntity])
                    },
                    allStoresCompletion: { result in
                        switch result {
                        case .success(let updatedEntity):
                            guardedPromise(.success(updatedEntity))
                            raiseUpdateEventsBox.process([updatedEntity])

                        case .none:
                            guardedPromise(.success(entity))
                            raiseUpdateEventsBox.process([entity])

                        case .failure(let error):
                            Logger.log(.error, "\(CoreManager.self): An error occurred while setting entity to all stores: \(error)")
                            guardedPromise(.failure(.store(error)))
                        }
                    }
                )
            }
        }.toSignal()
    }
    
    func set<S>(_ entities: S,
                in context: WriteContext<E>) -> Signal<AnySequence<E>, ManagerError> where S: Sequence, S.Element == E {

        let entities = Array(entities)
        
        return FutureSubject { promise in

            guard context.requestAllowedForAccessLevel else {
                promise(.failure(.userAccessInvalid))
                return
            }

            let initialUserAccess = context.userAccess
            let guardedPromise: (Result<AnySequence<E>, ManagerError>) -> Void = { result in
                guard context.responseAllowedForAccessLevel,
                    initialUserAccess == context.userAccess else {
                    promise(.failure(.userAccessInvalid))
                    return
                }
                promise(result)
            }

            self.operationQueue.run(title: "\(CoreManager.self):bulk_set") { operationCompletion in
                defer { operationCompletion() }
                
                let time = UpdateTime(timestamp: context.originTimestamp)
                var entitiesToUpdate = OrderedDualHashDictionary(
                    self.updateTime(for: entities
                        .lazy.map { $0.identifier })
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
                    guardedPromise(.success(.empty))
                    return
                }
                
                self.setUpdateTime(time, for: entitiesToUpdate.lazy.compactMap { $0.1?.identifier })
                
                let raiseUpdateEventsBox = ProcessOnceEntityBox<E> { updatedEntities in
                    self.raiseUpdateEvents(withQuery: .filter(.identifier >> updatedEntities.lazy.map { $0.identifier }),
                                           results: .entities(updatedEntities))
                }
                let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)
                storeStack.set(
                    entitiesToUpdate.lazy.compactMap { $0.1 },
                    in: context,
                    localStoresCompletion: { result in
                        guard let updatedEntities = result?.value else { return }
                        raiseUpdateEventsBox.process(updatedEntities)
                    },
                    allStoresCompletion: { result in
                        switch result {
                        case .success(let updatedEntities):
                            for entity in updatedEntities {
                                entitiesToUpdate[entity.identifier] = entity
                            }
                            for entity in entities where entitiesToUpdate[entity.identifier] == nil {
                                entitiesToUpdate[entity.identifier] = entity
                            }
                            guardedPromise(.success(entitiesToUpdate.lazy.compactMap { $0.1 }.any))
                            raiseUpdateEventsBox.process(updatedEntities)
                        
                        case .none:
                            guardedPromise(.success(entities.any))
                            raiseUpdateEventsBox.process(entities)

                        case .failure(let error):
                            Logger.log(.error, "\(CoreManager.self): An error occurred while setting entities to all stores: \(error)")
                            guardedPromise(.failure(.store(error)))
                        }
                    }
                )
            }
        }.toSignal()
    }
    
    func removeAll(withQuery query: Query<E>,
                   in context: WriteContext<E>) -> Signal<AnySequence<E.Identifier>, ManagerError> {

        return FutureSubject { promise in

            guard context.requestAllowedForAccessLevel else {
                promise(.failure(.userAccessInvalid))
                return
            }

            let initialUserAccess = context.userAccess
            let guardedPromise: (Result<AnySequence<E.Identifier>, ManagerError>) -> Void = { result in
                guard context.responseAllowedForAccessLevel,
                    initialUserAccess == context.userAccess else {
                    promise(.failure(.userAccessInvalid))
                    return
                }
                promise(result)
            }

            self.operationQueue.run(title: "\(CoreManager.self):remove_all") { operationCompletion in

                let time = UpdateTime(timestamp: context.originTimestamp)
                self.localStore.search(withQuery: query, in: ReadContext<E>()) { result in
                    defer { operationCompletion() }

                    switch result {
                    case .success(var results):
                        results.materialize()

                        let entitiesToRemove = self.filter(entities: results.any, basedOn: time).compactMap { $0 }
                        guard entitiesToRemove.isEmpty == false else {
                            guardedPromise(.success(.empty))
                            return
                        }
                        let identifiersToRemove = entitiesToRemove.lazy.map { $0.identifier }
                        self.setUpdateTime(time, for: identifiersToRemove)
                        
                        let raiseDeleteEventsBox = ProcessOnceIdentifierBox<E.Identifier> { removedIdentifiers in
                            self.raiseDeleteEvents(DualHashSet(removedIdentifiers))
                        }
                        let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)
                        if entitiesToRemove.count == results.count {
                            storeStack.removeAll(
                                withQuery: query,
                                in: context,
                                localStoresCompletion: { result in
                                    guard let removedIdentifiers = result?.value else { return }
                                    raiseDeleteEventsBox.process(removedIdentifiers)
                                },
                                allStoresCompletion: { result in
                                    switch result {
                                    case .success(let removedIdentifiers):
                                        guardedPromise(.success(removedIdentifiers))
                                        raiseDeleteEventsBox.process(removedIdentifiers)
                                        
                                    case .none:
                                        let removedIdentifiers = entitiesToRemove.map { $0.identifier }.any
                                        guardedPromise(.success(removedIdentifiers))
                                        raiseDeleteEventsBox.process(removedIdentifiers)

                                    case .failure(let error):
                                        Logger.log(.error, "\(CoreManager.self): An error occurred while removing all entities in query from all stores: \(error)")
                                        guardedPromise(.failure(.store(error)))
                                    }
                                }
                            )
                        } else {
                            storeStack.remove(
                                identifiersToRemove,
                                in: context,
                                localStoresCompletion: { result in
                                    guard result?.error == nil else { return }
                                    raiseDeleteEventsBox.process(identifiersToRemove)
                            },
                                allStoresCompletion: { result in
                                    switch result {
                                    case .success, .none:
                                        guardedPromise(.success(identifiersToRemove.any))
                                        raiseDeleteEventsBox.process(identifiersToRemove)
                                        
                                    case .failure(let error):
                                        Logger.log(.error, "\(CoreManager.self): An error occurred while removing entities for identifiers from all stores: \(error)")
                                        guardedPromise(.failure(.store(error)))
                                    }
                            }
                            )
                        }
                        
                    case .failure(let error):
                        Logger.log(.error, "\(CoreManager.self): An error occurred while searching for entities to remove all: \(error)")
                        guardedPromise(.failure(.store(error)))
                    }
                }
            }
        }.toSignal()
    }
    
    func remove(atID identifier: E.Identifier,
                in context: WriteContext<E>) -> Signal<Void, ManagerError> {
        
        return FutureSubject { promise in

            guard context.requestAllowedForAccessLevel else {
                promise(.failure(.userAccessInvalid))
                return
            }

            let initialUserAccess = context.userAccess
            let guardedPromise: (Result<Void, ManagerError>) -> Void = { result in
                guard context.responseAllowedForAccessLevel,
                    initialUserAccess == context.userAccess else {
                    promise(.failure(.userAccessInvalid))
                    return
                }
                promise(result)
            }

            self.operationQueue.run(title: "\(CoreManager.self):remove") { operationCompletion in
                defer { operationCompletion() }

                let time = UpdateTime(timestamp: context.originTimestamp)
                guard self.canUpdate(identifier: identifier, basedOn: time) else {
                    guardedPromise(.success(()))
                    return
                }
                self.setUpdateTime(time, for: identifier)
                
                let raiseDeleteEventsBox = ProcessOnceIdentifierBox<E.Identifier> { removedIdentifiers in
                    guard let removedIdentifier = removedIdentifiers.first else { return }
                    self.raiseDeleteEvents(DualHashSet([removedIdentifier]))
                }
                let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)
                storeStack.remove(
                    atID: identifier,
                    in: context,
                    localStoresCompletion: { result in
                        guard result?.error == nil else { return }
                        raiseDeleteEventsBox.process([identifier])
                    },
                    allStoresCompletion: { result in
                        switch result {
                        case .success,
                             .none:
                            guardedPromise(.success(()))
                            raiseDeleteEventsBox.process([identifier])
                            
                        case .failure(let error):
                            Logger.log(.error, "\(CoreManager.self): An error occurred while removing entity from all stores: \(error)")
                            guardedPromise(.failure(.store(error)))
                        }
                    }
                )
            }
        }.toSignal()
    }
    
    func remove<S>(_ identifiers: S,
                   in context: WriteContext<E>) -> Signal<Void, ManagerError> where S: Sequence, S.Element == E.Identifier {
        
        return FutureSubject { promise in

            guard context.requestAllowedForAccessLevel else {
                promise(.failure(.userAccessInvalid))
                return
            }

            let initialUserAccess = context.userAccess
            let guardedPromise: (Result<Void, ManagerError>) -> Void = { result in
                guard context.responseAllowedForAccessLevel,
                    initialUserAccess == context.userAccess else {
                    promise(.failure(.userAccessInvalid))
                    return
                }
                promise(result)
            }

            self.operationQueue.run(title: "\(CoreManager.self):bulk_remove") { operationCompletion in
                defer { operationCompletion() }

                let time = UpdateTime(timestamp: context.originTimestamp)
                let identifiersToRemove = self.filter(identifiers: identifiers, basedOn: time).lazy.compactMap { $0 }
                guard identifiersToRemove.isEmpty == false else {
                    guardedPromise(.success(()))
                    return
                }
                self.setUpdateTime(time, for: identifiersToRemove)
                
                let raiseDeleteEventsBox = ProcessOnceIdentifierBox<E.Identifier> { removedIdentifiers in
                    self.raiseDeleteEvents(DualHashSet(removedIdentifiers))
                }
                let storeStack = context.storeStack(with: self.stores, queues: self.storeStackQueues)
                storeStack.remove(
                    identifiersToRemove,
                    in: context,
                    localStoresCompletion: { result in
                        guard result?.error == nil else { return }
                        raiseDeleteEventsBox.process(identifiersToRemove)
                    },
                    allStoresCompletion: { result in
                        switch result {
                        case .success,
                             .none:
                            guardedPromise(.success(()))
                            raiseDeleteEventsBox.process(identifiersToRemove)
                            
                        case .failure(let error):
                            Logger.log(.error, "\(CoreManager.self): An error occurred while removing entities from all stores: \(error)")
                            guardedPromise(.failure(.store(error)))
                        }
                    }
                )
            }
        }.toSignal()
    }
}

// MARK: - MutableEntity Actions

extension CoreManaging where E: MutableEntity {

    public func setAndUpdateIdentifierInLocalStores(_ entity: E, originTimestamp: UInt64) -> SafeSignal<Void> {
        let context = WriteContext<E>(dataTarget: .local, remoteSyncState: .createResponse(originTimestamp))
        return set(entity, in: context)
            .flatMapLatest { storedResult -> Signal<Void, ManagerError> in
                storedResult.merge(identifier: entity.identifier)
                let context = WriteContext<E>(dataTarget: .local, remoteSyncState: .mergeIdentifier)
                return self.set(storedResult, in: context).map { _ in }
            }
            .replaceError(with: ())
    }

    public func removeFromLocalStores(_ identifier: E.Identifier, originTimestamp: UInt64) -> SafeSignal<Void> {
        let context = WriteContext<E>(dataTarget: .local, remoteSyncState: .createResponse(originTimestamp))
        return remove(atID: identifier, in: context)
            .map { _ in }
            .replaceError(with: ())
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
    
    final class PropertyEntry {
        
        let query: Query<E>
        let accessValidator: UserAccessValidating?

        private let propertyDispatchQueue = DispatchQueue(label: "\(PropertyEntry.self):property")
        private var _strongProperty: Property<QueryResult<E>?>?
        private weak var _weakProperty: Property<QueryResult<E>?>?
        
        var property: Property<QueryResult<E>?>? {
            return propertyDispatchQueue.sync { _weakProperty ?? _strongProperty }
        }
        
        init(_ query: Query<E>,
             property: Property<QueryResult<E>?>,
             accessValidator: UserAccessValidating?) {
            self.query = query
            self._weakProperty = property
            self.accessValidator = accessValidator
        }

        func strengthen() {
            let property = self.property // makes sure to retain before dispatching.
            propertyDispatchQueue.async {
                self._strongProperty = property
            }
        }
        
        func update(with value: QueryResult<E>) {
            let shouldAllowRequest = accessValidator?.userAccess.allowsStoreRequest ?? true
            if shouldAllowRequest {
                property?.update(with: value)
            } else {
                property?.update(with: .entities([]))
            }
        }
        
        func materialize() {
            guard let value = self.property?.value?.materialized else { return }
            property?.silentUpdate(value: value)
        }
    }

    func preparePropertiesForSearchUpdate(forQuery query: Query<E>, accessValidator: UserAccessValidating?) -> Property<QueryResult<E>?> {

        if let property = propertiesQueue.sync(execute: { (_properties + _pendingProperties).first { $0.query == query }?.property }) {
            return property
        }

        let subject = CoreManagerSubject<QueryResult<E>?, Never>()
        let property = Property<QueryResult<E>?>(nil, subject: subject)

        let entry = PropertyEntry(query, property: property, accessValidator: accessValidator)
        propertiesQueue.async(flags: .barrier) {
            self._pendingProperties.removeAll { $0.property == nil }
            self._pendingProperties.append(entry)
        }
        
        // Because `willAddFirstObserver` is called synchronously when `property` gets observed,
        // `entry` can't get released before being retained by `strengthen`.
        // If nothing observes, it gets released immediately.
        subject.willAddFirstObserver = { [weak self] in
            guard let strongSelf = self else { return }
            entry.strengthen()
            strongSelf.propertiesQueue.async(flags: .barrier) {
                if let index = strongSelf._pendingProperties.firstIndex(where: { $0 === entry }) {
                    strongSelf._pendingProperties.remove(at: index)
                }
                strongSelf._properties.append(entry)
            }
        }

        // As soon as the last observer is removed from `subject`, the `entry` gets released.
        subject.willRemoveLastObserver = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.propertiesQueue.async(flags: .barrier) {
                if let index = strongSelf._properties.firstIndex(where: { $0 === entry }) {
                    strongSelf._properties.remove(at: index)
                }
            }
        }
        
        return property
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
    
    func storeStack<E: Entity>(with stores: [Storing<E>], queues: StoreStackQueues<E>) -> StoreStack<E> {
        var filteredStores: [Storing<E>]
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
    func raiseUpdateEvents(withQuery query: Query<E>, results: QueryResult<E>, returnsCompleteResultSet: Bool = true) {
        raiseEventsQueue.async {
            let properties = self.propertiesQueue.sync { self._properties + self._pendingProperties }
            for element in properties {
                if element.query != query, let filter = element.query.filter {
                    let newEntitiesUnion = results.lazy.filter(with: filter)
                    let newEntitiesUnionsByID = newEntitiesUnion.reduce(into: DualHashDictionary<E.Identifier, E>()) { $0[$1.identifier] = $1 }
                    
                    var newEntities: AnySequence<E>
                    if let previousPropertyValue = element.property?.value {
                        newEntities = previousPropertyValue.update(byReplacingOrAdding: newEntitiesUnionsByID).any
                        if element.query.order.contains(where: { $0.isDeterministic }) {
                            newEntities = newEntities.order(with: element.query.order).any
                        }
                    } else {
                        newEntities = newEntitiesUnion
                    }
                    
                    let newEntityIDsExclusion = results.lazy.filter(with: !filter).map { $0.identifier }
                    newEntities = newEntities.lazy.filter(with: !(.identifier >> newEntityIDsExclusion))
                    
                    let newValue = QueryResult(fromOrderedEntities: newEntities, for: element.query)
                    element.update(with: newValue)
                } else if element.query == query || query.filter == .all {
                    if returnsCompleteResultSet == false,
                        let propertyValue = element.property?.value {
                        let newEntitiesByID = results.reduce(into: DualHashDictionary<E.Identifier, E>()) { $0[$1.identifier] = $1 }
                        var newEntities = propertyValue.update(byReplacingOrAdding: newEntitiesByID)
                        if query.order.contains(where: { $0.isDeterministic }) {
                            newEntities = newEntities.order(with: query.order)
                        }
                        let newValue = QueryResult(fromOrderedEntities: newEntities, for: query)
                        element.update(with: newValue)
                    } else if element.query.order != query.order,
                        element.query.order.contains(where: { $0.isDeterministic }) {
                        let orderedEntities = results.order(with: element.query.order)
                        let orderedResults = QueryResult(fromOrderedEntities: orderedEntities, for: element.query)
                        element.update(with: orderedResults)
                    } else {
                        element.update(with: results)
                    }
                } else if let propertyValue = element.property?.value {
                    let newEntitiesByID = results.reduce(into: DualHashDictionary<E.Identifier, E>()) { $0[$1.identifier] = $1 }
                    var newEntities = element.query.filter == .all ?
                        propertyValue.update(byReplacingOrAdding: newEntitiesByID) :
                        propertyValue.update(byReplacing: newEntitiesByID)
                    
                    if element.query.order.contains(where: { $0.isDeterministic }) {
                        newEntities = newEntities.order(with: element.query.order)
                    }
                    let newValue = QueryResult(fromOrderedEntities: newEntities, for: element.query)
                    element.update(with: newValue)
                }
            }
        }
    }
    
    func raiseDeleteEvents(_ deletedIDs: DualHashSet<E.Identifier>) {
        raiseEventsQueue.async {
            let properties = self.propertiesQueue.sync { self._properties + self._pendingProperties }
            for element in properties {
                element.materialize()
                if let propertyValue = element.property?.value {
                    let newEntities = propertyValue.filter { deletedIDs.contains($0.identifier) == false }
                    guard propertyValue.count != newEntities.count else { continue }
                    let newValue = QueryResult(fromOrderedEntities: newEntities, for: element.query)
                    element.update(with: newValue)
                }
            }
        }
    }
}

private extension Property where Element: Equatable {
    
    func update(with value: Element) {
        if value != self.value {
            self.value = value
        }
    }
}

// MARK: - ProcessOnceBox

private final class ProcessOnceBox<Identifier, Object> where Identifier: EntityIdentifier {
    
    private let operation: (AnySequence<Object>) -> Void
    private var _processedSet = DualHashSet<Identifier>()
    private let dataQueue = DispatchQueue(label: "\(ProcessOnceBox<Identifier, Object>.self)_data_queue")
    
    init(operation: @escaping (AnySequence<Object>) -> Void) {
        self.operation = operation
    }

    private func process<O, I>(_ objects: O, _ identifiers: I) where O: Sequence, O.Element == Object, I: Sequence, I.Element == Identifier {
        guard dataQueue.sync(execute: {
            var newItems = DualHashSet(identifiers)
            newItems.subtract(_processedSet)
            defer { newItems.forEach { _processedSet.insert($0) } }
            return newItems.isEmpty == false
        }) else { return }
        operation(objects.any)
    }
}

private typealias ProcessOnceIdentifierBox<I: EntityIdentifier> = ProcessOnceBox<I, I>
private typealias ProcessOnceEntityBox<E: Entity> = ProcessOnceBox<E.Identifier, E>

private extension ProcessOnceBox where Identifier == Object {
    
    func process<S>(_ identifiers: S) where S: Sequence, S.Element == Identifier {
        process(identifiers, identifiers)
    }
}

private extension ProcessOnceBox where Object: Entity, Object.Identifier == Identifier {
    
    func process<S>(_ objects: S) where S: Sequence, S.Element == Object {
        process(objects, objects.lazy.map { $0.identifier })
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
        ) -> Signal<AnySequence<AnyEntity>, ManagerError>
        
        private let getByIDs: GetByIDs
        
        public init<CoreManager>(_ coreManager: CoreManager)
            where CoreManager: RelationshipCoreManaging, CoreManager.AnyEntity == AnyEntity, CoreManager.ResultPayload == ResultPayload {

            getByIDs = { identifiers, entityType, context in
                return coreManager.get(byIDs: identifiers, entityType: entityType, in: context)
            }
        }
        
        public func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>, entityType: String, in context: _ReadContext<ResultPayload>) -> Signal<AnySequence<AnyEntity>, ManagerError> {
            return getByIDs(identifiers, entityType, context)
        }
    }
    
    func rootEntity<Graph>(byID identifier: E.Identifier,
                           in context: ReadContext<E>) -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery
        where Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {
            
            return get(byID: identifier, in: context).relationships(from: relationshipManager, in: context)
    }
    
    func rootEntities<S, Graph>(for identifiers: S,
                                in context: ReadContext<E>) -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery
        where S: Sequence, S.Element == E.Identifier, Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {
            
            return RelationshipController.RelationshipQuery(rootEntities: get(byIDs: identifiers, in: context),
                                                            in: context,
                                                            relationshipManager: relationshipManager)
    }

    func rootEntities<Graph>(for query: Query<E> = .all,
                             in context: ReadContext<E>) -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery
        where Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {

            return RelationshipController.RelationshipQuery(rootEntities: search(withQuery: query, in: context),
                                                            in: context,
                                                            relationshipManager: relationshipManager)
    }
}

public extension CoreManaging where E.Identifier == VoidEntityIdentifier {

    func rootEntity<Graph>(in context: ReadContext<E>) -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery
        where Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {

            return rootEntity(byID: VoidEntityIdentifier(), in: context)
    }
}
