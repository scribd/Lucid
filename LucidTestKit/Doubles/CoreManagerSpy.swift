//
//  CoreManagerSpy.swift
//  LucidTestKit
//
//  Created by Stephane Magne on 9/18/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
import ReactiveKit
import XCTest

@testable import Lucid

public final class CoreManagerSpy<E: Entity> {
    
    public typealias AnyEntityType = AnyEntitySpy
    
    // MARK: Stubs
    
    var getEntityStub: Signal<QueryResult<E>, ManagerError> = .failed(.notSupported)
    var getEntityStubs: [Signal<QueryResult<E>, ManagerError>]?

    var setEntityStub: Signal<E, ManagerError> = .failed(.notSupported)
    var setEntityStubs: [Signal<E, ManagerError>]?

    var setEntitiesStub: Signal<AnySequence<E>, ManagerError> = .failed(.notSupported)
    var setEntitiesStubs: [Signal<AnySequence<E>, ManagerError>]?

    var removeAllStub: Signal<AnySequence<E.Identifier>, ManagerError> = .failed(.notSupported)
    var removeAllStubs: [Signal<AnySequence<E.Identifier>, ManagerError>]?

    var removeEntityStub: Signal<Void, ManagerError> = .failed(.notSupported)
    var removeEntityStubs: [Signal<Void, ManagerError>]?

    var removeEntitiesStub: Signal<Void, ManagerError> = .failed(.notSupported)
    var removeEntitiesStubs: [Signal<Void, ManagerError>]?

    var searchStub: (
        once: Signal<QueryResult<E>, ManagerError>,
        continuous: SafeSignal<QueryResult<E>>
    ) = (once: .failed(.notSupported), continuous: .completed())

    var searchStubs: [(
        once: Signal<QueryResult<E>, ManagerError>,
        continuous: SafeSignal<QueryResult<E>>
    )]?

    // MARK: Records
    
    var getEntityRecords: [GetRecord] = []
    
    var setEntityRecords: [SetRecord] = []
    
    var setEntitiesRecords: [SetRecord] = []
    
    var removeAllRecords: [RemoveAllRecord] = []
    
    var removeEntityRecords: [RemoveRecord] = []
    
    var removeEntitiesRecords: [RemoveRecord] = []
    
    var searchRecords: [SearchRecord] = []
    
    // MARK: API
    
    func get(byID identifier: E.Identifier,
             in context: ReadContext<E>) -> Signal<QueryResult<E>, ManagerError> {
        getEntityRecords.append(GetRecord(identifier: identifier, context: context))
        return getEntityStubs?.getOrFail(at: getEntityRecords.count - 1) ?? getEntityStub
    }

    func search(withQuery query: Query<E>,
                in context: ReadContext<E>) -> (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>) {
        searchRecords.append(SearchRecord(query: query, context: context))
        return searchStubs?.getOrFail(at: searchRecords.count - 1) ?? searchStub
    }

    func set(_ entity: E,
             in context: WriteContext<E>) -> Signal<E, ManagerError> {
        setEntityRecords.append(SetRecord(entity: [entity], context: context))
        return setEntityStubs?.getOrFail(at: setEntityRecords.count - 1) ?? setEntityStub
    }
    
    func set<S>(_ entities: S,
                in context: WriteContext<E>) -> Signal<AnySequence<E>, ManagerError> where S: Sequence, S.Element == E {
        setEntitiesRecords.append(SetRecord(entity: entities.array, context: context))
        return setEntitiesStubs?.getOrFail(at: setEntitiesRecords.count - 1) ?? setEntitiesStub
    }
    
    func removeAll(withQuery query: Query<E>,
                   in context: WriteContext<E>) -> Signal<AnySequence<E.Identifier>, ManagerError> {
        removeAllRecords.append(RemoveAllRecord(query: query, context: context))
        return removeAllStubs?.getOrFail(at: removeAllRecords.count - 1) ?? removeAllStub
    }
    
    func remove(atID identifier: E.Identifier,
                in context: WriteContext<E>) -> Signal<Void, ManagerError> {
        removeEntityRecords.append(RemoveRecord(identifier: [identifier], context: context))
        return removeEntityStubs?.getOrFail(at: removeEntityRecords.count - 1) ?? removeEntityStub
    }
    
    func remove<S>(_ identifiers: S,
                   in context: WriteContext<E>) -> Signal<Void, ManagerError> where S: Sequence, S.Element == E.Identifier {
        removeEntityRecords.append(RemoveRecord(identifier: identifiers.array, context: context))
        return removeEntitiesStubs?.getOrFail(at: removeEntityRecords.count - 1) ?? removeEntitiesStub
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

extension CoreManagerSpy {
    
    struct GetRecord {
        let identifier: E.Identifier
        let context: ReadContext<E>
    }

    struct SearchRecord {
        let query: Query<E>
        let context: ReadContext<E>
    }

    struct SetRecord {
        let entity: [E]
        let context: WriteContext<E>
    }
    
    struct RemoveAllRecord {
        let query: Query<E>
        let context: WriteContext<E>
    }
    
    struct RemoveRecord {
        let identifier: [E.Identifier]
        let context: WriteContext<E>
    }
}

// MARK: - CoreManaging Conversion

extension CoreManagerSpy {
    
    func managing<AnyEntityType>() -> CoreManaging<E, AnyEntityType> where AnyEntityType: EntityConvertible {
        return CoreManaging(getEntity: { self.get(byID: $0, in: $1) },
                            searchEntities: { self.search(withQuery: $0, in: $1) },
                            setEntity: { self.set($0, in: $1) },
                            setEntities: { self.set($0, in: $1) },
                            removeAllEntities: { self.removeAll(withQuery: $0, in: $1) },
                            removeEntity: { self.remove(atID: $0, in: $1)},
                            removeEntities: { self.remove($0, in: $1) },
                            relationshipManager: nil)
    }
}
