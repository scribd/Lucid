//
//  PropertyBox.swift
//  Lucid
//
//  Created by Théophane Rupin on 5/3/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

/// A mutable property which can either ensure atomicity or not.
public final class PropertyBox<T> {

    private let valueQueue: DispatchQueue?

    private var _value: T

    public var value: T {
        get {
            if let valueQueue = valueQueue {
                return valueQueue.sync { _value }
            } else {
                return _value
            }
        }
        set {
            if let valueQueue = valueQueue {
                valueQueue.async(flags: .barrier) {
                    self._value = newValue
                }
            } else {
                Logger.log(.error, "\(PropertyBox.self): A non atomic property cannot be mutated.", assert: true)
            }
        }
    }

    public init(_ value: T, _ valueQueue: DispatchQueue) {
        self.valueQueue = valueQueue
        _value = value
    }

    public init(_ value: T, atomic: Bool) {
        _value = value
        valueQueue = atomic ? DispatchQueue(label: "\(PropertyBox.self)") : nil
    }
}

extension PropertyBox: Codable where T: Codable {

    private enum Keys: String, CodingKey {
        case atomic
        case value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        let atomic: Bool = valueQueue != nil
        try container.encode(atomic, forKey: .atomic)
        try container.encode(value, forKey: .value)
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)

        let atomic = try container.decode(Bool.self, forKey: .atomic)
        let value = try container.decode(T.self, forKey: .value)
        self.init(value, atomic: atomic)
    }
}

extension PropertyBox: Equatable where T: Equatable {

    public static func == (_ lhs: PropertyBox<T>, _ rhs: PropertyBox<T>) -> Bool {
        return lhs.value == rhs.value
    }
}
