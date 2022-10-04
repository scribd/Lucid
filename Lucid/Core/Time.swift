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

    public var value: CMTime { return _value.time }

    private let _value: TimeWrapper

    public required init(seconds: Double, preferredTimescale: Int32 = 1000) {
        _value = TimeWrapper(time: CMTime(seconds: seconds, preferredTimescale: preferredTimescale))
    }

    public static func == (lhs: Time, rhs: Time) -> Bool {
        return lhs.value == rhs.value
    }

    public static func < (lhs: Time, rhs: Time) -> Bool {
        return lhs.value < rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        return _value.hash(into: &hasher)
    }

    public static var zero: Self {
        return Self(seconds: 0)
    }

    public var seconds: Seconds {
        return Seconds(seconds: value.seconds, preferredTimescale: value.timescale)
    }

    public var milliseconds: Milliseconds {
        return Milliseconds(seconds: value.seconds, preferredTimescale: value.timescale)
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

// MARK: - Private

/// Because iOS 16 introduced Hashable onto CMTime, it broke our compilation with our custom Hashable extensions.
/// Swift doesn't offer syntax to only use the custom extension on iOS 15 and earlier.
/// When iOS 16 becomes the minimum target, this class can be deleted and just replace it's usage with CMTime.
private final class TimeWrapper: Hashable, Comparable {

    let time: CMTime

    init(time: CMTime) {
        self.time = time
    }

    // MARK: Hashable

    public func hash(into hasher: inout Hasher) {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            time.hash(into: &hasher)
        } else {
            hasher.combine(time.seconds.hashValue)
        }
        #elseif os(watchOS)
        if #available(watchOS 9.0, *) {
            time.hash(into: &hasher)
        } else {
            hasher.combine(time.seconds.hashValue)
        }
        #elseif os(tvOS)
        if #available(tvOS 16.0, *) {
            time.hash(into: &hasher)
        } else {
            hasher.combine(time.seconds.hashValue)
        }
        #elseif os(macOS)
        if #available(macOS 13.0, *) {
            time.hash(into: &hasher)
        } else {
            hasher.combine(time.seconds.hashValue)
        }
        #endif
    }

    // MARK: Comparable

    static func == (lhs: TimeWrapper, rhs: TimeWrapper) -> Bool {
        return lhs.time == rhs.time
    }

    static func < (lhs: TimeWrapper, rhs: TimeWrapper) -> Bool {
        return lhs.time < rhs.time
    }
}
