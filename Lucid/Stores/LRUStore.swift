//
//  LRUStore.swift
//  Lucid
//
//  Created by Théophane Rupin on 12/12/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

// MARK: - LinkedList

private final class LinkedListElement<T> {
    let value: T?
    var next: LinkedListElement?
    var prev: LinkedListElement?

    init(value: T? = nil,
         next: LinkedListElement? = nil,
         prev: LinkedListElement? = nil) {
        self.value = value
        self.next = next ?? self
        self.prev = prev ?? self
    }
}

// MARK: - Store

public final class LRUStore<E>: StoringConvertible where E: LocalEntity {

    private let store: Storing<E>

    private let limit: Int

    private var _elementsByID = DualHashDictionary<E.Identifier, LinkedListElement<E.Identifier>>()
    private var _identifiersListSentinel = LinkedListElement<E.Identifier>()

    private let identifiersDispatchQueue = DispatchQueue(label: "\(LRUStore<E>.self):identifiers_dispatch_queue", attributes: .concurrent)
    private let identifiersAsyncQueue = AsyncTaskQueue()

    public let level: StoreLevel

    public init(store: Storing<E>, limit: Int = 100) {
        self.store = store
        self.limit = limit
        level = store.level
        _ = identifiersDispatchQueue // For thread-safety
    }

    public func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        store.get(withQuery: query, in: context) { result in
            switch result {
            case .success(let queryResult):
                guard let successfulEntity = queryResult.entity else {
                    completion(result)
                    return
                }

                self.identifiersDispatchQueue.async(flags: .barrier) {
                    _ = self._push([successfulEntity.identifier].any)
                    completion(result)
                }
            case .failure:
                completion(result)
            }
        }
    }

    public func get(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        let result = await store.get(withQuery: query, in: context)

        switch result {
        case .success(let queryResult):
            guard let successfulEntity = queryResult.entity else {
                return result
            }

            do {
                return try await identifiersAsyncQueue.enqueueBarrier { operationCompletion in
                    defer { operationCompletion() }

                    _ = self._push([successfulEntity.identifier].any)
                    return result
                }
            } catch {
                return .failure(.notSupported)
            }
        case .failure:
            return result
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        store.search(withQuery: query, in: context) { result in
            switch result {
            case .success(let successfulEntities):
                guard successfulEntities.isEmpty == false else {
                    completion(result)
                    return
                }

                self.identifiersDispatchQueue.async(flags: .barrier) {
                    self._push(successfulEntities.lazy.map { $0.identifier })
                    completion(result)
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        let result = await store.search(withQuery: query, in: context)
        switch result {
        case .success(let successfulEntities):
            guard successfulEntities.isEmpty == false else {
                return result
            }

            do {
                return try await identifiersAsyncQueue.enqueueBarrier { operationCompletion in
                    defer { operationCompletion() }

                    self._push(successfulEntities.lazy.map { $0.identifier })
                    return result
                }
            } catch {
                return .failure(.notSupported)
            }

        case .failure(let error):
            return .failure(error)
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {
        store.set(entities, in: context) { result in
            switch result {
            case .some(.success(let successfulEntities)):
                self.identifiersDispatchQueue.async(flags: .barrier) {
                    let identifiersToRemove = self._push(successfulEntities.lazy.map { $0.identifier })
                    self._remove(identifiersToRemove.any, in: context) {
                        completion(result)
                    }
                }
            case .some(.failure(let error)):
                completion(.failure(error))
            case .none:
                completion(.failure(.notSupported))
            }
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>) async -> Result<AnySequence<E>, StoreError>? where S : Sequence, E == S.Element {
        let result = await store.set(entities, in: context)

        switch result {
        case .some(.success(let successfulEntities)):
            do {
                return try await identifiersAsyncQueue.enqueueBarrier { operationCompletion in
                    defer { operationCompletion() }
                    let identifiersToRemove = self._push(successfulEntities.lazy.map { $0.identifier })
                    await self._remove(identifiersToRemove.any, in: context)
                    return result
                }
            } catch {
                return .failure(.notSupported)
            }
        case .some(.failure(let error)):
            return .failure(error)
        case .none:
            return .failure(.notSupported)
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {
        store.search(withQuery: query, in: ReadContext<E>()) { result in
            switch result {
            case .success(let queryResult):
                let identifiers = queryResult.lazy.map { $0.identifier }
                self.remove(identifiers, in: context) { result in
                    switch result {
                    case .some(.success):
                        completion(.success(identifiers.any))
                    case .some(.failure(let error)):
                        completion(.failure(error))
                    case .none:
                        completion(.failure(.notSupported))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>) async -> Result<AnySequence<E.Identifier>, StoreError>? {
        let result = await store.search(withQuery: query, in: ReadContext<E>())
        switch result {
        case .success(let queryResult):
            let identifiers = queryResult.lazy.map { $0.identifier }
            let removeResult = await self.remove(identifiers, in: context)

            switch removeResult {
            case .some(.success):
                return .success(identifiers.any)
            case .some(.failure(let error)):
                return .failure(error)
            case .none:
                return .failure(.notSupported)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {
        identifiersDispatchQueue.async(flags: .barrier) {
            let removedIdentifiers = self._remove(identifiers)
            guard !removedIdentifiers.isEmpty else {
                completion(.success(()))
                return
            }
            self.store.remove(removedIdentifiers.any, in: context, completion: completion)
        }
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>) async -> Result<Void, StoreError>? where S : Sequence, S.Element == E.Identifier {
        do {
            return try await identifiersAsyncQueue.enqueueBarrier { operationCompletion in
                defer { operationCompletion() }

                let removedIdentifiers = self._remove(identifiers)
                guard !removedIdentifiers.isEmpty else {
                    return .success(())
                }
                return await self.store.remove(removedIdentifiers.any, in: context)
            }
        } catch {
            return .failure(.notSupported)
        }
    }
}

// MARK: - Utils

private extension LRUStore {

    @discardableResult
    func _remove<S>(_ identifiers: S) -> [E.Identifier] where S: Sequence, S.Element == E.Identifier {
        return identifiers.compactMap { _remove($0) ? $0 : nil }
    }

    @discardableResult
    func _remove(_ identifier: E.Identifier) -> Bool {
        guard let elementInList = _elementsByID[identifier] else {
            return false
        }
        _elementsByID[identifier] = nil
        elementInList.prev?.next = elementInList.next
        elementInList.next?.prev = elementInList.prev
        return true
    }

    @discardableResult
    func _push<S>(_ identifiers: S) -> [E.Identifier] where S: Sequence, S.Element == E.Identifier {
        var identifiersToRemove = [E.Identifier]()

        for identifier in identifiers {
            _remove(identifier)

            let element = LinkedListElement(value: identifier,
                                            next: _identifiersListSentinel.next,
                                            prev: _identifiersListSentinel)
            _identifiersListSentinel.next?.prev = element
            _identifiersListSentinel.next = element
            _elementsByID[identifier] = element

            if _elementsByID.count > limit, let oldestIdentifier = _identifiersListSentinel.prev?.value {
                _remove(oldestIdentifier)
                identifiersToRemove.append(oldestIdentifier)
            }
        }

        if identifiersToRemove.isEmpty == false {
            Logger.log(.verbose, "\(LRUStore<E>.self): Dropping \(identifiersToRemove.count) elements as the \(limit) limit was reached.")
        }
        Logger.log(.verbose, "\(LRUStore<E>.self): Entities count: \(_elementsByID.count) / \(limit)")

        return identifiersToRemove
    }

    func _remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping () -> Void) where S: Sequence, S.Element == E.Identifier {
        guard !identifiers.any.isEmpty else {
            completion()
            return
        }

        store.remove(identifiers, in: context) { result in
            if result == nil {
                Logger.log(.error, "\(LRUStore<E>.self): Could not delete entity: \(identifiers) because of error. Unexpectedly received nil.", assert: true)
            } else if let error = result?.error {
                Logger.log(.error, "\(LRUStore<E>.self): Could not delete entity: \(identifiers) because of error: \(error).", assert: true)
            }
            completion()
        }
    }

    func _remove<S>(_ identifiers: S, in context: WriteContext<E>) async where S: Sequence, S.Element == E.Identifier {
        guard !identifiers.any.isEmpty else {
            return
        }

        let result = await store.remove(identifiers, in: context)
        if result == nil {
            Logger.log(.error, "\(LRUStore<E>.self): Could not delete entity: \(identifiers) because of error. Unexpectedly received nil.", assert: true)
        } else if let error = result?.error {
            Logger.log(.error, "\(LRUStore<E>.self): Could not delete entity: \(identifiers) because of error: \(error).", assert: true)
        }
    }
}
