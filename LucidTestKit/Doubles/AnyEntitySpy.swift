//
//  AnyEntitySpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 2/5/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import XCTest
import Lucid

public enum AnyEntitySpyIndexName: Hashable, QueryResultConvertible {
    case entitySpy(EntitySpy.IndexName)
    case entityRelationshipSpy(EntityRelationshipSpy.IndexName)

    public var requestValue: String {
        switch self {
        case .entitySpy(let index):
            return index.requestValue
        case .entityRelationshipSpy(let index):
            return index.requestValue
        }
    }
}

public enum AnyRelationshipSpyPath: RelationshipPathConvertible {
    public typealias AnyEntity = AnyEntitySpy

    public var paths: [[AnyEntitySpyIndexName]] {
        return []
    }
}

public enum AnyEntitySpy: EntityIndexing, EntityConvertible {
    case entitySpy(EntitySpy)
    case entityRelationshipSpy(EntityRelationshipSpy)

    public init?<E>(_ entity: E) where E: Entity {
        switch entity {
        case let entity as EntitySpy:
            self = .entitySpy(entity)
        case let entity as EntityRelationshipSpy:
            self = .entityRelationshipSpy(entity)
        default:
            return nil
        }
    }

    public var entityRelationshipIndices: [AnyEntitySpyIndexName] {
        switch self {
        case .entitySpy(let entity):
            return entity.entityRelationshipIndices.map { .entitySpy($0) }
        case .entityRelationshipSpy(let entity):
            return entity.entityRelationshipIndices.map { .entityRelationshipSpy($0) }
        }
    }

    public func entityIndexValue(for indexName: AnyEntitySpyIndexName) -> EntityIndexValue<EntityRelationshipSpyIdentifier, VoidSubtype> {
        switch (self, indexName) {
        case (.entitySpy(let entity), .entitySpy(let indexName)):
            return entity.entityIndexValue(for: indexName)
        case (.entityRelationshipSpy(let entity), .entityRelationshipSpy(let indexName)):
            return entity.entityIndexValue(for: indexName)
        default:
            XCTFail("Unexpected couple \(self) / \(indexName)")
            return .none
        }
    }

    public var description: String {
        switch self {
        case .entitySpy(let entity):
            return entity.identifier.description
        case .entityRelationshipSpy(let entity):
            return entity.identifier.description
        }
    }
}
