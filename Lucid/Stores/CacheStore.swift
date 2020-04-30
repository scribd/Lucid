//
//  CacheStore.swift
//  Lucid
//
//  Created by Théophane Rupin on 12/13/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

public final class CacheStore<E: Entity>: StoringConvertible {
    
    private let keyValueStore: Storing<E>
    
    private let persistentStore: Storing<E>
    
    public let level: StoreLevel
    
    private let operationQueue = AsyncOperationQueue()
    
    // MARK: - Inits

    public init(keyValueStore: Storing<E>, persistentStore: Storing<E>) {
        if keyValueStore.level != .memory {
            Logger.log(.error, "\(CacheStore.self) keyValueStore must be a memory store", assert: true)
        }

        if persistentStore.level != .disk {
            Logger.log(.error, "\(CacheStore.self) persistentStore must be a disk store", assert: true)
        }
        
        self.keyValueStore = keyValueStore
        self.persistentStore = persistentStore
        self.level = persistentStore.level
    }
    
    // MARK: - API
    
    public func get(byID identifier: E.Identifier, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        keyValueStore.get(byID: identifier, in: context) { result in
            switch result {
            case .success(let queryResult) where queryResult.entity != nil:
                completion(.success(queryResult))
            case .success,
                 .failure:
                if let error = result.error {
                    Logger.log(.error, "\(CacheStore.self): Could not get entity: \(identifier) from cache store: \(error)", assert: true)
                }
                
                self.operationQueue.run(title: "\(CacheStore.self):get") { operationCompletion in
                    
                    self.persistentStore.get(byID: identifier, in: context) { result in
                        switch result {
                        case .success(let queryResult):
                            if let entity = queryResult.entity {
                                self.keyValueStore.set(entity, in: WriteContext(dataTarget: .local)) { keyValueResult in
                                    if keyValueResult == nil {
                                        Logger.log(.error, "\(CacheStore.self): Could not set entity: \(identifier) in cache store. Unexpectedly received nil.", assert: true)
                                    } else if let error = keyValueResult?.error {
                                        Logger.log(.error, "\(CacheStore.self): Could not set entity: \(identifier) in cache store: \(error)", assert: true)
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

    public func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        guard let identifiers = query.filter?.extractOrIdentifiers?.array, query.order.contains(where: { $0.isDeterministic == false }) == false else {
            operationQueue.run(title: "\(CacheStore.self):search:1") { operationCompletion in
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
                    self.operationQueue.run(title: "\(CacheStore.self):search:2") { operationCompletion in
                        self.persistentStore.search(withQuery: query, in: context) { result in
                            switch result {
                            case .success(var successfulEntities):
                                self.keyValueStore.set(successfulEntities.materialize(), in: WriteContext(dataTarget: .local)) { setResult in
                                    if setResult == nil {
                                        Logger.log(.error, "\(CacheStore.self): Could not set entity: \(successfulEntities.array) in cache store. Unexpectedly received nil.", assert: true)
                                    } else if let error = setResult?.error {
                                        Logger.log(.error, "\(CacheStore.self): Could not set entity: \(successfulEntities.array) in cache store: \(error)", assert: true)
                                    } else {
                                        Logger.log(.verbose, "\(CacheStore.self): Cached \(successfulEntities.count) entities.")
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

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {

        operationQueue.run(title: "\(CacheStore.self):set") { operationCompletion in

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
                            return cachedEntity != entity
                        }
                    }
                    
                    Logger.log(.verbose, "\(CacheStore.self): Writing \(entitiesToSave.count) out of \(initialEntitiesToSaveCount) entities to disk.")
                    
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
                    Logger.log(.verbose, "\(CacheStore.self): Writing \(entitiesToSave.count) entities to disk.")
                    self._set(entitiesToSave.values, in: context) {
                        completion($0)
                        operationCompletion()
                    }
                }
            }
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
                        Logger.log(.error, "\(CacheStore.self): Could not set entities: \(entities.map { $0.identifier }) in persistent store. Unexpectedly received nil.", assert: true)
                    } else if let error = result?.error {
                        Logger.log(.error, "\(CacheStore.self): Could not set entities: \(entities.map { $0.identifier }) in persistent store: \(error)", assert: true)
                    }
                    completion(.success(entities))
                }

            case .some(.failure(let error)):
                Logger.log(.error, "\(CacheStore.self): Could not set entities: \(entities.map { $0.identifier }) in cache store: \(error)", assert: true)
                self.persistentStore.set(entities, in: context, completion: completion)
            case .none:
                Logger.log(.error, "\(CacheStore.self): Could not set entities: \(entities.map { $0.identifier }) in cache store. Unexpectedly received nil.", assert: true)
                self.persistentStore.set(entities, in: context, completion: completion)
            }
        }
    }
    
    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {
        
        operationQueue.run(title: "\(CacheStore.self):remove_all") { operationCompletion in
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            dispatchGroup.enter()

            self.keyValueStore.removeAll(withQuery: query, in: context) { result in
                if result == nil {
                    Logger.log(.error, "\(CacheStore.self): Could not remove entities matching query: \(query) from cache store. Unexpectedly received nil.", assert: true)
                } else if let error = result?.error {
                    Logger.log(.error, "\(CacheStore.self): Could not remove entities matching query: \(query) from cache store: \(error)", assert: true)
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
                    Logger.log(.error, "\(CacheStore.self): Should never happen. If it does, fix asap.", assert: true)
                    completion(.failure(.notSupported))
                    return
                }
                completion(result)
            }
        }
    }
    
    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {

        operationQueue.run(title: "\(CacheStore.self):bulk_remove") { operationCompletion in
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            dispatchGroup.enter()

            self.keyValueStore.remove(identifiers, in: context) { result in
                if result == nil {
                    Logger.log(.error, "\(CacheStore.self): Could not remove entity: \(identifiers) from cache store. Unexpectedly received nil.", assert: true)
                } else if let error = result?.error {
                    Logger.log(.error, "\(CacheStore.self): Could not remove entity: \(identifiers) from cache store: \(error)", assert: true)
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
                    Logger.log(.error, "\(CacheStore.self): Should never happen. If it does, fix asap.", assert: true)
                    completion(.failure(.notSupported))
                    return
                }
                completion(result)
            }
        }
    }
}
