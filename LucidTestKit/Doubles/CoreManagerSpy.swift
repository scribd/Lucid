//
//  CoreManagerSpy.swift
//  LucidTestKit
//
//  Created by Stephane Magne on 9/18/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Combine
import Foundation
import Lucid
import XCTest

public final class CoreManagerSpy<E: Entity> {

    public typealias AnyEntityType = AnyEntitySpy

    public enum AsyncResult<T> {
        case value(_: T)
        case error(_: ManagerError)
    }

    // MARK: Stubs

    public var getEntityStub: AnyPublisher<QueryResult<E>, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var getEntityStubs: [AnyPublisher<QueryResult<E>, ManagerError>]?

    public var getEntityAsyncStub: AsyncResult<QueryResult<E>> = .error(.notSupported)
    public var getEntityAsyncStubs: [AsyncResult<QueryResult<E>>]?

    public var setEntityStub: AnyPublisher<E, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var setEntityStubs: [AnyPublisher<E, ManagerError>]?

    public var setEntityAsyncStub: AsyncResult<E> = .error(.notSupported)
    public var setEntityAsyncStubs: [AsyncResult<E>]?

    public var setEntitiesStub: AnyPublisher<AnySequence<E>, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var setEntitiesStubs: [AnyPublisher<AnySequence<E>, ManagerError>]?

    public var setEntitiesAsyncStub: AsyncResult<AnySequence<E>> = .error(.notSupported)
    public var setEntitiesAsyncStubs: [AsyncResult<AnySequence<E>>]?

    public var removeAllStub: AnyPublisher<AnySequence<E.Identifier>, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var removeAllStubs: [AnyPublisher<AnySequence<E.Identifier>, ManagerError>]?

    public var removeAllAsyncStub: AsyncResult<AnySequence<E.Identifier>> = .error(.notSupported)
    public var removeAllAsyncStubs: [AsyncResult<AnySequence<E.Identifier>>]?

    public var removeEntityStub: AnyPublisher<Void, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var removeEntityStubs: [AnyPublisher<Void, ManagerError>]?

    public var removeEntityAsyncStub: AsyncResult<Void> = .error(.notSupported)
    public var removeEntityAsyncStubs: [AsyncResult<Void>]?

    public var removeEntitiesStub: AnyPublisher<Void, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var removeEntitiesStubs: [AnyPublisher<Void, ManagerError>]?

    public var removeEntitiesAsyncStub: AsyncResult<Void> = .error(.notSupported)
    public var removeEntitiesAsyncStubs: [AsyncResult<Void>]?

    public var searchStub: (
        once: AnyPublisher<QueryResult<E>, ManagerError>,
        continuous: AnyPublisher<QueryResult<E>, Never>
    ) = (
        once: Fail(error: .notSupported).eraseToAnyPublisher(),
        continuous: PassthroughSubject().eraseToAnyPublisher()
    )

    public var searchStubs: [(
        once: AnyPublisher<QueryResult<E>, ManagerError>,
        continuous: AnyPublisher<QueryResult<E>, Never>
    )]?

    public var searchAsyncStub: (
        once: QueryResult<E>,
        continuous: AsyncStream<QueryResult<E>>
    ) = (
        once: QueryResult<E>.entities([]),
        continuous: AsyncStream<QueryResult<E>>(unfolding: { return nil })
    )

    public var searchAsyncStubs: [(
        once: QueryResult<E>,
        continuous: AsyncStream<QueryResult<E>>
    )]?

    // MARK: Records

    public var getEntityRecords: [GetRecord] = []
    public var getEntityAsyncRecords: [GetRecord] = []

    public var setEntityRecords: [SetRecord] = []
    public var setEntityAsyncRecords: [SetRecord] = []

    public var setEntitiesRecords: [SetRecord] = []
    public var setEntitiesAsyncRecords: [SetRecord] = []

    public var removeAllRecords: [RemoveAllRecord] = []
    public var removeAllAsyncRecords: [RemoveAllRecord] = []

    public var removeEntityRecords: [RemoveRecord] = []
    public var removeEntityAsyncRecords: [RemoveRecord] = []

    public var removeEntitiesRecords: [RemoveRecord] = []
    public var removeEntitiesAsyncRecords: [RemoveRecord] = []

    public var searchRecords: [SearchRecord] = []
    public var searchAsyncRecords: [SearchRecord] = []

    // MARK: API

    public init() {
        // no-op
    }

    public func get(withQuery query: Query<E>,
                    in context: ReadContext<E>) -> AnyPublisher<QueryResult<E>, ManagerError> {
        getEntityRecords.append(GetRecord(query: query, context: context))
        return getEntityStubs?.getOrFail(at: getEntityRecords.count - 1) ?? getEntityStub
    }

    public func get(withQuery query: Query<E>,
                    in context: ReadContext<E>) async throws -> QueryResult<E> {
        getEntityAsyncRecords.append(GetRecord(query: query, context: context))
        let stub = getEntityAsyncStubs?.getOrFail(at: getEntityAsyncRecords.count - 1) ?? getEntityAsyncStub
        switch stub {
        case .value(let value):
            return value
        case .error(let error):
            throw error
        }
    }

    public func search(withQuery query: Query<E>,
                       in context: ReadContext<E>) -> (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnyPublisher<QueryResult<E>, Never>) {
        searchRecords.append(SearchRecord(query: query, context: context))
        return searchStubs?.getOrFail(at: searchRecords.count - 1) ?? searchStub
    }

    public func search(withQuery query: Query<E>,
                       in context: ReadContext<E>) async throws -> (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>) {
        searchAsyncRecords.append(SearchRecord(query: query, context: context))
        return searchAsyncStubs?.getOrFail(at: searchAsyncRecords.count - 1) ?? searchAsyncStub
    }

    public func set(_ entity: E,
                    in context: WriteContext<E>) -> AnyPublisher<E, ManagerError> {
        setEntityRecords.append(SetRecord(entity: [entity], context: context))
        return setEntityStubs?.getOrFail(at: setEntityRecords.count - 1) ?? setEntityStub
    }

    public func set(_ entity: E,
                    in context: WriteContext<E>) async throws -> E {
        setEntityAsyncRecords.append(SetRecord(entity: [entity], context: context))
        let stub = setEntityAsyncStubs?.getOrFail(at: setEntityRecords.count - 1) ?? setEntityAsyncStub
        switch stub {
        case .value(let entity):
            return entity
        case .error(let error):
            throw error
        }
    }

    public func set<S>(_ entities: S,
                       in context: WriteContext<E>) -> AnyPublisher<AnySequence<E>, ManagerError> where S: Sequence, S.Element == E {
        setEntitiesRecords.append(SetRecord(entity: entities.array, context: context))
        return setEntitiesStubs?.getOrFail(at: setEntitiesRecords.count - 1) ?? setEntitiesStub
    }

    public func set<S>(_ entities: S,
                       in context: WriteContext<E>) async throws -> AnySequence<E> where S: Sequence, S.Element == E {
        setEntitiesAsyncRecords.append(SetRecord(entity: entities.array, context: context))
        let stub = setEntitiesAsyncStubs?.getOrFail(at: setEntitiesAsyncRecords.count - 1) ?? setEntitiesAsyncStub
        switch stub {
        case .value(let value):
            return value
        case .error(let error):
            throw error
        }
    }

    public func removeAll(withQuery query: Query<E>,
                          in context: WriteContext<E>) -> AnyPublisher<AnySequence<E.Identifier>, ManagerError> {
        removeAllRecords.append(RemoveAllRecord(query: query, context: context))
        return removeAllStubs?.getOrFail(at: removeAllRecords.count - 1) ?? removeAllStub
    }

    public func removeAll(withQuery query: Query<E>,
                          in context: WriteContext<E>) async throws -> AnySequence<E.Identifier> {
        removeAllAsyncRecords.append(RemoveAllRecord(query: query, context: context))
        let stub = removeAllAsyncStubs?.getOrFail(at: removeAllAsyncRecords.count - 1) ?? removeAllAsyncStub
        switch stub {
        case .value(let value):
            return value
        case .error(let error):
            throw error
        }
    }

    public func remove(atID identifier: E.Identifier,
                       in context: WriteContext<E>) -> AnyPublisher<Void, ManagerError> {
        removeEntityRecords.append(RemoveRecord(identifier: [identifier], context: context))
        return removeEntityStubs?.getOrFail(at: removeEntityRecords.count - 1) ?? removeEntityStub
    }

    public func remove(atID identifier: E.Identifier,
                       in context: WriteContext<E>) async throws {
        removeEntityAsyncRecords.append(RemoveRecord(identifier: [identifier], context: context))
        let stub = removeEntityAsyncStubs?.getOrFail(at: removeEntityAsyncRecords.count - 1) ?? removeEntityAsyncStub
        switch stub {
        case .value(let value):
            return value
        case .error(let error):
            throw error
        }
    }

    public func remove<S>(_ identifiers: S,
                          in context: WriteContext<E>) -> AnyPublisher<Void, ManagerError> where S: Sequence, S.Element == E.Identifier {
        removeEntityRecords.append(RemoveRecord(identifier: identifiers.array, context: context))
        return removeEntitiesStubs?.getOrFail(at: removeEntityRecords.count - 1) ?? removeEntitiesStub
    }

    public func remove<S>(_ identifiers: S,
                          in context: WriteContext<E>) async throws where S: Sequence, S.Element == E.Identifier {
        removeEntityAsyncRecords.append(RemoveRecord(identifier: identifiers.array, context: context))
        let stub = removeEntitiesAsyncStubs?.getOrFail(at: removeEntityAsyncRecords.count - 1) ?? removeEntitiesAsyncStub
        switch stub {
        case .value(let value):
            return value
        case .error(let error):
            throw error
        }
    }
}

private extension Array {

    func getOrFail(at index: Int) -> Element? {
        guard index < count else {
            XCTFail("Index is out of bound \(index)")
            return nil
        }
        return self[index]
    }
}

// MARK: - Record Definitions

public extension CoreManagerSpy {

    struct GetRecord {
        public let query: Query<E>
        public let context: ReadContext<E>
    }

    struct SearchRecord {
        public let query: Query<E>
        public let context: ReadContext<E>
    }

    struct SetRecord {
        public let entity: [E]
        public let context: WriteContext<E>
    }

    struct RemoveAllRecord {
        public let query: Query<E>
        public let context: WriteContext<E>
    }

    struct RemoveRecord {
        public let identifier: [E.Identifier]
        public let context: WriteContext<E>
    }
}

// MARK: - CoreManaging Conversion

public extension CoreManagerSpy {

    func managing<AnyEntityType>() -> CoreManaging<E, AnyEntityType> where AnyEntityType: EntityConvertible {
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
                            relationshipManager: nil)
    }
}
