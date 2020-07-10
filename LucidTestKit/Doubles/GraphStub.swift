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
@testable import Lucid_ReactiveKit
#else
@testable import Lucid
#endif

final class GraphStub: MutableGraph {

    typealias AnyEntity = AnyEntitySpy

    private(set) var rootEntities: [AnyEntitySpy]

    private(set) var entitySpies = DualHashDictionary<EntitySpyIdentifier, EntitySpy>()

    private(set) var entityRelationshipSpies = DualHashDictionary<EntityRelationshipSpyIdentifier, EntityRelationshipSpy>()

    init() {
        rootEntities = []
    }

    func insert<S>(_ entities: S) where S: Sequence, AnyEntitySpy == S.Element {
        for entity in entities {
            switch entity {
            case .entitySpy(let value):
                entitySpies[value.identifier] = value
            case .entityRelationshipSpy(let value):
                entityRelationshipSpies[value.identifier] = value
            }
        }
    }

    func setRoot<S>(_ entities: S) where S: Sequence, AnyEntitySpy == S.Element {
        rootEntities = entities.array
    }

    func contains(_ identifier: AnyRelationshipIdentifierConvertible) -> Bool {
        guard let identifier = identifier as? EntityRelationshipSpyIdentifier else {
            XCTFail("Expected an identifier of type \(EntityRelationshipSpyIdentifier.self)")
            return false
        }
        return entityRelationshipSpies[identifier] != nil
    }

    var entities: [AnyEntitySpy] {
        return [
            entitySpies.values.map { .entitySpy($0) },
            entityRelationshipSpies.values.map { .entityRelationshipSpy($0) }
        ].flatMap { $0 }
    }
}
