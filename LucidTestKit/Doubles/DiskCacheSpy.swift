//
//  DiskCacheSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 10/18/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

#if !RELEASE

#if LUCID_REACTIVE_KIT
@testable import Lucid_ReactiveKit
#else
@testable import Lucid
#endif

public final class DiskCacheSpy<DataType: Codable> {

    // MARK: - Stubs

    public var values = [String: DataType]()

    // MARK: - Records

    public private(set) var getInvocations = [(
        String
    )]()

    public private(set) var setInvocations = [(
        String,
        DataType?
    )]()

    public private(set) var asyncSetInvocations = [(
        String,
        DataType?
    )]()

    // MARK: - Implementation

    public init() {
        // no-op
    }

    public var caching: DiskCaching<DataType> {
        return DiskCaching(get: {
            self.getInvocations.append(($0))
            return self.values[$0]
        }, set: {
            self.values[$0] = $1
            self.setInvocations.append(($0, $1))
            return true
        }, asyncSet: {
            self.values[$0] = $1
            self.asyncSetInvocations.append(($0, $1))
        }, keys: {
            Array(self.values.keys)
        },
           keysAtInitialization: {
            Array(self.values.keys)
        })
    }
}

#endif
