//
//  FakeStore.swift
//  LucidTests
//
//  Created by Ibrahim Sha'ath on 2/5/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Lucid

public final class FakeStoreCounter {

    public internal(set) static var count: Int = 0
}

/**
 * This is just a simplified version of the InMemoryStore, altered to allow a fake StoreLevel.
 */
public final class FakeStore<E>: StoringConvertible where E: LocalEntity, E: RemoteEntity, E.Identifier.RemoteValueType == Int, E.Identifier.LocalValueType == String {

    private actor FakeStoreCache {
        var value = [FakeStoreKey: E]()

        func set(value: E?, forKey key: FakeStoreKey) {
            self.value[key] = value
        }
    }

    private let _cache: FakeStoreCache = FakeStoreCache()

    public let level: StoreLevel

    deinit {
        FakeStoreCounter.count -= 1
    }

    public init(level: StoreLevel) {
        self.level = level
        FakeStoreCounter.count += 1
    }

    public func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        if let identifierValue = query.identifier?.identifierValue {
            Task {
                let cacheValue = await self._cache.value[identifierValue]
                completion(.success(QueryResult(from: cacheValue)))
            }
        } else {
            completion(.failure(.identifierNotFound))
        }
    }

    public func get(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        if let identifierValue = query.identifier?.identifierValue {
            let cacheValue = await self._cache.value[identifierValue]
            return .success(QueryResult(from: cacheValue))
        } else {
            return .failure(.identifierNotFound)
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        Task {
            completion(.success(await self._collectEntities(for: query)))
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        return .success(await self._collectEntities(for: query))
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {
        Task {
            var mergedEntities: [E] = []
            for entity in entities {
                var mergedEntity = entity
                let identifierValue = entity.identifier.identifierValue

                if let existingEntity = await self._cache.value[identifierValue] {
                    mergedEntity = existingEntity.merging(entity)
                }
                await self._cache.set(value: mergedEntity, forKey: identifierValue)
                mergedEntities.append(mergedEntity)
            }
            completion(.success(mergedEntities.any))
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>) async -> Result<AnySequence<E>, StoreError>? where S: Sequence, S.Element == E {
        var mergedEntities: [E] = []
        for entity in entities {
            var mergedEntity = entity
            let identifierValue = entity.identifier.identifierValue
            if let existingEntity = await self._cache.value[identifierValue] {
                mergedEntity = existingEntity.merging(entity)
            }
            await self._cache.set(value: mergedEntity, forKey: identifierValue)
            mergedEntities.append(mergedEntity)
        }
        return .success(mergedEntities.any)
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {
        Task {
            let results = await self._collectEntities(for: query)
            let identifiers = results.any.lazy.map { $0.identifier }
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
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>) async -> Result<AnySequence<E.Identifier>, StoreError>? {
        let results = await self._collectEntities(for: query)
        let identifiers = results.any.lazy.map { $0.identifier }
        let result = await self.remove(identifiers, in: context)
        switch result {
        case .some(.success):
            return .success(identifiers.any)
        case .some(.failure(let error)):
            return .failure(error)
        case .none:
            return .failure(.notSupported)
        }
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {
        Task {
            for identifier in identifiers {
                await self._cache.set(value: nil, forKey: identifier.identifierValue)
            }
            completion(.success(()))
        }
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>) async -> Result<Void, StoreError>? where S : Sequence, S.Element == E.Identifier {
        await identifiers.asyncForEach { identifier in
            await self._cache.set(value: nil, forKey: identifier.identifierValue)
        }
        return .success(())
    }
}

// MARK: - Collect

private extension FakeStore {

    func _collectEntities(for query: Query<E>) async -> QueryResult<E> {
        var dualHashCache = DualHashDictionary<E.Identifier, E>()
        for (fakeStoreKey, entity) in await _cache.value {
            if E.self == EntitySpy.self,
               let entitySpyIdentifier = EntitySpyIdentifier(fakeStoreKey: fakeStoreKey) as? E.Identifier {
                dualHashCache[entitySpyIdentifier] = entity
            } else if E.self == EntityRelationshipSpy.self,
                      let entityRelationshipSpyIdentifier = EntityRelationshipSpyIdentifier(fakeStoreKey: fakeStoreKey) as? E.Identifier {
                dualHashCache[entityRelationshipSpyIdentifier] = entity
            }

        }
        guard let filter = query.filter else {
            return QueryResult(from: dualHashCache, for: query).materialized
        }
        return QueryResult(from: dualHashCache.filter(with: filter),
                           for: query,
                           entitiesByID: dualHashCache).materialized
    }
}

private extension RemoteIdentifier where RemoteValueType == Int, LocalValueType == String {

    var identifierValue: FakeStoreKey {
        switch value {
        case .remote(let remoteValue, let localValue):
            if let localValue {
                return .remoteAndLocal(remoteValue, localValue)
            } else {
                return .remote(remoteValue)
            }
        case .local(let localValue):
            return .local(localValue)
        }
    }
}

// MARK: - Helpers

private enum FakeStoreKey: Hashable {
    case remoteAndLocal(Int, String)
    case remote(Int)
    case local(String)
}

private extension EntitySpyIdentifier {

    convenience init(fakeStoreKey: FakeStoreKey) {
        switch fakeStoreKey {
        case .remoteAndLocal(let remoteValue, let localValue):
            self.init(value: .remote(remoteValue, localValue))
        case .remote(let remoteValue):
            self.init(value: .remote(remoteValue, nil))
        case .local(let localValue):
            self.init(value: .local(localValue))
        }
    }
}

private extension EntityRelationshipSpyIdentifier {

    convenience init(fakeStoreKey: FakeStoreKey) {
        switch fakeStoreKey {
        case .remoteAndLocal(let remoteValue, let localValue):
            self.init(value: .remote(remoteValue, localValue))
        case .remote(let remoteValue):
            self.init(value: .remote(remoteValue, nil))
        case .local(let localValue):
            self.init(value: .local(localValue))
        }
    }
}

extension FakeStoreKey: Equatable {

    static func == (lhs: FakeStoreKey, rhs: FakeStoreKey) -> Bool {
        switch (lhs, rhs) {
        case (.remoteAndLocal(let lhsRemoteValue, let lhsLocalValue), .remoteAndLocal(let rhsRemoteValue, let rhsLocalValue)):
            return lhsRemoteValue == rhsRemoteValue
                && lhsLocalValue == rhsLocalValue
        case (.remote(let lhsRemoteValue), .remote(let rhsRemoteValue)):
            return lhsRemoteValue == rhsRemoteValue
        case (.local(let lhsLocalValue), .local(let rhsLocalValue)):
            return lhsLocalValue == rhsLocalValue
        case (.remoteAndLocal(_, let lhsLocalValue), .local(let rhsLocalValue)):
            return lhsLocalValue == rhsLocalValue
        case (.remoteAndLocal(let lhsRemoteValue, _), .remote(let rhsRemoteValue)):
            return lhsRemoteValue == rhsRemoteValue
        case (.local(let lhsLocalValue), .remoteAndLocal(_, let rhsLocalValue)):
            return lhsLocalValue == rhsLocalValue
        case (.remote(let lhsRemoteValue), .remoteAndLocal(let rhsRemoteValue, _)):
            return lhsRemoteValue == rhsRemoteValue
        default:
            return false
        }
    }
}
