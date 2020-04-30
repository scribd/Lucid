//
//  RelationshipCoreManagerSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 2/5/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import XCTest
import ReactiveKit

@testable import Lucid

final class RelationshipCoreManagerSpy: RelationshipCoreManaging {

    private(set) var getByIDsInstanciations = [(
        identifiers: [AnyRelationshipIdentifierConvertible],
        entityType: String,
        context: _ReadContext<EntityEndpointResultPayloadSpy>
    )]()
    
    var getByIDsStubs: [Signal<[AnyEntitySpy], ManagerError>] = [Signal(just: [])]
    
    func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
             entityType: String,
             in context: _ReadContext<EntityEndpointResultPayloadSpy>) -> Signal<AnySequence<AnyEntitySpy>, ManagerError> {

        getByIDsInstanciations.append((identifiers.array, entityType, context))

        guard getByIDsStubs.count >= getByIDsInstanciations.count else {
            XCTFail("Expected stub for call number \(getByIDsInstanciations.count - 1)")
            return Signal(just: [].any)
        }

        return getByIDsStubs[getByIDsInstanciations.count - 1].map { $0.any }
    }
}
