//
//  RelationshipCoreManagerSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 2/5/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import XCTest

#if LUCID_REACTIVE_KIT
import ReactiveKit
import Lucid_ReactiveKit
#else
import Combine
import Lucid
#endif

public final class RelationshipCoreManagerSpy: RelationshipCoreManaging {

    public init() {
        // no-op
    }

    public private(set) var getByIDsInvocations = [(
        identifiers: [AnyRelationshipIdentifierConvertible],
        entityType: String,
        context: _ReadContext<EntityEndpointResultPayloadSpy>
    )]()

    #if LUCID_REACTIVE_KIT
    public var getByIDsStubs: [Signal<[AnyEntitySpy], ManagerError>] = [Signal(just: [])]

    public func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
                    entityType: String,
                    in context: _ReadContext<EntityEndpointResultPayloadSpy>) -> Signal<AnySequence<AnyEntitySpy>, ManagerError> {

        getByIDsInvocations.append((identifiers.array, entityType, context))

        guard getByIDsStubs.count >= getByIDsInvocations.count else {
            XCTFail("Expected stub for call number \(getByIDsInvocations.count - 1)")
            return Signal(just: [].any)
        }

        return getByIDsStubs[getByIDsInvocations.count - 1].map { $0.any }
    }

    #else
    public var getByIDsStubs: [AnyPublisher<[AnyEntitySpy], ManagerError>] = [
        Just([]).setFailureType(to: ManagerError.self).eraseToAnyPublisher()
    ]

    public func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
                    entityType: String,
                    in context: _ReadContext<EntityEndpointResultPayloadSpy>) -> AnyPublisher<AnySequence<AnyEntitySpy>, ManagerError> {

        getByIDsInvocations.append((identifiers.array, entityType, context))

        guard getByIDsStubs.count >= getByIDsInvocations.count else {
            XCTFail("Expected stub for call number \(getByIDsInvocations.count - 1)")
            return Just([].any)
                .setFailureType(to: ManagerError.self)
                .eraseToAnyPublisher()
        }

        return getByIDsStubs[getByIDsInvocations.count - 1].map { $0.any }.eraseToAnyPublisher()
    }
    #endif
}
