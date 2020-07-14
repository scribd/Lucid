//
//  CoreManagerSpy.swift
//  LucidTestKit
//
//  Created by Stephane Magne on 9/18/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

#if !RELEASE

import Foundation
import XCTest

#if LUCID_REACTIVE_KIT
import ReactiveKit
@testable import Lucid_ReactiveKit
#else
import Combine
@testable import Lucid
#endif

public final class CoreManagerSpy<E: Entity> {

    public typealias AnyEntityType = AnyEntitySpy

    // MARK: Stubs

    #if LUCID_REACTIVE_KIT
    public var getEntityStub: Signal<QueryResult<E>, ManagerError> = .failed(.notSupported)
    public var getEntityStubs: [Signal<QueryResult<E>, ManagerError>]?

    public var setEntityStub: Signal<E, ManagerError> = .failed(.notSupported)
    public var setEntityStubs: [Signal<E, ManagerError>]?

    public var setEntitiesStub: Signal<AnySequence<E>, ManagerError> = .failed(.notSupported)
    public var setEntitiesStubs: [Signal<AnySequence<E>, ManagerError>]?

    public var removeAllStub: Signal<AnySequence<E.Identifier>, ManagerError> = .failed(.notSupported)
    public var removeAllStubs: [Signal<AnySequence<E.Identifier>, ManagerError>]?

    public var removeEntityStub: Signal<Void, ManagerError> = .failed(.notSupported)
    public var removeEntityStubs: [Signal<Void, ManagerError>]?

    public var removeEntitiesStub: Signal<Void, ManagerError> = .failed(.notSupported)
    public var removeEntitiesStubs: [Signal<Void, ManagerError>]?

    public var searchStub: (
        once: Signal<QueryResult<E>, ManagerError>,
        continuous: SafeSignal<QueryResult<E>>
    ) = (once: .failed(.notSupported), continuous: .completed())

    public var searchStubs: [(
        once: Signal<QueryResult<E>, ManagerError>,
        continuous: SafeSignal<QueryResult<E>>
    )]?
    #else
    public var getEntityStub: AnyPublisher<QueryResult<E>, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var getEntityStubs: [AnyPublisher<QueryResult<E>, ManagerError>]?

    public var setEntityStub: AnyPublisher<E, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var setEntityStubs: [AnyPublisher<E, ManagerError>]?

    public var setEntitiesStub: AnyPublisher<AnySequence<E>, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var setEntitiesStubs: [AnyPublisher<AnySequence<E>, ManagerError>]?

    public var removeAllStub: AnyPublisher<AnySequence<E.Identifier>, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var removeAllStubs: [AnyPublisher<AnySequence<E.Identifier>, ManagerError>]?

    public var removeEntityStub: AnyPublisher<Void, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var removeEntityStubs: [AnyPublisher<Void, ManagerError>]?

    public var removeEntitiesStub: AnyPublisher<Void, ManagerError> = Fail(error: .notSupported).eraseToAnyPublisher()
    public var removeEntitiesStubs: [AnyPublisher<Void, ManagerError>]?

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
    #endif

    // MARK: Records

    public var getEntityRecords: [GetRecord] = []

    public var setEntityRecords: [SetRecord] = []

    public var setEntitiesRecords: [SetRecord] = []

    public var removeAllRecords: [RemoveAllRecord] = []

    public var removeEntityRecords: [RemoveRecord] = []

    public var removeEntitiesRecords: [RemoveRecord] = []

    public var searchRecords: [SearchRecord] = []

    // MARK: API

    #if LUCID_REACTIVE_KIT
    public func get(withQuery query: Query<E>,
                    in context: ReadContext<E>) -> Signal<QueryResult<E>, ManagerError> {
        getEntityRecords.append(GetRecord(query: query, context: context))
        return getEntityStubs?.getOrFail(at: getEntityRecords.count - 1) ?? getEntityStub
    }

    public func search(withQuery query: Query<E>,
                       in context: ReadContext<E>) -> (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>) {
        searchRecords.append(SearchRecord(query: query, context: context))
        return searchStubs?.getOrFail(at: searchRecords.count - 1) ?? searchStub
    }

    public func set(_ entity: E,
                    in context: WriteContext<E>) -> Signal<E, ManagerError> {
        setEntityRecords.append(SetRecord(entity: [entity], context: context))
        return setEntityStubs?.getOrFail(at: setEntityRecords.count - 1) ?? setEntityStub
    }

    public func set<S>(_ entities: S,
                       in context: WriteContext<E>) -> Signal<AnySequence<E>, ManagerError> where S: Sequence, S.Element == E {
        setEntitiesRecords.append(SetRecord(entity: entities.array, context: context))
        return setEntitiesStubs?.getOrFail(at: setEntitiesRecords.count - 1) ?? setEntitiesStub
    }

    public func removeAll(withQuery query: Query<E>,
                          in context: WriteContext<E>) -> Signal<AnySequence<E.Identifier>, ManagerError> {
        removeAllRecords.append(RemoveAllRecord(query: query, context: context))
        return removeAllStubs?.getOrFail(at: removeAllRecords.count - 1) ?? removeAllStub
    }

    public func remove(atID identifier: E.Identifier,
                       in context: WriteContext<E>) -> Signal<Void, ManagerError> {
        removeEntityRecords.append(RemoveRecord(identifier: [identifier], context: context))
        return removeEntityStubs?.getOrFail(at: removeEntityRecords.count - 1) ?? removeEntityStub
    }

    public func remove<S>(_ identifiers: S,
                          in context: WriteContext<E>) -> Signal<Void, ManagerError> where S: Sequence, S.Element == E.Identifier {
        removeEntityRecords.append(RemoveRecord(identifier: identifiers.array, context: context))
        return removeEntitiesStubs?.getOrFail(at: removeEntityRecords.count - 1) ?? removeEntitiesStub
    }
    #else
    public func get(withQuery query: Query<E>,
                    in context: ReadContext<E>) -> AnyPublisher<QueryResult<E>, ManagerError> {
        getEntityRecords.append(GetRecord(query: query, context: context))
        return getEntityStubs?.getOrFail(at: getEntityRecords.count - 1) ?? getEntityStub
    }

    public func search(withQuery query: Query<E>,
                       in context: ReadContext<E>) -> (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnyPublisher<QueryResult<E>, Never>) {
        searchRecords.append(SearchRecord(query: query, context: context))
        return searchStubs?.getOrFail(at: searchRecords.count - 1) ?? searchStub
    }

    public func set(_ entity: E,
                    in context: WriteContext<E>) -> AnyPublisher<E, ManagerError> {
        setEntityRecords.append(SetRecord(entity: [entity], context: context))
        return setEntityStubs?.getOrFail(at: setEntityRecords.count - 1) ?? setEntityStub
    }

    public func set<S>(_ entities: S,
                       in context: WriteContext<E>) -> AnyPublisher<AnySequence<E>, ManagerError> where S: Sequence, S.Element == E {
        setEntitiesRecords.append(SetRecord(entity: entities.array, context: context))
        return setEntitiesStubs?.getOrFail(at: setEntitiesRecords.count - 1) ?? setEntitiesStub
    }

    public func removeAll(withQuery query: Query<E>,
                          in context: WriteContext<E>) -> AnyPublisher<AnySequence<E.Identifier>, ManagerError> {
        removeAllRecords.append(RemoveAllRecord(query: query, context: context))
        return removeAllStubs?.getOrFail(at: removeAllRecords.count - 1) ?? removeAllStub
    }

    public func remove(atID identifier: E.Identifier,
                       in context: WriteContext<E>) -> AnyPublisher<Void, ManagerError> {
        removeEntityRecords.append(RemoveRecord(identifier: [identifier], context: context))
        return removeEntityStubs?.getOrFail(at: removeEntityRecords.count - 1) ?? removeEntityStub
    }

    public func remove<S>(_ identifiers: S,
                          in context: WriteContext<E>) -> AnyPublisher<Void, ManagerError> where S: Sequence, S.Element == E.Identifier {
        removeEntityRecords.append(RemoveRecord(identifier: identifiers.array, context: context))
        return removeEntitiesStubs?.getOrFail(at: removeEntityRecords.count - 1) ?? removeEntitiesStub
    }
    #endif
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
                            searchEntities: { self.search(withQuery: $0, in: $1) },
                            setEntity: { self.set($0, in: $1) },
                            setEntities: { self.set($0, in: $1) },
                            removeAllEntities: { self.removeAll(withQuery: $0, in: $1) },
                            removeEntity: { self.remove(atID: $0, in: $1)},
                            removeEntities: { self.remove($0, in: $1) },
                            relationshipManager: nil)
    }
}

#endif
