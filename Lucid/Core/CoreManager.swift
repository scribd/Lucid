//
//  CoreManager.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/21/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import ReactiveKit

#if !LUCID_REACTIVE_KIT
import Combine
#endif

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

    #if LUCID_REACTIVE_KIT
    public typealias GetEntity = (
        _ query: Query<E>,
        _ context: ReadContext<E>
    ) -> Signal<QueryResult<E>, ManagerError>
    #else
    public typealias GetEntity = (
        _ query: Query<E>,
        _ context: ReadContext<E>
    ) -> AnyPublisher<QueryResult<E>, ManagerError>
    #endif

    #if LUCID_REACTIVE_KIT
    public typealias SearchEntities = (
        _ query: Query<E>,
        _ context: ReadContext<E>
    ) -> (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>)
    #else
    public typealias SearchEntities = (
        _ query: Query<E>,
        _ context: ReadContext<E>
    ) -> (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnyPublisher<QueryResult<E>, Never>)
    #endif

    #if LUCID_REACTIVE_KIT
    public typealias SetEntity = (
        _ entity: E,
        _ context: WriteContext<E>
    ) -> Signal<E, ManagerError>
    #else
    public typealias SetEntity = (
        _ entity: E,
        _ context: WriteContext<E>
    ) -> AnyPublisher<E, ManagerError>
    #endif

    #if LUCID_REACTIVE_KIT
    public typealias SetEntities = (
        _ entities: AnySequence<E>,
        _ context: WriteContext<E>
    ) -> Signal<AnySequence<E>, ManagerError>
    #else
    public typealias SetEntities = (
        _ entities: AnySequence<E>,
        _ context: WriteContext<E>
    ) -> AnyPublisher<AnySequence<E>, ManagerError>
    #endif

    #if LUCID_REACTIVE_KIT
    public typealias RemoveAllEntities = (
        _ query: Query<E>,
        _ context: WriteContext<E>
    ) -> Signal<AnySequence<E.Identifier>, ManagerError>
    #else
    public typealias RemoveAllEntities = (
        _ query: Query<E>,
        _ context: WriteContext<E>
    ) -> AnyPublisher<AnySequence<E.Identifier>, ManagerError>
    #endif

    #if LUCID_REACTIVE_KIT
    public typealias RemoveEntity = (
        _ identifier: E.Identifier,
        _ context: WriteContext<E>
    ) -> Signal<Void, ManagerError>
    #else
    public typealias RemoveEntity = (
        _ identifier: E.Identifier,
        _ context: WriteContext<E>
    ) -> AnyPublisher<Void, ManagerError>
    #endif

    #if LUCID_REACTIVE_KIT
    public typealias RemoveEntities = (
        _ identifiers: AnySequence<E.Identifier>,
        _ context: WriteContext<E>
    ) -> Signal<Void, ManagerError>
    #else
    public typealias RemoveEntities = (
        _ identifiers: AnySequence<E.Identifier>,
        _ context: WriteContext<E>
    ) -> AnyPublisher<Void, ManagerError>
    #endif

    // MARK: - Methods

    private let getEntity: GetEntity
    private let searchEntities: SearchEntities
    private let setEntity: SetEntity
    private let setEntities: SetEntities
    private let removeAllEntities: RemoveAllEntities
    private let removeEntity: RemoveEntity
    private let removeEntities: RemoveEntities
    private weak var relationshipManager: RelationshipManager?

    public init(getEntity: @escaping GetEntity,
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
    #if LUCID_REACTIVE_KIT
    public func get(byID identifier: E.Identifier,
                    in context: ReadContext<E> = ReadContext<E>()) -> Signal<QueryResult<E>, ManagerError> {
        let query = Query<E>.identifier(identifier)
        return getEntity(query, context)
    }
    #else
    public func get(byID identifier: E.Identifier,
                    in context: ReadContext<E> = ReadContext<E>()) -> AnyPublisher<QueryResult<E>, ManagerError> {
        let query = Query<E>.identifier(identifier)
        return getEntity(query, context)
    }
    #endif

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
    #if LUCID_REACTIVE_KIT
    public func search(withQuery query: Query<E>,
                       in context: ReadContext<E> = ReadContext<E>()) -> (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>) {
        return searchEntities(query, context)
    }
    #else
    public func search(withQuery query: Query<E>,
                       in context: ReadContext<E> = ReadContext<E>()) -> (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnyPublisher<QueryResult<E>, Never>) {
        return searchEntities(query, context)
    }
    #endif

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
    #if LUCID_REACTIVE_KIT
    @discardableResult
    public func set(_ entity: E,
                    in context: WriteContext<E>) -> Signal<E, ManagerError> {
        return setEntity(entity, context)
    }
    #else
    @discardableResult
    public func set(_ entity: E,
                    in context: WriteContext<E>) -> AnyPublisher<E, ManagerError> {
        return setEntity(entity, context)
    }
    #endif

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
    #if LUCID_REACTIVE_KIT
    @discardableResult
    public func set<S>(_ entities: S,
                       in context: WriteContext<E>) -> Signal<AnySequence<E>, ManagerError> where S: Sequence, S.Element == E {
        return setEntities(entities.any, context)
    }
    #else
    @discardableResult
    public func set<S>(_ entities: S,
                       in context: WriteContext<E>) -> AnyPublisher<AnySequence<E>, ManagerError> where S: Sequence, S.Element == E {
        return setEntities(entities.any, context)
    }
    #endif

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
    #if LUCID_REACTIVE_KIT
    @discardableResult
    public func removeAll(withQuery query: Query<E>,
                          in context: WriteContext<E>) -> Signal<AnySequence<E.Identifier>, ManagerError> {
        return removeAllEntities(query, context)
    }
    #else
    @discardableResult
    public func removeAll(withQuery query: Query<E>,
                          in context: WriteContext<E>) -> AnyPublisher<AnySequence<E.Identifier>, ManagerError> {
        return removeAllEntities(query, context)
    }
    #endif

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
    #if LUCID_REACTIVE_KIT
    @discardableResult
    public func remove(atID identifier: E.Identifier,
                       in context: WriteContext<E>) -> Signal<Void, ManagerError> {
        return removeEntity(identifier, context)
    }
    #else
    @discardableResult
    public func remove(atID identifier: E.Identifier,
                       in context: WriteContext<E>) -> AnyPublisher<Void, ManagerError> {
        return removeEntity(identifier, context)
    }
    #endif

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
    #if LUCID_REACTIVE_KIT
    @discardableResult
    public func remove<S>(_ identifiers: S,
                          in context: WriteContext<E>) -> Signal<Void, ManagerError> where S: Sequence, S.Element == E.Identifier {
        return removeEntities(identifiers.any, context)
    }
    #else
    @discardableResult
    public func remove<S>(_ identifiers: S,
                          in context: WriteContext<E>) -> AnyPublisher<Void, ManagerError> where S: Sequence, S.Element == E.Identifier {
        return removeEntities(identifiers.any, context)
    }
    #endif
}

public extension CoreManaging {

    /// Retrieve entities from the core manager based on a given query.
    ///
    /// - Parameters:
    ///     - context: Context associated to the query.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `[Entity]` or `ManagerError`.
    #if LUCID_REACTIVE_KIT
    func all(in context: ReadContext<E> = ReadContext<E>()) -> Signal<QueryResult<E>, ManagerError> {
        return search(withQuery: .all, in: context).once
    }
    #else
    func all(in context: ReadContext<E> = ReadContext<E>()) -> AnyPublisher<QueryResult<E>, ManagerError> {
        return search(withQuery: .all, in: context).once
    }
    #endif

    /// Retrieve the first entity found from the core manager based on a given query.
    ///
    /// - Parameters:
    ///     - query: Criteria to run the search query.
    ///     - context: Context associated to the query.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `Entity` or `ManagerError`.
    #if LUCID_REACTIVE_KIT
    func first(for query: Query<E> = .all,
               in context: ReadContext<E> = ReadContext<E>()) -> Signal<E?, ManagerError> {
        return search(withQuery: query, in: context).once.map { $0.first }
    }
    #else
    func first(for query: Query<E> = .all,
               in context: ReadContext<E> = ReadContext<E>()) -> AnyPublisher<E?, ManagerError> {
        return search(withQuery: query, in: context).once.map { $0.first }.eraseToAnyPublisher()
    }
    #endif

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
    #if LUCID_REACTIVE_KIT
    func get<S>(byIDs identifiers: S,
                in context: ReadContext<E> = ReadContext<E>()) -> (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>)
        where S: Sequence, S.Element == E.Identifier {

            let query = Query<E>.filter(.identifier >> identifiers).order([.identifiers(identifiers.any)])

            return search(withQuery: query, in: context)
    }
    #else
    func get<S>(byIDs identifiers: S,
                in context: ReadContext<E> = ReadContext<E>()) -> (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnyPublisher<QueryResult<E>, Never>)
        where S: Sequence, S.Element == E.Identifier {

            let query = Query<E>.filter(.identifier >> identifiers).order([.identifiers(identifiers.any)])

            return search(withQuery: query, in: context)
    }
    #endif
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
    #if LUCID_REACTIVE_KIT
    func firstWithMetadata(for query: Query<E>? = .all,
                           in context: ReadContext<E> = ReadContext<E>()) -> Signal<QueryResult<E>, ManagerError> {

        let signals = search(withQuery: query ?? .all, in: context)
        return signals.once.map { result -> QueryResult<E> in
            guard let entity = result.entity, let metadata = result.metadata else { return .empty() }
            return QueryResult<E>(from: entity, metadata: metadata)
        }
    }
    #else
    func firstWithMetadata(for query: Query<E>? = .all,
                           in context: ReadContext<E> = ReadContext<E>()) -> AnyPublisher<QueryResult<E>, ManagerError> {

        let signals = search(withQuery: query ?? .all, in: context)
        return signals.once.map { result -> QueryResult<E> in
            guard let entity = result.entity, let metadata = result.metadata else { return .empty() }
            return QueryResult<E>(from: entity, metadata: metadata)
        }.eraseToAnyPublisher()
    }
    #endif

    /// Retrieve entity that matches the given identifier.
    ///
    /// - Parameters:
    ///     - identifier: Identifiers used to build an OR query.
    ///     - extras: Any extras you require on the entity.
    ///     - context: Context associated to the query.
    ///
    /// - Returns:
    ///     - A Signal to be observed. It will return a single response of either `QueryResult<Entity>` or `ManagerError`.
    #if LUCID_REACTIVE_KIT
    func get(byID identifier: E.Identifier,
             extras: [E.ExtrasIndexName],
             in context: ReadContext<E> = ReadContext<E>()) -> Signal<QueryResult<E>, ManagerError> {
        let query = Query<E>.identifier(identifier, extras: extras)
        return getEntity(query, context)
    }
    #else
    func get(byID identifier: E.Identifier,
             extras: [E.ExtrasIndexName],
             in context: ReadContext<E> = ReadContext<E>()) -> AnyPublisher<QueryResult<E>, ManagerError> {
        let query = Query<E>.identifier(identifier, extras: extras)
        return getEntity(query, context)
    }
    #endif

    /// Retrieve entities that match one of the given identifiers.
    ///
    /// - Parameters:
    ///     - identifiers: List of identifiers used to build a OR query.
    ///     - extras: Any extras you require on the entity.
    ///     - context: Context associated to the query.
    ///
    /// - Returns:
    ///     - Two Signals, `once` and `continuous`.
    ///     - `once` will return a single response of either `QueryResult<Entity>` or `ManagerError`.
    ///     - `continuous` will return a response of either `[Entity]` or `ManagerError` every time changes occur that
    ///        match the query. It will never be completed and will be retained until you release the dispose bag.
    #if LUCID_REACTIVE_KIT
    func get<S>(byIDs identifiers: S,
                extras: [E.ExtrasIndexName],
                in context: ReadContext<E> = ReadContext<E>()) -> (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>)
        where S: Sequence, S.Element == E.Identifier {

            let query = Query<E>.filter(.identifier >> identifiers).order([.identifiers(identifiers.any)]).extras(extras)
            return search(withQuery: query, in: context)
    }
    #else
    func get<S>(byIDs identifiers: S,
                extras: [E.ExtrasIndexName],
                in context: ReadContext<E> = ReadContext<E>()) -> (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnyPublisher<QueryResult<E>, Never>)
        where S: Sequence, S.Element == E.Identifier {

            let query = Query<E>.filter(.identifier >> identifiers).order([.identifiers(identifiers.any)]).extras(extras)
            return search(withQuery: query, in: context)
    }
    #endif
}

public extension CoreManaging where E.Identifier == VoidEntityIdentifier {

    #if LUCID_REACTIVE_KIT
    func get(in context: ReadContext<E> = ReadContext<E>()) -> Signal<QueryResult<E>, ManagerError> {
        return getEntity(Query.identifier(VoidEntityIdentifier()), context)
    }
    #else
    func get(in context: ReadContext<E> = ReadContext<E>()) -> AnyPublisher<QueryResult<E>, ManagerError> {
        return getEntity(Query.identifier(VoidEntityIdentifier()), context)
    }
    #endif
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

    private let disposeBag = DisposeBag()

    // MARK: - Inits

    public init(stores: [Storing<E>]) {
        self.stores = stores
        localStore = StoreStack(stores: stores.local(), queues: storeStackQueues)
    }

    public func managing<AnyEntityType>(_ relationshipManager: CoreManaging<E, AnyEntityType>.RelationshipManager? = nil) -> CoreManaging<E, AnyEntityType> where AnyEntityType: EntityConvertible {
        #if LUCID_REACTIVE_KIT
        return CoreManaging(getEntity: { self.get(withQuery: $0, in: $1) },
                            searchEntities: { self.search(withQuery: $0, in: $1) },
                            setEntity: { self.set($0, in: $1) },
                            setEntities: { self.set($0, in: $1) },
                            removeAllEntities: { self.removeAll(withQuery: $0, in: $1) },
                            removeEntity: { self.remove(atID: $0, in: $1)},
                            removeEntities: { self.remove($0, in: $1) },
                            relationshipManager: relationshipManager)
        #else
        return CoreManaging(getEntity: { self.get(withQuery: $0, in: $1).toPublisher().eraseToAnyPublisher() },
                            searchEntities: {
                                let signals = self.search(withQuery: $0, in: $1)
                                return (
                                    signals.once.toPublisher().eraseToAnyPublisher(),
                                    signals.continuous.toPublisher().eraseToAnyPublisher()
                                )
                            },
                            setEntity: { self.set($0, in: $1).toPublisher().eraseToAnyPublisher() },
                            setEntities: { self.set($0, in: $1).toPublisher().eraseToAnyPublisher() },
                            removeAllEntities: { self.removeAll(withQuery: $0, in: $1).toPublisher().eraseToAnyPublisher() },
                            removeEntity: { self.remove(atID: $0, in: $1).toPublisher().eraseToAnyPublisher() },
                            removeEntities: { self.remove($0, in: $1).toPublisher().eraseToAnyPublisher() },
                            relationshipManager: relationshipManager)
        #endif
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
             in context: ReadContext<E>) -> Signal<QueryResult<E>, ManagerError> {

        let queryIdentifiers = query.identifiers?.array ?? []
        if queryIdentifiers.count != 1 {
            Logger.log(.error, "\(CoreManager.self) get must be called with a single identifier. Instead found \(queryIdentifiers.count)", assert: true)
        }

        guard let identifier = queryIdentifiers.first else {
            Logger.log(.error, "\(CoreManager.self) can not perform get without valid identifier", assert: true)
            return Signal.failed(.notSupported)
        }

        if let remoteContext = context.remoteContextAfterMakingLocalRequest {
            let localContext = ReadContext<E>(dataSource: .local, accessValidator: context.accessValidator)
            return get(withQuery: query, in: localContext)
                .flatMapError { _ -> Signal<QueryResult<E>, ManagerError> in
                    return Signal(just: .empty())
                }
                .flatMapLatest { localResult -> Signal<QueryResult<E>, ManagerError> in
                    if localResult.entity != nil {
                        if context.shouldFetchFromRemoteWhileFetchingFromLocalStore {
                            self.get(withQuery: query, in: remoteContext).observe { _ in }.dispose(in: self.disposeBag)
                        }
                        return Signal(just: localResult)
                    } else {
                        return self.get(withQuery: query, in: remoteContext)
                            .flatMapError { error -> Signal<QueryResult<E>, ManagerError> in
                                if error.shouldFallBackToLocalStore {
                                    // if we can't reach the remote store, return local results
                                    return Signal(just: localResult)
                                } else {
                                    return .failed(error)
                                }
                            }
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

                    storeStack.get(withQuery: query, in: context) { result in

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
                                            Logger.log(.error, "\(CoreManager.self): An error occurred while writing entity: \(error)", assert: true)
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
                                            Logger.log(.error, "\(CoreManager.self): An error occurred while deleting entity: \(error)", assert: true)
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
                            if error.shouldFallBackToLocalStore {
                                Logger.log(.debug, "\(CoreManager.self): Encountered state while getting entity: \(error)")
                            } else {
                                Logger.log(.error, "\(CoreManager.self): An error occurred while getting entity: \(error)", assert: true)
                            }
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

            let overwriteSearch: (QueryResult<E>?) -> Signal<QueryResult<E>, ManagerError> = { localResult in
                let mapNetworkErrorToLocalResult: ((ManagerError) -> Signal<QueryResult<E>, ManagerError>) = { error in
                    if error.shouldFallBackToLocalStore, let localResult = localResult {
                        // if we can't reach the remote store, return local results
                        return Signal(just: localResult)
                    } else {
                        return .failed(error)
                    }
                }
                return dispatchQueue.sync {
                    if let overwriteSignal = overwriteSignal {
                        return overwriteSignal
                            .flatMapError(mapNetworkErrorToLocalResult)
                    }
                    let signal = self.search(withQuery: query, in: remoteContext)
                        .once
                    overwriteSignal = signal
                    return signal
                        .flatMapError(mapNetworkErrorToLocalResult)
                }
            }

            if context.shouldFetchFromRemoteWhileFetchingFromLocalStore {
                operationQueue.run(title: "\(CoreManager.self):search:1") { operationCompletion in
                    defer { operationCompletion() }
                    overwriteSearch(nil).observe { _ in }.dispose(in: self.disposeBag)
                }
            }

            return (
                once: cacheSearches.once
                    .flatMapError { _ -> Signal<QueryResult<E>, ManagerError> in
                        return Signal(just: QueryResult<E>(fromProcessedEntities: [], for: query))
                    }
                    .flatMapLatest { localResult -> Signal<QueryResult<E>, ManagerError> in
                        let searchIdentifierCount = query.filter?.extractOrIdentifiers?.map { $0 }.count ?? 0
                        let entityResultCount = localResult.count

                        let hasAllIdentifiersLocally = searchIdentifierCount > 0 && entityResultCount == searchIdentifierCount
                        let hasResultsForComplexSearch = searchIdentifierCount == 0 && entityResultCount > 0

                        if hasAllIdentifiersLocally || hasResultsForComplexSearch {
                            return Signal(just: localResult)
                        } else {
                            return overwriteSearch(localResult)
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
                    case .success(let queryResult):

                        if context.shouldOverwriteInLocalStores {
                            self.localStore.search(withQuery: query, in: context) { localResult in

                                switch localResult {
                                case .success(let localResults):
                                    let remoteResults = queryResult.materialized

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
                                                Logger.log(.error, "\(CoreManager.self): An error occurred while writing entities: \(error)", assert: true)
                                            }
                                            dispatchGroup.leave()
                                        }
                                    }

                                    if identifiersToDelete.isEmpty == false {
                                        dispatchGroup.enter()
                                        self.localStore.remove(identifiersToDelete, in: WriteContext(dataTarget: .local)) { result in
                                            if let error = result?.error {
                                                Logger.log(.error, "\(CoreManager.self): An error occurred while deleting entities: \(error)", assert: true)
                                            }
                                            dispatchGroup.leave()
                                        }
                                    }

                                    dispatchGroup.notify(queue: self.storeStackQueues.writeResultsQueue) {
                                        guardedPromise(.success(remoteResults))
                                        self.raiseUpdateEvents(withQuery: query, results: remoteResults, returnsCompleteResultSet: context.returnsCompleteResultSet)
                                    }

                                case .failure(let error):
                                    Logger.log(.error, "\(CoreManager.self): An error occurred while searching entities: \(error)", assert: true)

                                    let entitiesToUpdate = self.filter(entities: queryResult, basedOn: time).compactMap { $0 }
                                    guard entitiesToUpdate.isEmpty == false else {
                                        guardedPromise(.success(queryResult))
                                        return
                                    }
                                    self.setUpdateTime(time, for: entitiesToUpdate.lazy.map { $0.identifier })

                                    self.localStore.set(entitiesToUpdate, in: WriteContext(dataTarget: .local)) { result in
                                        if let error = result?.error {
                                            Logger.log(.error, "\(CoreManager.self): An error occurred while writing entities: \(error)", assert: true)
                                        }
                                        guardedPromise(.success(queryResult))
                                        self.raiseUpdateEvents(withQuery: query, results: queryResult, returnsCompleteResultSet: context.returnsCompleteResultSet)
                                    }
                                }
                            }
                        } else {
                            guardedPromise(.success(queryResult))
                            property.update(with: queryResult)
                        }

                    case .failure(let error):
                        if error.shouldFallBackToLocalStore {
                            Logger.log(.debug, "\(CoreManager.self): Encountered state while searching entities: \(error)")
                        } else {
                            Logger.log(.error, "\(CoreManager.self): An error occurred while searching entities: \(error)", assert: true)
                        }
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
                    self.localStore.get(withQuery: Query.identifier(entity.identifier), in: ReadContext<E>()) { result in
                        switch result {
                        case .success(let queryResult):
                            if let entity = queryResult.entity {
                                guardedPromise(.success(entity))
                            } else {
                                guardedPromise(.failure(.conflict))
                            }
                        case .failure(let error):
                            Logger.log(.error, "\(CoreManager.self): An error occurred while setting entity: \(error)")
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
                            Logger.log(.error, "\(CoreManager.self): An error occurred while setting entity: \(error)")
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
                            Logger.log(.error, "\(CoreManager.self): An error occurred while setting entities: \(error)")
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
                                        Logger.log(.error, "\(CoreManager.self): An error occurred while removing all entities in query: \(error)")
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
                                        Logger.log(.error, "\(CoreManager.self): An error occurred while removing entities for identifiers: \(error)")
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
                            Logger.log(.error, "\(CoreManager.self): An error occurred while removing entity: \(error)")
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
                            Logger.log(.error, "\(CoreManager.self): An error occurred while removing entities: \(error)")
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

    private func _setAndUpdateIdentifierInLocalStores(_ entity: E, originTimestamp: UInt64) -> SafeSignal<Void> {
        let context = WriteContext<E>(dataTarget: .local, remoteSyncState: .createResponse(originTimestamp))
        return set(entity, in: context)
            .toSignal()
            .flatMapLatest { storedResult -> Signal<Void, ManagerError> in
                storedResult.merge(identifier: entity.identifier)
                let context = WriteContext<E>(dataTarget: .local, remoteSyncState: .mergeIdentifier)
                return self.set(storedResult, in: context).toSignal().map { _ in }
            }
            .replaceError(with: ())
    }

    #if LUCID_REACTIVE_KIT
    public func setAndUpdateIdentifierInLocalStores(_ entity: E, originTimestamp: UInt64) -> SafeSignal<Void> {
        return _setAndUpdateIdentifierInLocalStores(entity, originTimestamp: originTimestamp)
    }
    #else
    public func setAndUpdateIdentifierInLocalStores(_ entity: E, originTimestamp: UInt64) -> AnyPublisher<Void, Never> {
        return _setAndUpdateIdentifierInLocalStores(entity, originTimestamp: originTimestamp).toPublisher().eraseToAnyPublisher()
    }
    #endif

    private func _removeFromLocalStores(_ identifier: E.Identifier, originTimestamp: UInt64) -> SafeSignal<Void> {
        let context = WriteContext<E>(dataTarget: .local, remoteSyncState: .createResponse(originTimestamp))
        return remove(atID: identifier, in: context)
            .toSignal()
            .map { _ in }
            .replaceError(with: ())
    }

    #if LUCID_REACTIVE_KIT
    public func removeFromLocalStores(_ identifier: E.Identifier, originTimestamp: UInt64) -> SafeSignal<Void> {
        return _removeFromLocalStores(identifier, originTimestamp: originTimestamp)
    }
    #else
    public func removeFromLocalStores(_ identifier: E.Identifier, originTimestamp: UInt64) -> AnyPublisher<Void, Never> {
        return _removeFromLocalStores(identifier, originTimestamp: originTimestamp).toPublisher().eraseToAnyPublisher()
    }
    #endif
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

                    let newValue = QueryResult(fromProcessedEntities: newEntities, for: element.query)
                    element.update(with: newValue.validatingExtras(with: element.query))
                } else if element.query == query || query.filter == .all {
                    if returnsCompleteResultSet == false,
                        let propertyValue = element.property?.value {
                        let newEntitiesByID = results.reduce(into: DualHashDictionary<E.Identifier, E>()) { $0[$1.identifier] = $1 }
                        var newEntities = propertyValue.update(byReplacingOrAdding: newEntitiesByID)
                        if query.order.contains(where: { $0.isDeterministic }) {
                            newEntities = newEntities.order(with: query.order)
                        }
                        let newValue = QueryResult(fromProcessedEntities: newEntities, for: query)
                        element.update(with: newValue.validatingExtras(with: element.query))
                    } else if element.query.order != query.order,
                        element.query.order.contains(where: { $0.isDeterministic }) {
                        let orderedEntities = results.order(with: element.query.order)
                        let orderedResults = QueryResult(fromProcessedEntities: orderedEntities, for: element.query)
                        element.update(with: orderedResults.validatingExtras(with: element.query))
                    } else {
                        element.update(with: results.validatingExtras(with: element.query))
                    }
                } else if let propertyValue = element.property?.value {
                    let newEntitiesByID = results.reduce(into: DualHashDictionary<E.Identifier, E>()) { $0[$1.identifier] = $1 }
                    var newEntities = element.query.filter == .all ?
                        propertyValue.update(byReplacingOrAdding: newEntitiesByID) :
                        propertyValue.update(byReplacing: newEntitiesByID)

                    if element.query.order.contains(where: { $0.isDeterministic }) {
                        newEntities = newEntities.order(with: element.query.order)
                    }
                    let newValue = QueryResult(fromProcessedEntities: newEntities, for: element.query)
                    element.update(with: newValue.validatingExtras(with: element.query))
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
                    let newValue = QueryResult(fromProcessedEntities: newEntities, for: element.query)
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

        #if LUCID_REACTIVE_KIT
        public typealias GetByIDs = (
            _ identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
            _ entityType: String,
            _ context: _ReadContext<ResultPayload>
        ) -> Signal<AnySequence<AnyEntity>, ManagerError>
        #else
        public typealias GetByIDs = (
            _ identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
            _ entityType: String,
            _ context: _ReadContext<ResultPayload>
        ) -> AnyPublisher<AnySequence<AnyEntity>, ManagerError>
        #endif

        private let getByIDs: GetByIDs

        public init<CoreManager>(_ coreManager: CoreManager)
            where CoreManager: RelationshipCoreManaging, CoreManager.AnyEntity == AnyEntity, CoreManager.ResultPayload == ResultPayload {

            getByIDs = { identifiers, entityType, context in
                return coreManager.get(byIDs: identifiers, entityType: entityType, in: context)
            }
        }

        #if LUCID_REACTIVE_KIT
        public func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>, entityType: String, in context: _ReadContext<ResultPayload>) -> Signal<AnySequence<AnyEntity>, ManagerError> {
            return getByIDs(identifiers, entityType, context)
        }
        #else
        public func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>, entityType: String, in context: _ReadContext<ResultPayload>) -> AnyPublisher<AnySequence<AnyEntity>, ManagerError> {
            return getByIDs(identifiers, entityType, context)
        }
        #endif
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

public extension CoreManaging where E: RemoteEntity {

    func rootEntity<Graph>(byID identifier: E.Identifier,
                           extras: [E.ExtrasIndexName],
                           in context: ReadContext<E>) -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery
        where Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {

            return get(byID: identifier, extras: extras, in: context).relationships(from: relationshipManager, in: context)
    }

    func rootEntities<S, Graph>(for identifiers: S,
                                extras: [E.ExtrasIndexName],
                                in context: ReadContext<E>) -> RelationshipController<RelationshipManager, Graph>.RelationshipQuery
        where S: Sequence, S.Element == E.Identifier, Graph: MutableGraph, Graph.AnyEntity == RelationshipManager.AnyEntity {

            return RelationshipController.RelationshipQuery(rootEntities: get(byIDs: identifiers, extras: extras, in: context),
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
