//
//  FakeStore.swift
//  LucidTests
//
//  Created by Ibrahim Sha'ath on 2/5/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Lucid

/**
 * This is just a simplified version of the InMemoryStore, altered to allow a fake StoreLevel.
 */
public final class FakeStore<E>: StoringConvertible where E: LocalEntity {

    private var _cache = DualHashDictionary<E.Identifier, E>()

    public let level: StoreLevel

    public init(level: StoreLevel) {
        self.level = level
    }

    public func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        if let identifier = query.identifier {
            completion(.success(QueryResult(from: self._cache[identifier])))
        } else {
            completion(.failure(.identifierNotFound))
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        completion(.success(self._collectEntities(for: query)))
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {
        var mergedEntities: [E] = []
        for entity in entities {
            var mergedEntity = entity
            if let existingEntity = self._cache[entity.identifier] {
                mergedEntity = existingEntity.merging(entity)
            }
            self._cache[entity.identifier] = mergedEntity
            mergedEntities.append(mergedEntity)
        }
        completion(.success(mergedEntities.any))
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {
        let results = self._collectEntities(for: query)
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

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {
        for identifier in identifiers {
            self._cache[identifier] = nil
        }
        completion(.success(()))
    }
}

// MARK: - Collect

private extension FakeStore {

    func _collectEntities(for query: Query<E>) -> QueryResult<E> {
        guard let filter = query.filter else {
            return QueryResult(from: _cache, for: query).materialized
        }
        return QueryResult(from: _cache.filter(with: filter),
                           for: query,
                           entitiesByID: _cache).materialized
    }
}
