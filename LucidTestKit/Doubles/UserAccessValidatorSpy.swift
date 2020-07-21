//
//  UserAccessValidatorSpy.swift
//  LucidTestKit
//
//  Created by Stephane Magne on 2/10/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

#if LUCID_REACTIVE_KIT
import Lucid_ReactiveKit
#else
import Lucid
#endif

public final class UserAccessValidatorSpy: UserAccessValidating {

    public init() {
        // no-op
    }

    public var stub: UserAccess = .remoteAccess

    public var userAccessInvocations: Int = 0

    public var userAccess: UserAccess {
        userAccessInvocations += 1
        return stub
    }
}
