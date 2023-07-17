//
//  CacheStore.swift
//  Lucid
//
//  Created by Théophane Rupin on 12/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

public final class CacheStore<E>: StoringConvertible where E: LocalEntity {

    private let keyValueStore: Storing<E>

    private let persistentStore: Storing<E>

    public let level: StoreLevel

    private let operationQueue = AsyncOperationQueue()

    private let asyncTaskQueue = AsyncTaskQueue()

    // MARK: - Inits

    public init(keyValueStore: Storing<E>, persistentStore: Storing<E>) {
        if keyValueStore.level != .memory {
            Logger.log(.error, "\(CacheStore<E>.self) keyValueStore must be a memory store", assert: true)
        }

        if persistentStore.level != .disk {
            Logger.log(.error, "\(CacheStore<E>.self) persistentStore must be a disk store", assert: true)
        }

        self.keyValueStore = keyValueStore
        self.persistentStore = persistentStore
        self.level = persistentStore.level
    }

    // MARK: - API

    public func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        keyValueStore.get(withQuery: query, in: context) { result in
            switch result {
            case .success(let queryResult) where queryResult.entity != nil:
                completion(.success(queryResult))
            case .success,
                 .failure:
                if let error = result.error {
                    Logger.log(.error, "\(CacheStore<E>.self): Could not get entity: \(query) from cache store: \(error)", assert: true)
                }

                self.operationQueue.run(title: "\(CacheStore<E>.self):get") { operationCompletion in

                    self.persistentStore.get(withQuery: query, in: context) { result in
                        switch result {
                        case .success(let queryResult):
                            if let entity = queryResult.entity {
                                self.keyValueStore.set(entity, in: WriteContext(dataTarget: .local)) { keyValueResult in
                                    if keyValueResult == nil {
                                        Logger.log(.error, "\(CacheStore<E>.self): Could not set entity: \(query) in cache store. Unexpectedly received nil.", assert: true)
                                    } else if let error = keyValueResult?.error {
                                        Logger.log(.error, "\(CacheStore<E>.self): Could not set entity: \(query) in cache store: \(error)", assert: true)
                                    }
                                    completion(.success(queryResult))
                                    operationCompletion()
                                }
                            } else {
                                completion(.success(.empty()))
                                operationCompletion()
                            }
                        case .failure(let error):
                            completion(.failure(error))
                            operationCompletion()
                        }
                    }
                }
            }
        }
    }

    public func get(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        let result = await keyValueStore.get(withQuery: query, in: context)

        switch result {
        case .success(let queryResult) where queryResult.entity != nil:
            return .success(queryResult)
        case .success, .failure:
            if let error = result.error {
                Logger.log(.error, "\(CacheStore<E>.self): Could not get entity: \(query) from cache store: \(error)", assert: true)
            }

            do {
                return try await self.asyncTaskQueue.enqueue { operationCompletion in
                    defer { operationCompletion() }

                    let getResult = await self.persistentStore.get(withQuery: query, in: context)
                    switch getResult {
                    case .success(let queryResult):
                        if let entity = queryResult.entity {
                            let setResult = await self.keyValueStore.set(entity, in: WriteContext(dataTarget: .local))

                            if setResult == nil {
                                Logger.log(.error, "\(CacheStore<E>.self): Could not set entity: \(query) in cache store. Unexpectedly received nil.", assert: true)
                            } else if let error = setResult?.error {
                                Logger.log(.error, "\(CacheStore<E>.self): Could not set entity: \(query) in cache store: \(error)", assert: true)
                            }
                            return .success(queryResult)
                        } else {
                            return .success(.empty())
                        }
                    case .failure(let error):
                        return .failure(error)
                    }
                }
            } catch {
                return .failure(.notSupported)
            }
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        guard let identifiers = query.identifiers?.array,
            query.order.contains(where: { $0.isDeterministic == false }) == false,
            query.offset == nil,
            query.limit == nil else {

                operationQueue.run(title: "\(CacheStore<E>.self):search:1") { operationCompletion in
                    self.persistentStore.search(withQuery: query, in: context) {
                        completion($0)
                        operationCompletion()
                    }
                }
                return
        }

        keyValueStore.search(withQuery: query, in: context) { result in
            switch result {
            case .success(var keyValueStoreEntities):

                if keyValueStoreEntities.materialize().count != identifiers.count {
                    self.operationQueue.run(title: "\(CacheStore<E>.self):search:2") { operationCompletion in
                        self.persistentStore.search(withQuery: query, in: context) { result in
                            switch result {
                            case .success(var successfulEntities):
                                self.keyValueStore.set(successfulEntities.materialize(), in: WriteContext(dataTarget: .local)) { setResult in
                                    if setResult == nil {
                                        Logger.log(.error, "\(CacheStore<E>.self): Could not set entity: \(successfulEntities.array) in cache store. Unexpectedly received nil.", assert: true)
                                    } else if let error = setResult?.error {
                                        Logger.log(.error, "\(CacheStore<E>.self): Could not set entity: \(successfulEntities.array) in cache store: \(error)", assert: true)
                                    } else {
                                        Logger.log(.verbose, "\(CacheStore<E>.self): Cached \(successfulEntities.count) entities.")
                                    }
                                    completion(result)
                                    operationCompletion()
                                }
                            case .failure(let error):
                                completion(.failure(error))
                                operationCompletion()
                            }
                        }
                    }
                } else {
                    completion(result)
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        guard let identifiers = query.identifiers?.array,
              query.order.contains(where: { $0.isDeterministic == false }) == false,
              query.offset == nil,
              query.limit == nil else {

            do {
                return try await asyncTaskQueue.enqueue { operationCompletion in
                    defer { operationCompletion() }
                    return await self.persistentStore.search(withQuery: query, in: context)
                }
            } catch {
                return .failure(.notSupported)
            }
        }

        let result = await keyValueStore.search(withQuery: query, in: context)

        switch result {
        case .success(var keyValueStoreEntities):

            if keyValueStoreEntities.materialize().count != identifiers.count {
                do {
                    return try await asyncTaskQueue.enqueue { operationCompletion in
                        defer { operationCompletion() }
                        let searchResult = await self.persistentStore.search(withQuery: query, in: context)

                        switch searchResult {
                        case .success(var successfulEntities):
                            let setResult = await self.keyValueStore.set(successfulEntities.materialize(), in: WriteContext(dataTarget: .local))
                            if setResult == nil {
                                Logger.log(.error, "\(CacheStore<E>.self): Could not set entity: \(successfulEntities.array) in cache store. Unexpectedly received nil.", assert: true)
                            } else if let error = setResult?.error {
                                Logger.log(.error, "\(CacheStore<E>.self): Could not set entity: \(successfulEntities.array) in cache store: \(error)", assert: true)
                            } else {
                                Logger.log(.verbose, "\(CacheStore<E>.self): Cached \(successfulEntities.count) entities.")
                            }
                            return searchResult
                        case .failure(let error):
                            return .failure(error)
                        }
                    }
                } catch {
                    return .failure(.notSupported)
                }
            } else {
                return result
            }

        case .failure(let error):
            return .failure(error)
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {

        operationQueue.run(title: "\(CacheStore<E>.self):set") { operationCompletion in

            let entitiesToSave = DualHashDictionary(entities.map { ($0.identifier, $0) })

            self.keyValueStore.search(withQuery: .filter(.identifier >> entitiesToSave.keys), in: ReadContext<E>()) { result in
                switch result {
                case .success(var result) where result.materialize().count > 0:

                    let cachedEntities = DualHashDictionary(result.map { ($0.identifier, $0) })
                    let initialEntitiesToSaveCount = entitiesToSave.count
                    let entitiesToSave = entitiesToSave.values.filter { entity in
                        guard let cachedEntity = cachedEntities[entity.identifier] else { return true }
                        switch context.remoteSyncState {
                        case .some(.mergeIdentifier):
                            return true
                        case .some(.createResponse),
                             .none:
                            return entity.shouldOverwrite(with: cachedEntity)
                        }
                    }

                    Logger.log(.verbose, "\(CacheStore<E>.self): Writing \(entitiesToSave.count) out of \(initialEntitiesToSaveCount) entities to disk.")

                    self._set(entitiesToSave, in: context) { result in
                        switch result {
                        case .some(.success):
                            completion(.success(entities.any))
                        case .some(.failure(let error)):
                            completion(.failure(error))
                        case .none:
                            completion(nil)
                        }
                        operationCompletion()
                    }

                case .failure,
                     .success:
                    Logger.log(.verbose, "\(CacheStore<E>.self): Writing \(entitiesToSave.count) entities to disk.")
                    self._set(entitiesToSave.values, in: context) {
                        completion($0)
                        operationCompletion()
                    }
                }
            }
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>) async -> Result<AnySequence<E>, StoreError>? where S : Sequence, E == S.Element {
        do {
            return try await asyncTaskQueue.enqueue { operationCompletion in
                defer { operationCompletion() }

                let entitiesToSave = DualHashDictionary(entities.map { ($0.identifier, $0) })
                let searchResult = await self.keyValueStore.search(withQuery: .filter(.identifier >> entitiesToSave.keys), in: ReadContext<E>())

                switch searchResult {
                case .success(var result) where result.materialize().count > 0:
                    let cachedEntities = DualHashDictionary(result.map { ($0.identifier, $0) })
                    let initialEntitiesToSaveCount = entitiesToSave.count
                    let entitiesToSave = entitiesToSave.values.filter { entity in
                        guard let cachedEntity = cachedEntities[entity.identifier] else { return true }
                        switch context.remoteSyncState {
                        case .some(.mergeIdentifier):
                            return true
                        case .some(.createResponse),
                             .none:
                            return entity.shouldOverwrite(with: cachedEntity)
                        }
                    }

                    Logger.log(.verbose, "\(CacheStore<E>.self): Writing \(entitiesToSave.count) out of \(initialEntitiesToSaveCount) entities to disk.")

                    let setResult = await self._set(entitiesToSave, in: context)
                    switch setResult {
                    case .some(.success):
                        return .success(entities.any)
                    case .some(.failure(let error)):
                        return .failure(error)
                    case .none:
                        return nil
                    }
                case .failure, .success:
                    Logger.log(.verbose, "\(CacheStore<E>.self): Writing \(entitiesToSave.count) entities to disk.")
                    let setResult = await self._set(entitiesToSave.values, in: context)
                    return setResult
                }
            }
        } catch {
            return .failure(.notSupported)
        }
    }

    private func _set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {
        guard entities.any.isEmpty == false else {
            completion(.success(entities.any))
            return
        }

        keyValueStore.set(entities, in: context) { result in
            switch result {
            case .some(.success(let entities)):
                self.persistentStore.set(entities, in: context) { result in
                    if result == nil {
                        Logger.log(.error, "\(CacheStore<E>.self): Could not set entities: \(entities.map { $0.identifier }) in persistent store. Unexpectedly received nil.", assert: true)
                    } else if let error = result?.error {
                        Logger.log(.error, "\(CacheStore<E>.self): Could not set entities: \(entities.map { $0.identifier }) in persistent store: \(error)", assert: true)
                    }
                    completion(.success(entities))
                }

            case .some(.failure(let error)):
                Logger.log(.error, "\(CacheStore<E>.self): Could not set entities: \(entities.map { $0.identifier }) in cache store: \(error)", assert: true)
                self.persistentStore.set(entities, in: context, completion: completion)
            case .none:
                Logger.log(.error, "\(CacheStore<E>.self): Could not set entities: \(entities.map { $0.identifier }) in cache store. Unexpectedly received nil.", assert: true)
                self.persistentStore.set(entities, in: context, completion: completion)
            }
        }
    }

    private func _set<S>(_ entities: S, in context: WriteContext<E>) async -> Result<AnySequence<E>, StoreError>? where S: Sequence, S.Element == E {
        guard entities.any.isEmpty == false else {
            return .success(entities.any)
        }

        let result = await self.keyValueStore.set(entities, in: context)
        switch result {
        case .some(.success(let entities)):
            let setResult = await self.persistentStore.set(entities, in: context)
            if setResult == nil {
                Logger.log(.error, "\(CacheStore<E>.self): Could not set entities: \(entities.map { $0.identifier }) in persistent store. Unexpectedly received nil.", assert: true)
            } else if let error = setResult?.error {
                Logger.log(.error, "\(CacheStore<E>.self): Could not set entities: \(entities.map { $0.identifier }) in persistent store: \(error)", assert: true)
            }
            return .success(entities)

        case .some(.failure(let error)):
            Logger.log(.error, "\(CacheStore<E>.self): Could not set entities: \(entities.map { $0.identifier }) in cache store: \(error)", assert: true)
            return await self.persistentStore.set(entities, in: context)
        case .none:
            Logger.log(.error, "\(CacheStore<E>.self): Could not set entities: \(entities.map { $0.identifier }) in cache store. Unexpectedly received nil.", assert: true)
            return await self.persistentStore.set(entities, in: context)
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {

        operationQueue.run(title: "\(CacheStore<E>.self):remove_all") { operationCompletion in
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            dispatchGroup.enter()

            self.keyValueStore.removeAll(withQuery: query, in: context) { result in
                if result == nil {
                    Logger.log(.error, "\(CacheStore<E>.self): Could not remove entities matching query: \(query) from cache store. Unexpectedly received nil.", assert: true)
                } else if let error = result?.error {
                    Logger.log(.error, "\(CacheStore<E>.self): Could not remove entities matching query: \(query) from cache store: \(error)", assert: true)
                }
                dispatchGroup.leave()
            }

            var _result: Result<AnySequence<E.Identifier>, StoreError>?
            self.persistentStore.removeAll(withQuery: query, in: context) { result in
                _result = result
                dispatchGroup.leave()
            }

            dispatchGroup.notify(queue: .global()) {
                defer { operationCompletion() }
                guard let result = _result else {
                    Logger.log(.error, "\(CacheStore<E>.self): Should never happen. If it does, fix asap.", assert: true)
                    completion(.failure(.notSupported))
                    return
                }
                completion(result)
            }
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>) async -> Result<AnySequence<E.Identifier>, StoreError>? {
        do {
            return try await asyncTaskQueue.enqueue { operationCompletion in
                defer { operationCompletion() }

                return await withTaskGroup(of: Result<AnySequence<E.Identifier>, StoreError>?.self) { group in
                    group.addTask {
                        let result = await self.keyValueStore.removeAll(withQuery: query, in: context)
                        if result == nil {
                            Logger.log(.error, "\(CacheStore<E>.self): Could not remove entities matching query: \(query) from cache store. Unexpectedly received nil.", assert: true)
                        } else if let error = result?.error {
                            Logger.log(.error, "\(CacheStore<E>.self): Could not remove entities matching query: \(query) from cache store: \(error)", assert: true)
                        }
                        return nil
                    }

                    group.addTask {
                        let result = await self.persistentStore.removeAll(withQuery: query, in: context)
                        return result
                    }

                    guard let result = await group.first(where: { $0 != nil }) else {
                        Logger.log(.error, "\(CacheStore<E>.self): Should never happen. If it does, fix asap.", assert: true)
                        return .failure(.notSupported)
                    }

                    return result
                }
            }
        } catch {
            return .failure(.notSupported)
        }
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {

        operationQueue.run(title: "\(CacheStore<E>.self):bulk_remove") { operationCompletion in
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            dispatchGroup.enter()

            self.keyValueStore.remove(identifiers, in: context) { result in
                if result == nil {
                    Logger.log(.error, "\(CacheStore<E>.self): Could not remove entity: \(identifiers) from cache store. Unexpectedly received nil.", assert: true)
                } else if let error = result?.error {
                    Logger.log(.error, "\(CacheStore<E>.self): Could not remove entity: \(identifiers) from cache store: \(error)", assert: true)
                }
                dispatchGroup.leave()
            }

            var _result: Result<Void, StoreError>?
            self.persistentStore.remove(identifiers, in: context) { result in
                _result = result
                dispatchGroup.leave()
            }

            dispatchGroup.notify(queue: .global()) {
                defer { operationCompletion() }
                guard let result = _result else {
                    Logger.log(.error, "\(CacheStore<E>.self): Should never happen. If it does, fix asap.", assert: true)
                    completion(.failure(.notSupported))
                    return
                }
                completion(result)
            }
        }
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>) async -> Result<Void, StoreError>? where S : Sequence, S.Element == E.Identifier {
        do {
            return try await asyncTaskQueue.enqueue { operationCompletion in
                defer { operationCompletion() }

                return await withTaskGroup(of: Result<Void, StoreError>?.self) { group in
                    group.addTask {
                        let result = await self.keyValueStore.remove(identifiers, in: context)
                        if result == nil {
                            Logger.log(.error, "\(CacheStore<E>.self): Could not remove entity: \(identifiers) from cache store. Unexpectedly received nil.", assert: true)
                        } else if let error = result?.error {
                            Logger.log(.error, "\(CacheStore<E>.self): Could not remove entity: \(identifiers) from cache store: \(error)", assert: true)
                        }
                        return nil
                    }

                    group.addTask {
                        let result = await self.persistentStore.remove(identifiers, in: context)
                        return result
                    }

                    guard let result = await group.first(where: { $0 != nil }) else {
                        Logger.log(.error, "\(CacheStore<E>.self): Should never happen. If it does, fix asap.", assert: true)
                        return .failure(.notSupported)
                    }

                    return result
                }
            }
        } catch {
            return .failure(.notSupported)
        }
    }
}
