//
//  UserAccessValidatorSpy.swift
//  LucidTestKit
//
//  Created by Stephane Magne on 2/10/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

#if !RELEASE

#if LUCID_REACTIVE_KIT
@testable import Lucid_ReactiveKit
#else
@testable import Lucid
#endif

final class UserAccessValidatorSpy: UserAccessValidating {

    var stub: UserAccess = .remoteAccess

    var userAccessInvocations: Int = 0

    var userAccess: UserAccess {
        userAccessInvocations += 1
        return stub
    }
}

#endif
