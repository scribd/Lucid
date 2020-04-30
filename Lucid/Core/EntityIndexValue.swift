//
//  EntityIndexValue.swift
//  Lucid
//
//  Created by Théophane Rupin on 1/3/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import AVFoundation

// MARK: - EntityIndex

/// Represents the values which can be associated to an `Entity.IndexName`
public enum EntityIndexValue<RelationshipIdentifier, Subtype>: DualHashable, Comparable where RelationshipIdentifier: AnyRelationshipIdentifier, Subtype: Hashable, Subtype: Comparable {
    
    case string(String)
    case int(Int)
    case double(Double)
    case float(Float)
    case relationship(RelationshipIdentifier)
    case subtype(Subtype)
    case void
    case regex(NSRegularExpression)
    case date(Date)
    case bool(Bool)
    case time(Time)
    case url(URL)
    case color(Color)
    case none
    
    indirect case array(AnySequence<EntityIndexValue>)
    
    public static func optional(_ value: EntityIndexValue?) -> EntityIndexValue {
        return value ?? .none
    }
    
    public static func milliseconds(_ value: Milliseconds) -> EntityIndexValue {
        return .time(value)
    }
    
    public static func seconds(_ value: Seconds) -> EntityIndexValue {
        return .time(value)
    }
}

// MARK: - DualHashable

extension EntityIndexValue {

    public func hash(into hasher: inout DualHasher) {
        switch self {
        case .string(let value):
            hasher.combine(value)
        case .int(let value):
            hasher.combine(value)
        case .double(let value):
            hasher.combine(value)
        case .float(let value):
            hasher.combine(value)
        case .relationship(let value):
            hasher.combine(value)
        case .subtype(let value):
            hasher.combine(value)
        case .void:
            hasher.combine("void")
        case .regex(let value):
            hasher.combine(value)
        case .date(let value):
            hasher.combine(value)
        case .bool(let value):
            hasher.combine(value)
        case .time(let value):
            hasher.combine(value)
        case .url(let value):
            hasher.combine(value)
        case .color(let value):
            hasher.combine(value)
        case .none:
            hasher.combine("none")
        case .array:
            // Dual hashing doesn't support collections.
            hasher.combine("array")
        }
    }
}

// MARK: - Comparable

extension EntityIndexValue {
    
    public static func < (lhs: EntityIndexValue<RelationshipIdentifier, Subtype>, rhs: EntityIndexValue<RelationshipIdentifier, Subtype>) -> Bool {
        switch (lhs, rhs) {
        case (.string(let lhs), .string(let rhs)):
            return lhs < rhs
        case (.int(let lhs), .int(let rhs)):
            return lhs < rhs
        case (.double(let lhs), .double(let rhs)):
            return lhs < rhs
        case (.float(let lhs), .float(let rhs)):
            return lhs < rhs
        case (.relationship(let lhs), .relationship(let rhs)):
            return lhs < rhs
        case (.void, .void):
            return false
        case (.regex(let lhs), .regex(let rhs)):
            return lhs.pattern < rhs.pattern
        case (.date(let lhs), .date(let rhs)):
            return lhs < rhs
        case (.bool(let lhs), .bool(let rhs)):
            return lhs == false && rhs ? true : false
        case (.time(let lhs), .time(let rhs)):
            return lhs < rhs
        case (.url(let lhs), .url(let rhs)):
            return lhs.absoluteString < rhs.absoluteString
        case (.color(let lhs), .color(let rhs)):
            return lhs.hex < rhs.hex
        case (.array(let lhs), .array(let rhs)):
            return Array(lhs).count < Array(rhs).count
        case (.subtype(let lhs), .subtype(let rhs)):
            return lhs < rhs
        case (.string, _),
             (.int, _),
             (.double, _),
             (.float, _),
             (.relationship, _),
             (.subtype, _),
             (.void, _),
             (.regex, _),
             (.date, _),
             (.bool, _),
             (.time, _),
             (.url, _),
             (.color, _),
             (.none, _),
             (.array, _):
            return false
        default:
            Logger.log(.error, "\(EntityIndexValue.self): Unhandled case \(lhs) < \(rhs)", assert: true)
            return false
        }
    }
}

// MARK: - CMTime + Hashable

extension CMTime: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(seconds.hashValue)
    }
}

// MARK: - ComparableRawRepresentable

public protocol ComparableRawRepresentable: Comparable {
    associatedtype RawValue: Comparable
    var rawValue: RawValue { get }
}

extension ComparableRawRepresentable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
