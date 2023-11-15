//
//  Store.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/20/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

// MARK: - Error

public indirect enum StoreError: Error, Equatable {
    case composite(current: StoreError, previous: StoreError)
    case unknown(NSError)
    case notSupported
    case api(APIError)
    case notFoundInPayload
    case emptyStack
    case invalidCoreDataState
    case invalidCoreDataEntity
    case coreData(NSError)
    case invalidContext
    case identifierNotSynced
    case identifierNotFound
    case emptyResponse
    case enqueueingError
}

// MARK: - StoreLevel

/// Level at which a `Store` is placed in a `StoreStack`.
///
/// E.g. when requesting entities, `InMemoryStore` goes first, then
/// `OnDiskStore` and `RemoteStore` goes last.
///
/// - Note: `StoreLevel` is only considered for reading since writes are
///         always executed on all stores in parrallel.
public enum StoreLevel: Int, Comparable {
    case memory = 0
    case disk = 1
    case remote = 2

    public static func < (lhs: StoreLevel, rhs: StoreLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var isLocal: Bool {
        switch self {
        case .memory,
             .disk:
            return true
        case .remote:
            return false
        }
    }

    var isRemote: Bool {
        return isLocal == false
    }
}

// MARK: - StoringConvertible

/// Store able to convert to its interface type (`Storing`).
///
/// The `Store` is in charge of writing/reading one type of entities.
///
/// - Requires: Thread-safety
public protocol StoringConvertible: AnyObject {

    /// Entity type.
    associatedtype E: Entity

    /// Interface type of a `Store`.
    var storing: Storing<E> { get }

    /// Level at which a `Store` is placed in a `StoreStack`.
    var level: StoreLevel { get }

    /// Retrieve an entity based on its identifier.
    ///
    /// - Parameters:
    ///     - query: `Query` to run. Create with Query.identifier().
    ///     - context: Details how to access the data.
    ///     - completion: Block to be called with either an `Entity` or a `StoreError`.
    func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void)

    /// Retrieve an entity based on its identifier.
    ///
    /// - Parameters:
    ///     - query: `Query` to run. Create with Query.identifier().
    ///     - context: Details how to access the data.
    /// - Returns:
    ///     - Result with either an `Entity` or a `StoreError`.
    func get(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError>

    /// Run a search query resulting with a filtered/ordered set of entities.
    ///
    /// - Parameters:
    ///     - query: `Query` to run.
    ///     - context: Details how to access the data.
    ///     - completion: Block to be called with either a `QueryResult` or a `StoreError`.
    func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void)

    /// Run a search query resulting with a filtered/ordered set of entities.
    ///
    /// - Parameters:
    ///     - query: `Query` to run.
    ///     - context: Details how to access the data.
    /// - Returns:
    ///     - Result with either a `QueryResult` or a `StoreError`.
    func search(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError>

    /// Write an `Entity` to the `Store`.
    ///
    /// - Parameters:
    ///     - entity: `Entity` to write.
    ///     - context: Details how to store the data.
    ///     - completion: Block to be called with optional result of the written `Entity` or `StoreError`. A response of `nil` means the response should be ignored.
    func set(_ entity: E, in context: WriteContext<E>, completion: @escaping (Result<E, StoreError>?) -> Void)

    /// Write an `Entity` to the `Store`.
    ///
    /// - Parameters:
    ///     - entity: `Entity` to write.
    ///     - context: Details how to store the data.
    /// - Returns:
    ///     - Optional result of the written `Entity` or `StoreError`. A response of `nil` means the response should be ignored.
    func set(_ entity: E, in context: WriteContext<E>) async -> Result<E, StoreError>?

    /// Bulk write an array of entities to the `Store`.
    ///
    /// - Parameters:
    ///     - entities: Entities to write.
    ///     - context: Details how to store the data.
    ///     - completion: Block to be called with optional result of an array of written entities or `StoreError`. A response of `nil` means the response should be ignored.
    func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E

    /// Bulk write an array of entities to the `Store`.
    ///
    /// - Parameters:
    ///     - entities: Entities to write.
    ///     - context: Details how to store the data.
    /// - Returns:
    ///     - Optional result of an array of written entities or `StoreError`. A response of `nil` means the response should be ignored.
    func set<S>(_ entities: S, in context: WriteContext<E>) async -> Result<AnySequence<E>, StoreError>? where S: Sequence, S.Element == E

    /// Delete all `Entity` objects that match the query.
    ///
    /// - Parameters:
    ///     - query: `Query` that defines matching entities to be deleted.
    ///     - context: Details how to store the data.
    ///     - completion: Block to be called with optional result `[E.Identifier]` or `StoreError`. A response of `nil` means the response should be ignored.
    func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void)

    /// Delete all `Entity` objects that match the query.
    ///
    /// - Parameters:
    ///     - query: `Query` that defines matching entities to be deleted.
    ///     - context: Details how to store the data.
    /// - Returns:
    ///     - Optional result `[E.Identifier]` or `StoreError`. A response of `nil` means the response should be ignored.
    func removeAll(withQuery query: Query<E>, in context: WriteContext<E>) async -> Result<AnySequence<E.Identifier>, StoreError>?

    /// Delete an `Entity` based on its identifier.
    ///
    /// - Parameters:
    ///     - identifier: Entity's identifier.
    ///     - context: Details how to store the data.
    ///     - completion: Block to be called with optional result `Void` or `StoreError`. A response of `nil` means the response should be ignored.
    func remove(atID identifier: E.Identifier, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void)

    /// Delete an `Entity` based on its identifier.
    ///
    /// - Parameters:
    ///     - identifier: Entity's identifier.
    ///     - context: Details how to store the data.
    /// - Returns:
    ///     - Optional result `Void` or `StoreError`. A response of `nil` means the response should be ignored.
    func remove(atID identifier: E.Identifier, in context: WriteContext<E>) async -> Result<Void, StoreError>?

    /// Bulk delete an `Entity` based on its identifier.
    ///
    /// - Parameters:
    ///     - identifier: Entities' identifiers.
    ///     - context: Details how to store the data.
    ///     - completion: Block to be called with either `Void` or a `StoreError`. A response of `nil` means the response should be ignored.
    func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier

    /// Bulk delete an `Entity` based on its identifier.
    ///
    /// - Parameters:
    ///     - identifier: Entities' identifiers.
    ///     - context: Details how to store the data.
    /// - Returns:
    ///     - Result with either `Void` or a `StoreError`. A response of `nil` means the response should be ignored.
    func remove<S>(_ identifiers: S, in context: WriteContext<E>) async -> Result<Void, StoreError>? where S: Sequence, S.Element == E.Identifier
}

public extension StoringConvertible {

    var storing: Storing<E> {
        return Storing(level: level,
                       getEntity: { self.get(withQuery: $0, in: $1, completion: $2) },
                       getEntityAsync: { await self.get(withQuery: $0, in: $1) },
                       searchEntities: { self.search(withQuery: $0, in: $1, completion: $2) },
                       searchEntitiesAsync: { await self.search(withQuery: $0, in: $1) },
                       setEntity: { self.set($0, in: $1, completion: $2) },
                       setEntityAsync: { await self.set($0, in: $1) },
                       setEntities: { self.set($0, in: $1, completion: $2) },
                       setEntitiesAsync: { await self.set($0, in: $1) },
                       removeAllEntities: { self.removeAll(withQuery: $0, in: $1, completion: $2) },
                       removeAllEntitiesAsync: { await self.removeAll(withQuery: $0, in: $1) },
                       removeEntity: { self.remove(atID: $0, in: $1, completion: $2) },
                       removeEntityAsync: { await self.remove(atID: $0, in: $1) },
                       removeEntities: { self.remove($0, in: $1, completion: $2) },
                       removeEntitiesAsync: { await self.remove($0, in: $1) })
    }

    func get(byID identifier: E.Identifier, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        get(withQuery: Query.identifier(identifier), in: context, completion: completion)
    }

    func get(byID identifier: E.Identifier, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        return await get(withQuery: Query.identifier(identifier), in: context)
    }

    func set(_ entity: E, in context: WriteContext<E>, completion: @escaping (Result<E, StoreError>?) -> Void) {
        set([entity], in: context) { result in
            switch result {
            case .some(.success(let entities)) where !entities.isEmpty:
                guard let entity = entities.first else {
                    completion(.failure(.notSupported))
                    return
                }
                completion(.success(entity))
            case .some(.success):
                Logger.log(.error, "\(Self.self): Should never happen. If it does, fix asap.", assert: true)
                completion(.failure(.notSupported))
            case .some(.failure(let error)):
                completion(.failure(error))
            case .none:
                completion(nil)
            }
        }
    }

    func set(_ entity: E, in context: WriteContext<E>) async -> Result<E, StoreError>? {
        let result = await self.set([entity], in: context)
        switch result {
        case .some(.success(let entities)) where entities.isEmpty == false:
            guard let entity = entities.first else {
                return .failure(.notSupported)
            }
            return .success(entity)
        case .some(.success):
            Logger.log(.error, "\(Self.self): Should never happen. If it does, fix asap.", assert: true)
            return .failure(.notSupported)
        case .some(.failure(let error)):
            return .failure(error)
        case .none:
            return nil
        }
    }

    func remove(atID identifier: E.Identifier, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) {
        remove([identifier], in: context, completion: completion)
    }

    func remove(atID identifier: E.Identifier, in context: WriteContext<E>) async -> Result<Void, StoreError>? {
        return await remove([identifier], in: context)
    }
}

// MARK: - Storing

/// Interface type of a `Store`.
///
/// - Note: A struct is used as a protocol in order to be able to carry the `Entity` type `E`
///         without the limitation of using an `associatedtype`.
public struct Storing<E: Entity> {

    let level: StoreLevel

    // MARK: - Method Types

    fileprivate typealias GetEntity = (
        _ query: Query<E>,
        _ context: ReadContext<E>,
        _ completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void
    ) -> Void

    fileprivate typealias GetEntityAsync = (
        _ query: Query<E>,
        _ context: ReadContext<E>
    ) async -> Result<QueryResult<E>, StoreError>

    fileprivate typealias SearchEntities = (
        _ query: Query<E>,
        _ context: ReadContext<E>,
        _ completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void
    ) -> Void

    fileprivate typealias SearchEntitiesAsync = (
        _ query: Query<E>,
        _ context: ReadContext<E>
    ) async -> Result<QueryResult<E>, StoreError>

    fileprivate typealias SetEntity = (
        _ entity: E,
        _ context: WriteContext<E>,
        _ completion: @escaping (Result<E, StoreError>?) -> Void
    ) -> Void

    fileprivate typealias SetEntityAsync = (
        _ entity: E,
        _ context: WriteContext<E>
    ) async -> Result<E, StoreError>?

    fileprivate typealias SetEntities = (
        _ entities: AnySequence<E>,
        _ context: WriteContext<E>,
        _ completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void
    ) -> Void

    fileprivate typealias SetEntitiesAsync = (
        _ entities: AnySequence<E>,
        _ context: WriteContext<E>
    ) async -> Result<AnySequence<E>, StoreError>?

    fileprivate typealias RemoveAllEntities = (
        _ query: Query<E>,
        _ context: WriteContext<E>,
        _ completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void
    ) -> Void

    fileprivate typealias RemoveAllEntitiesAsync = (
        _ query: Query<E>,
        _ context: WriteContext<E>
    ) async -> Result<AnySequence<E.Identifier>, StoreError>?

    fileprivate typealias RemoveEntity = (
        _ identifier: E.Identifier,
        _ context: WriteContext<E>,
        _ completion: @escaping (Result<Void, StoreError>?) -> Void
    ) -> Void

    fileprivate typealias RemoveEntityAsync = (
        _ identifier: E.Identifier,
        _ context: WriteContext<E>
    ) async -> Result<Void, StoreError>?

    fileprivate typealias RemoveEntities = (
        _ identifiers: AnySequence<E.Identifier>,
        _ context: WriteContext<E>,
        _ completion: @escaping (Result<Void, StoreError>?) -> Void
    ) -> Void

    fileprivate typealias RemoveEntitiesAsync = (
        _ identifiers: AnySequence<E.Identifier>,
        _ context: WriteContext<E>
    ) async -> Result<Void, StoreError>?

    // MARK: - Methods

    fileprivate let getEntity: GetEntity
    fileprivate let getEntityAsync: GetEntityAsync
    fileprivate let searchEntities: SearchEntities
    fileprivate let searchEntitiesAsync: SearchEntitiesAsync
    fileprivate let setEntity: SetEntity
    fileprivate let setEntityAsync: SetEntityAsync
    fileprivate let setEntities: SetEntities
    fileprivate let setEntitiesAsync: SetEntitiesAsync
    fileprivate let removeAllEntities: RemoveAllEntities
    fileprivate let removeAllEntitiesAsync: RemoveAllEntitiesAsync
    fileprivate let removeEntity: RemoveEntity
    fileprivate let removeEntityAsync: RemoveEntityAsync
    fileprivate let removeEntities: RemoveEntities
    fileprivate let removeEntitiesAsync: RemoveEntitiesAsync

    // MARK: - API

    public func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        getEntity(query, context, completion)
    }

    public func get(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        return await getEntityAsync(query, context)
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        searchEntities(query, context, completion)
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        return await searchEntitiesAsync(query, context)
    }

    public func set(_ entity: E, in context: WriteContext<E>, completion: @escaping (Result<E, StoreError>?) -> Void) {
        setEntity(entity, context, completion)
    }

    public func set(_ entity: E, in context: WriteContext<E>) async -> Result<E, StoreError>? {
        return await setEntityAsync(entity, context)
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {
        setEntities(entities.any, context, completion)
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>) async -> Result<AnySequence<E>, StoreError>? where S: Sequence, S.Element == E {
        return await setEntitiesAsync(entities.any, context)
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {
        removeAllEntities(query, context, completion)
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>) async -> Result<AnySequence<E.Identifier>, StoreError>? {
        return await removeAllEntitiesAsync(query, context)
    }

    public func remove(atID identifier: E.Identifier, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) {
        removeEntity(identifier, context, completion)
    }

    public func remove(atID identifier: E.Identifier, in context: WriteContext<E>) async -> Result<Void, StoreError>? {
        return await removeEntityAsync(identifier, context)
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {
        removeEntities(identifiers.any, context, completion)
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>) async -> Result<Void, StoreError>? where S: Sequence, S.Element == E.Identifier {
        return await removeEntitiesAsync(identifiers.any, context)
    }
}

public extension Storing {

    func get(byID identifier: E.Identifier, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        getEntity(Query.identifier(identifier), context, completion)
    }

    func get(byID identifier: E.Identifier, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        return await getEntityAsync(Query.identifier(identifier), context)
    }
}

// MARK: - StoreStack

/// Stack of stores able to perform read/write operations on each contained stores.
///
/// - Note: Read operations are performed sequentially while write operation are
///         performed in parrallele.
/// - Note: Fully threadsafe.
final class StoreStack<E: Entity> {

    private let readWriteQueue: DispatchQueue
    private let contractQueue: DispatchQueue
    private let writeResultsQueue: DispatchQueue

    private let readWriteAsyncQueue: AsyncTaskQueue
    private let contractAsyncQueue: AsyncTaskQueue
    private let writeResultsAsyncQueue: AsyncTaskQueue

    private let stores: [Storing<E>]

    // MARK: - Init

    init(stores: [Storing<E>], queues: StoreStackQueues<E>) {
        self.stores = stores
        self.readWriteQueue = queues.readWriteQueue
        self.readWriteAsyncQueue = queues.readWriteAsyncQueue
        self.writeResultsQueue = queues.writeResultsQueue
        self.writeResultsAsyncQueue = queues.writeResultsAsyncQueue
        self.contractQueue = queues.contractQueue
        self.contractAsyncQueue = queues.contractAsyncQueue
    }

    // MARK: - Get

    func get(withQuery query: Query<E>,
             in context: ReadContext<E>,
             completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        get(withQuery: query, in: context, stores: stores, completion: completion)
    }

    func get(withQuery query: Query<E>,
             in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        return await get(withQuery: query, in: context, stores: stores)
    }

    private func get(withQuery query: Query<E>,
                     in context: ReadContext<E>,
                     stores: [Storing<E>],
                     error: StoreError? = nil,
                     completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        var stores = stores

        guard let store = stores.first else {
            readWriteQueue.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(.empty()))
                }
            }
            return
        }

        stores.removeFirst()

        store.get(withQuery: query, in: context) { result in
            switch result {
            case .success(let queryResult):
                self.contractQueue.async {
                    let (validatedResult, invalidCount) = queryResult.validatingContract(context.contract, with: query)
                    let shouldRefetch = invalidCount > 0 || validatedResult.isEmpty
                    if shouldRefetch {
                        self.get(withQuery: query, in: context, stores: stores, error: error, completion: completion)
                    } else {
                        self.readWriteQueue.async {
                            completion(.success(validatedResult))
                        }
                    }
                }
            case .failure(let currentError):
                let error = currentError.compose(with: error)
                self.get(withQuery: query, in: context, stores: stores, error: error, completion: completion)
            }
        }
    }

    private func get(withQuery query: Query<E>,
                     in context: ReadContext<E>,
                     stores: [Storing<E>],
                     error: StoreError? = nil) async -> Result<QueryResult<E>, StoreError> {
        var stores = stores

        guard let store = stores.first else {
            do {
                return try await readWriteAsyncQueue.enqueue {
                    if let error = error {
                        return .failure(error)
                    } else {
                        return .success(.empty())
                    }
                }
            } catch {
                return .failure(.notSupported)
            }
        }

        stores.removeFirst()

        // Make a copy for using within concurrency
        let storesCopy = stores

        let storeResult = await store.get(withQuery: query, in: context)
        switch storeResult {
        case .success(let queryResult):
            do {
                return try await self.contractAsyncQueue.enqueue {

                    let (validatedResult, invalidCount) = queryResult.validatingContract(context.contract, with: query)
                    let shouldRefetch = invalidCount > 0 || validatedResult.isEmpty
                    if shouldRefetch {
                        return await Task { return await self.get(withQuery: query, in: context, stores: storesCopy, error: error) }.value
                    } else {
                        return try await self.readWriteAsyncQueue.enqueue {
                            return .success(validatedResult)
                        }
                    }
                }
            } catch {
                return .failure(.notSupported)
            }
        case .failure(let currentError):
            let error = currentError.compose(with: error)
            return await self.get(withQuery: query, in: context, stores: stores, error: error)
        }
    }

    // MARK: - Search

    func search(withQuery query: Query<E>,
                in context: ReadContext<E>,
                completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        guard stores.isEmpty == false else {
            readWriteQueue.async {
                completion(.success(.entities(AnySequence.empty)))
            }
            return
        }

        let stores: [Storing<E>] = {
            if query.order.contains(where: { $0.isNatural}) && self.stores.contains(where: { $0.level.isLocal }) {
                Logger.log(.error, "\(StoreStack.self): Natural ordering is incompatible with local stores. Only the remote stores will be reached.", assert: true)
                return self.stores.filter { !$0.level.isLocal }
            } else {
                return self.stores
            }
        }()

        search(withQuery: query, in: context, stores: stores, completion: completion)
    }

    func search(withQuery query: Query<E>,
                in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        guard stores.isEmpty == false else {
            do {
                return try await readWriteAsyncQueue.enqueue {
                    return .success(.entities(AnySequence.empty))
                }
            } catch {
                return .failure(.notSupported)
            }
        }

        let stores: [Storing<E>] = {
            if query.order.contains(where: { $0.isNatural}) && self.stores.contains(where: { $0.level.isLocal }) {
                Logger.log(.error, "\(StoreStack.self): Natural ordering is incompatible with local stores. Only the remote stores will be reached.", assert: true)
                return self.stores.filter { !$0.level.isLocal }
            } else {
                return self.stores
            }
        }()

        return await search(withQuery: query, in: context, stores: stores)
    }

    private func search(withQuery query: Query<E>,
                        in context: ReadContext<E>,
                        stores: [Storing<E>],
                        error: StoreError? = nil,
                        completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        var stores = stores

        guard let store = stores.first else {
            readWriteQueue.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(.entities(AnySequence.empty)))
                }
            }
            return
        }

        stores.removeFirst()

        store.search(withQuery: query, in: context) { result in
            switch result {
            case .success(let queryResult):
                self.contractQueue.async {
                    let (validatedResult, invalidCount) = queryResult.validatingContract(context.contract, with: query)
                    let shouldRefetch = (invalidCount > 0 || validatedResult.isEmpty) && stores.isEmpty == false && store.level.isLocal
                    if shouldRefetch {
                        self.search(withQuery: query, in: context, stores: stores, error: error, completion: completion)
                    } else {
                        self.readWriteQueue.async {
                            completion(.success(validatedResult))
                        }
                    }
                }

            case .failure(let currentError):
                let error = currentError.compose(with: error)
                self.search(withQuery: query, in: context, stores: stores, error: error, completion: completion)
            }
        }
    }

    private func search(withQuery query: Query<E>,
                        in context: ReadContext<E>,
                        stores: [Storing<E>],
                        error: StoreError? = nil) async -> Result<QueryResult<E>, StoreError> {
        var stores = stores

        guard let store = stores.first else {
            do {
                return try await readWriteAsyncQueue.enqueue {
                    if let error = error {
                        return .failure(error)
                    } else {
                        return .success(.entities(AnySequence.empty))
                    }
                }
            } catch {
                return .failure(.notSupported)
            }
        }

        stores.removeFirst()

        // Make a copy for using within concurrency
        let storesCopy = stores

        let storeResult = await store.search(withQuery: query, in: context)
        switch storeResult {
        case .success(let queryResult):
            do {
                return try await self.contractAsyncQueue.enqueue {
                    let (validatedResult, invalidCount) = queryResult.validatingContract(context.contract, with: query)
                    let shouldRefetch = (invalidCount > 0 || validatedResult.isEmpty) && storesCopy.isEmpty == false && store.level.isLocal
                    if shouldRefetch {
                        return await Task { await self.search(withQuery: query, in: context, stores: storesCopy, error: error) }.value
                    } else {
                        return try await self.readWriteAsyncQueue.enqueue {
                            return .success(validatedResult)
                        }
                    }
                }
            } catch {
                return .failure(.notSupported)
            }
        case .failure(let currentError):
            let error = currentError.compose(with: error)
            return await self.search(withQuery: query, in: context, stores: stores, error: error)
        }
    }

    // MARK: - Set

    func set(_ entity: E,
             in context: WriteContext<E>,
             localStoresCompletion: @escaping (Result<E, StoreError>?) -> Void = { _ in },
             allStoresCompletion: @escaping (Result<E, StoreError>?) -> Void) {

        guard stores.isEmpty == false else {
            writeResultsQueue.async {
                allStoresCompletion(.success(entity))
            }
            return
        }

        runInParallel(handler: { $0.set(entity, in: context, completion: $1) },
                      localStoresCompletion: localStoresCompletion,
                      allStoresCompletion: allStoresCompletion)
    }

    func set(_ entity: E,
             in context: WriteContext<E>,
             localStoresCompletion: @escaping (Result<E, StoreError>?) -> Void = { _ in }) async -> Result<E, StoreError>? {

        guard stores.isEmpty == false else {
            do {
                return try await writeResultsAsyncQueue.enqueue {
                    return .success(entity)
                }
            } catch {
                return .failure(.notSupported)
            }
        }

        let handler: (Storing<E>, (Result<E, StoreError>?) async -> Void) async -> Void = { store, resultHandler in
            let result = await store.set(entity, in: context)
            await resultHandler(result)
        }

        return await runInParallel(handler: handler,
                                   localStoresCompletion: localStoresCompletion)
    }

    func set<S>(_ entities: S,
                in context: WriteContext<E>,
                localStoresCompletion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void = { _ in },
                allStoresCompletion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {

        guard stores.isEmpty == false else {
            writeResultsQueue.async {
                allStoresCompletion(.success(entities.any))
            }
            return
        }

        runInParallel(handler: { $0.set(entities, in: context, completion: $1) },
                      localStoresCompletion: localStoresCompletion,
                      allStoresCompletion: allStoresCompletion)
    }

    func set<S>(_ entities: S,
                in context: WriteContext<E>,
                localStoresCompletion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void = { _ in }) async -> Result<AnySequence<E>, StoreError>? where S: Sequence, S.Element == E {

        guard stores.isEmpty == false else {
            do {
                return try await writeResultsAsyncQueue.enqueue {
                   return .success(entities.any)
                }
            } catch {
                return .failure(.notSupported)
            }
        }

        let handler: (Storing<E>, (Result<AnySequence<E>, StoreError>?) async -> Void) async -> Void = { store, resultHandler in
            let result = await store.set(entities, in: context)
            await resultHandler(result)
        }

        return await runInParallel(handler: handler,
                                   localStoresCompletion: localStoresCompletion)
    }

    // MARK: - Remove

    func removeAll(withQuery query: Query<E>,
                   in context: WriteContext<E>,
                   localStoresCompletion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void = { _ in },
                   allStoresCompletion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {

        guard stores.isEmpty == false else {
            writeResultsQueue.async {
                allStoresCompletion(.success(.empty))
            }
            return
        }

        runInParallel(handler: { $0.removeAll(withQuery: query, in: context, completion: $1) },
                      localStoresCompletion: localStoresCompletion,
                      allStoresCompletion: allStoresCompletion)
    }

    func removeAll(withQuery query: Query<E>,
                   in context: WriteContext<E>,
                   localStoresCompletion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void = { _ in }) async -> Result<AnySequence<E.Identifier>, StoreError>? {

        guard stores.isEmpty == false else {
            do {
                return try await writeResultsAsyncQueue.enqueue {
                    return .success(.empty)
                }
            } catch {
                return .failure(.notSupported)
            }
        }

        let handler: (Storing<E>, (Result<AnySequence<E.Identifier>, StoreError>?) async -> Void) async -> Void = { store, resultHandler in
            let result = await store.removeAll(withQuery: query, in: context)
            await resultHandler(result)
        }

        return await runInParallel(handler: handler,
                                   localStoresCompletion: localStoresCompletion)
    }

    func remove(atID identifier: E.Identifier,
                in context: WriteContext<E>,
                localStoresCompletion: @escaping (Result<Void, StoreError>?) -> Void = { _ in },
                allStoresCompletion: @escaping (Result<Void, StoreError>?) -> Void) {

        guard stores.isEmpty == false else {
            writeResultsQueue.async(flags: .barrier) {
                allStoresCompletion(.success(()))
            }
            return
        }

        runInParallel(handler: { $0.remove(atID: identifier, in: context, completion: $1) },
                      localStoresCompletion: localStoresCompletion,
                      allStoresCompletion: allStoresCompletion)
    }

    func remove(atID identifier: E.Identifier,
                in context: WriteContext<E>,
                localStoresCompletion: @escaping (Result<Void, StoreError>?) -> Void = { _ in }) async -> Result<Void, StoreError>? {

        guard stores.isEmpty == false else {
            do {
                return try await writeResultsAsyncQueue.enqueue {
                    return .success(())
                }
            } catch {
                return .failure(.notSupported)
            }
        }

        let handler: (Storing<E>, (Result<Void, StoreError>?) async -> Void) async -> Void = { store, resultHandler in
            let result = await store.remove(atID: identifier, in: context)
            await resultHandler(result)
        }

        return await runInParallel(handler: handler,
                                   localStoresCompletion: localStoresCompletion)
    }

    func remove<S>(_ identifiers: S,
                   in context: WriteContext<E>,
                   localStoresCompletion: @escaping (Result<Void, StoreError>?) -> Void = { _ in }) async -> Result<Void, StoreError>? where S: Sequence, S.Element == E.Identifier {

        guard stores.isEmpty == false else {
            do {
                return try await writeResultsAsyncQueue.enqueue {
                    return .success(())
                }
            } catch {
                return .failure(.notSupported)
            }
        }

        let handler: (Storing<E>, (Result<Void, StoreError>?) async -> Void) async -> Void = { store, resultHandler in
            let result = await store.remove(identifiers, in: context)
            await resultHandler(result)
        }

        return await runInParallel(handler: handler,
                                   localStoresCompletion: localStoresCompletion)
    }

    func remove<S>(_ identifiers: S,
                   in context: WriteContext<E>,
                   localStoresCompletion: @escaping (Result<Void, StoreError>?) -> Void = { _ in },
                   allStoresCompletion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {

        guard stores.isEmpty == false else {
            writeResultsQueue.async {
                allStoresCompletion(.success(()))
            }
            return
        }

        runInParallel(handler: { $0.remove(identifiers, in: context, completion: $1) },
                      localStoresCompletion: localStoresCompletion,
                      allStoresCompletion: allStoresCompletion)
    }
}

extension StoreStack {

    func get(byID identifier: E.Identifier, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        get(withQuery: Query.identifier(identifier), in: context, completion: completion)
    }

    func get(byID identifier: E.Identifier, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        return await get(withQuery: Query.identifier(identifier), in: context)
    }
}

// MARK: - Utils

private extension StoreStack {

    func runInParallel<Output>(handler: @escaping (Storing<E>, @escaping (Result<Output, StoreError>?) -> Void) -> Void,
                               localStoresCompletion: @escaping (Result<Output, StoreError>?) -> Void,
                               allStoresCompletion: @escaping (Result<Output, StoreError>?) -> Void) {

        guard stores.isEmpty == false else {
            readWriteQueue.async {
                allStoresCompletion(.failure(.emptyStack))
            }
            return
        }

        let allStoresDispatchGroup = DispatchGroup()
        let localStoresDispatchGroup = DispatchGroup()

        for store in stores {
            if store.level.isLocal {
                localStoresDispatchGroup.enter()
            }
            allStoresDispatchGroup.enter()
        }

        var results = [Int: Result<Output, StoreError>?]()

        for (index, store) in stores.enumerated() {
            handler(store, { result in
                self.readWriteQueue.async(flags: .barrier) {
                    results[index] = result
                    if store.level.isLocal {
                        localStoresDispatchGroup.leave()
                    }
                    allStoresDispatchGroup.leave()
                }
            })
        }

        localStoresDispatchGroup.notify(queue: writeResultsQueue) {
            let results = self.stores.enumerated().compactMap { (index, store) -> Result<Output, StoreError>?? in
                store.level.isLocal ? results[index] : nil
            }
            guard results.isEmpty == false else { return }
            localStoresCompletion(self.collectResult(from: results))
        }

        allStoresDispatchGroup.notify(queue: writeResultsQueue) {
            let results = self.stores.enumerated().compactMap { (index, _) in results[index] }
            allStoresCompletion(self.collectResult(from: results))
        }
    }

    private actor StoreResult<Output> {
        var results: [Int: Result<Output, StoreError>?] = [:]

        func append(result: Result<Output, StoreError>?, at index: Int) {
            results[index] = result
        }

        func get(at index: Int) -> Result<Output, StoreError>? {
            return results[index] ?? nil
        }
    }

    func runInParallel<Output>(handler: @escaping (Storing<E>, @escaping (Result<Output, StoreError>?) async -> Void) async -> Void,
                               localStoresCompletion: @escaping (Result<Output, StoreError>?) -> Void) async -> Result<Output, StoreError>? {

        guard stores.isEmpty == false else {
            do {
                return try await readWriteAsyncQueue.enqueue {
                    return .failure(.emptyStack)
                }
            } catch {
                Logger.log(.error, "Error while enqueuing the async Task")
                return .failure(.notSupported)
            }
        }

        let results = StoreResult<Output>()

        @Sendable func handleStore(store: Storing<E>, at index: Int) async -> Void {
            await handler(store, { result in
                do {
                    try await self.readWriteAsyncQueue.enqueue {
                        await results.append(result: result, at: index)
                    }
                } catch {
                    Logger.log(.error, "\(StoreStack.self) Found error while enqueuing the async Task")
                }
            })
        }

        let localStores: [(Int, Storing<E>)] = stores.enumerated().filter { $1.level.isLocal }
        let remoteStores: [(Int, Storing<E>)] = stores.enumerated().filter { $1.level == .remote }

        return await withTaskGroup(of: Void.self, returning: Result<Output, StoreError>?.self) { group in
            group.addTask {
                await withTaskGroup(of: Void.self) { localGroup in
                    for (index, store) in localStores {
                        localGroup.addTask {
                            await handleStore(store: store, at: index)
                        }
                    }

                    await localGroup.waitForAll()

                    do {
                        let results = try await localStores.asyncCompactMap { (index, store) -> Result<Output, StoreError>?? in
                            await results.get(at: index)
                        }
                        guard results.isEmpty == false else { return }
                        localStoresCompletion(self.collectResult(from: results))
                    } catch {
                        Logger.log(.error, "\(StoreStack.self) found error collecting results")
                        localStoresCompletion(.failure(.notSupported))
                    }
                }
            }

            group.addTask {
                await withTaskGroup(of: Void.self) { remoteGroup in
                    for (index, store) in remoteStores {
                        remoteGroup.addTask {
                            await handleStore(store: store, at: index)
                        }
                    }
                }
            }

            await group.waitForAll()

            let results = await self.stores.enumerated().asyncMap { (index, _) in await results.get(at: index) }
            return self.collectResult(from: results)
        }
    }

    private func collectResult<Output>(from results: [Result<Output, StoreError>?]) -> Result<Output, StoreError>? {

        let error: StoreError? = results.reduce(nil) {
            switch $1 {
            case .some(.failure(let error)):
                return error.compose(with: $0)
            case .some,
                 .none:
                return $0
            }
        }

        if let _error = error {
            return .failure(_error)
        } else {
            let newValue: Output? = results.compactMap {
                switch $0 {
                case .some(.success(let value)):
                    return value
                case .some,
                     .none:
                    return nil
                }
            }.first

            if let _newValue = newValue {
                return .success(_newValue)
            } else {
                return nil
            }
        }
    }
}

private extension StoreError {
    func compose(with previous: StoreError?) -> StoreError {
        if let previous = previous {
            return .composite(current: self, previous: previous)
        } else {
            return self
        }
    }
}

struct StoreStackQueues<E> {
    let readWriteQueue = DispatchQueue(label: "\(StoreStackQueues<E>.self)_read_write_queue", attributes: .concurrent)
    let writeResultsQueue = DispatchQueue(label: "\(StoreStackQueues<E>.self)_write_results_queue")
    let contractQueue = DispatchQueue(label: "\(StoreStackQueues<E>.self)_contract_queue")

    let readWriteAsyncQueue = AsyncTaskQueue()
    let writeResultsAsyncQueue = AsyncTaskQueue()
    let contractAsyncQueue = AsyncTaskQueue()
}
