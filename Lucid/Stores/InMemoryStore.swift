//
//  InMemoryStore.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/21/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

public final class InMemoryStore<E>: StoringConvertible where E: LocalEntity {

    private var _cache = DualHashDictionary<E.Identifier, E>()

    private let dispatchQueue = DispatchQueue(label: "\(InMemoryStore.self)", attributes: .concurrent)

    public let level: StoreLevel = .memory

    private let notificationCenter: NotificationCenter

    deinit {
        notificationCenter.removeObserver(self)
    }

    public init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        if let memoryPressureNotification = Constants.memoryPressureNotification {
            notificationCenter.addObserver(forName: memoryPressureNotification, object: nil, queue: nil) { [weak self] _ in
                guard let self = self else { return }
                self.didReceiveMemoryWarning()
            }
        }
    }

    public func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        guard let identifier = query.identifier else {
            completion(.failure(.identifierNotFound))
            return
        }

        dispatchQueue.async {
            let entity = self._cache[identifier]
            completion(.success(QueryResult(from: entity)))
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        dispatchQueue.async {
            let results = self._collectEntities(for: query)
            completion(.success(results))
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {
        dispatchQueue.async(flags: .barrier) {
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
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {
        dispatchQueue.async(flags: .barrier) {
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
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {
        dispatchQueue.async(flags: .barrier) {
            for identifier in identifiers {
                self._cache[identifier] = nil
            }
            completion(.success(()))
        }
    }
}

// MARK: - Collect

private extension InMemoryStore {

    func _collectEntities(for query: Query<E>) -> QueryResult<E> {
        guard let filter = query.filter else {
            return QueryResult(from: _cache, for: query).materialized
        }
        return QueryResult(from: _cache.filter(with: filter),
                           for: query,
                           entitiesByID: _cache).materialized
    }
}

// MARK: - Memory Pressure

private extension InMemoryStore {

    func didReceiveMemoryWarning() {
        dispatchQueue.sync(flags: .barrier) {
            _cache = DualHashDictionary<E.Identifier, E>()
        }
    }
}

// MARK: - Constants

extension InMemoryStore {

    enum Constants {

        static var memoryPressureNotification: Notification.Name? {
            #if os(iOS) || os(tvOS)
            return UIApplication.didReceiveMemoryWarningNotification
            #elseif os(macOS) || os(Linux)
            return nil
            #elseif os(watchOS)
            if #available(watchOS 7.0, *) {
                return WKExtension.applicationWillResignActiveNotification
            } else {
                return nil
            }
            #endif
        }
    }
}
