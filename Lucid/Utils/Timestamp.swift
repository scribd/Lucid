//
//  Timestamp.swift
//  Lucid
//
//  Created by Théophane Rupin on 5/23/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

/// Precise timestamp (ns) taken at the kernel level.
func timestampInNanoseconds() -> UInt64 {
    var info = mach_timebase_info()
    guard mach_timebase_info(&info) == KERN_SUCCESS else {
        Logger.log(.error, "\(#function): Failed to retrieve timestamp.", assert: true)
        return .max
    }
    let currentTime = mach_absolute_time()
    if info.denom != 0 {
        return currentTime * UInt64(info.numer) / UInt64(info.denom)
    } else {
        Logger.log(.error, "\(#function): Failed to retrieve a valid timestamp's denom.", assert: true)
        return .max
    }
}
