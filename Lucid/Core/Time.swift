//
//  Time.swift
//  Lucid
//
//  Created by Théophane Rupin on 1/15/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
import AVFoundation

public class Time: Hashable, Comparable {
    
    public let value: CMTime
        
    public init(seconds: Double, preferredTimescale: Int32 = 1000) {
        value = CMTime(seconds: seconds, preferredTimescale: preferredTimescale)
    }
    
    public static func == (lhs: Time, rhs: Time) -> Bool {
        return lhs.value == rhs.value
    }
    
    public static func < (lhs: Time, rhs: Time) -> Bool {
        return lhs.value < rhs.value
    }
    
    public func hash(into hasher: inout Hasher) {
        return value.hash(into: &hasher)
    }

    public static var zero: Time {
        return Time(seconds: 0)
    }
}

@objc public final class SCTimeObjc: NSObject {
    public let _value: Time
    
    public init(_ value: Time) {
        self._value = value
    }
    
    @objc public var value: CMTime {
        return _value.value
    }
}
