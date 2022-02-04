//
//  PayloadPersistenceManagerSpy.swift
//  LucidTestKit
//
//  Created by Stephane Magne on 2/4/22.
//  Copyright © 2022 Scribd. All rights reserved.
//

import Foundation
import XCTest
import Lucid

final class PayloadPersistenceManagerSpy: RemoteStoreCachePayloadPersistenceManaging {

    public init() {
        // no-op
    }

    private(set) var persistEntitiesInvocations = [(
        payload: AnyResultPayloadConvertible,
        accessValidator: UserAccessValidating?
    )]()

    func persistEntities(from payload: AnyResultPayloadConvertible, accessValidator: UserAccessValidating?) {
        persistEntitiesInvocations.append((payload, accessValidator))
    }
}
