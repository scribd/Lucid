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

    // [EntityRelationshipSpyIdentifier.RemoteValue: AnyEntitySpy]
    public var getByIDsStubs: [Int: AnyPublisher<AnyEntitySpy, ManagerError>] = [:]

    public func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
                    entityType: String,
                    in context: _ReadContext<EntityEndpointResultPayloadSpy>) -> AnyPublisher<AnySequence<AnyEntitySpy>, ManagerError> {

        getByIDsInvocations.append((identifiers.array, entityType, context))

        let relationshipIdentifiers: [EntityRelationshipSpyIdentifier] = identifiers.compactMap { $0.toRelationshipID() }
        let remoteValues: [Int] = relationshipIdentifiers.compactMap { $0.value.remoteValue }
        let publishers: [AnyPublisher<AnyEntitySpy, ManagerError>] = remoteValues.compactMap { getByIDsStubs[$0] }
        return Publishers.MergeMany(publishers).collect().map { $0.any }.eraseToAnyPublisher()
    }

    public private(set) var getByIDsAsyncInvocations = [(
        identifiers: [AnyRelationshipIdentifierConvertible],
        entityType: String,
        context: _ReadContext<EntityEndpointResultPayloadSpy>
    )]()

    // [EntityRelationshipSpyIdentifier.RemoteValue: AnyEntitySpy]
    public var getByIDsAsyncStubs: [Int: AnyEntitySpy] = [:]
    public var getByIDsAsyncError: ManagerError? = nil

    public func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
                    entityType: String,
                    in context: _ReadContext<EntityEndpointResultPayloadSpy>) async throws -> AnySequence<AnyEntitySpy> {

        getByIDsAsyncInvocations.append((identifiers.array, entityType, context))

        if let error = getByIDsAsyncError {
            throw error
        }

        let relationshipIdentifiers: [EntityRelationshipSpyIdentifier] = identifiers.compactMap { $0.toRelationshipID() }
        let remoteValues: [Int] = relationshipIdentifiers.compactMap { $0.value.remoteValue }
        return remoteValues.compactMap { getByIDsAsyncStubs[$0] }.any
    }
}
