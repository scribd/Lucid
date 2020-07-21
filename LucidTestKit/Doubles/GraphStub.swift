//
//  GraphStub.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 2/5/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import XCTest

#if LUCID_REACTIVE_KIT
import Lucid_ReactiveKit
#else
import Lucid
#endif

public final class GraphStub: MutableGraph {

    public typealias AnyEntity = AnyEntitySpy

    public private(set) var rootEntities: [AnyEntitySpy]

    public private(set) var entitySpies = DualHashDictionary<EntitySpyIdentifier, EntitySpy>()

    public private(set) var entityRelationshipSpies = DualHashDictionary<EntityRelationshipSpyIdentifier, EntityRelationshipSpy>()

    public init() {
        rootEntities = []
    }

    public func insert<S>(_ entities: S) where S: Sequence, AnyEntitySpy == S.Element {
        for entity in entities {
            switch entity {
            case .entitySpy(let value):
                entitySpies[value.identifier] = value
            case .entityRelationshipSpy(let value):
                entityRelationshipSpies[value.identifier] = value
            }
        }
    }

    public func setRoot<S>(_ entities: S) where S: Sequence, AnyEntitySpy == S.Element {
        rootEntities = entities.array
    }

    public func contains(_ identifier: AnyRelationshipIdentifierConvertible) -> Bool {
        guard let identifier = identifier as? EntityRelationshipSpyIdentifier else {
            XCTFail("Expected an identifier of type \(EntityRelationshipSpyIdentifier.self)")
            return false
        }
        return entityRelationshipSpies[identifier] != nil
    }

    public var entities: [AnyEntitySpy] {
        return [
            entitySpies.values.map { .entitySpy($0) },
            entityRelationshipSpies.values.map { .entityRelationshipSpy($0) }
        ].flatMap { $0 }
    }
}
