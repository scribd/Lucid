//
//  ManagerResult.swift
//  Lucid
//
//  Created by Théophane Rupin on 9/6/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

public enum ManagerResult<E> where E: Entity {
    case groups(DualHashDictionary<EntityIndexValue<E.RelationshipIdentifier, E.Subtype>, [E]>)
    case entities([E])

    public var entities: [E] {
        switch self {
        case .groups(let groups):
            return groups.values.flatMap { $0 }
        case .entities(let entities):
            return entities
        }
    }

    public var entity: E? {
        return entities.first
    }

    public var isEmpty: Bool {
        return entities.isEmpty
    }
}

public extension ManagerResult {

    static func entity(_ entity: E?) -> ManagerResult {
        return .entities([entity].compactMap { $0 })
    }

    static var empty: ManagerResult {
        return .entities([])
    }
}

// MARK: - Sequence

extension ManagerResult: Sequence {

    public __consuming func makeIterator() -> Array<E>.Iterator {
        return entities.makeIterator()
    }
}

// MARK: - Conversions

public extension QueryResult {

    var managerResult: ManagerResult<E> {
        switch data {
        case .groups(let groups):
            return .groups(groups)
        case .entitiesSequence(let entities):
            return .entities(entities.array)
        case .entitiesArray(let entities):
            return .entities(entities)
        }
    }
}
