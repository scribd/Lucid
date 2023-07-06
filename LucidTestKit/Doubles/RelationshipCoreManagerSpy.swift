//
//  RelationshipCoreManagerSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 2/5/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Combine
import Foundation
import Lucid
import XCTest

public final class RelationshipCoreManagerSpy: RelationshipCoreManaging {

    public init() {
        // no-op
    }

    public private(set) var getByIDsInvocations = [(
        identifiers: [AnyRelationshipIdentifierConvertible],
        entityType: String,
        context: _ReadContext<EntityEndpointResultPayloadSpy>
    )]()

    public var getByIDsStubs: [AnyPublisher<[AnyEntitySpy], ManagerError>] = [Publishers.ReplayOnce(just: []).eraseToAnyPublisher()]

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

    public private(set) var getByIDsAsyncInvocations = [(
        identifiers: [AnyRelationshipIdentifierConvertible],
        entityType: String,
        context: _ReadContext<EntityEndpointResultPayloadSpy>
    )]()

    public var getByIDsAsyncStubs: [[AnyEntitySpy]] = []
    public var getByIDsAsyncError: ManagerError? = nil

    public func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
                    entityType: String,
                    in context: _ReadContext<EntityEndpointResultPayloadSpy>) async throws -> AnySequence<AnyEntitySpy> {

        getByIDsAsyncInvocations.append((identifiers.array, entityType, context))

        if let error = getByIDsAsyncError {
            throw error
        }

        guard getByIDsAsyncStubs.count >= getByIDsAsyncInvocations.count else {
            XCTFail("Expected stub for call number \(getByIDsInvocations.count - 1)")
            return [].any
        }

        return getByIDsAsyncStubs[getByIDsAsyncInvocations.count - 1].any
    }
}
