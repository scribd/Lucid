//
//  Codable.swift
//  Lucid
//
//  Created by Théophane Rupin on 1/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
import AVFoundation

// MARK: - Error

public enum DecodingErrorWrapper: Error {

    case decodingOfUnusedProperty(DecodingError)
    case decodingOfUsedProperty(DecodingError)
    case unknown(Error)

    init(_ error: Error) {
        switch error {
        case let error as DecodingErrorWrapper:
            self = error
        case let error as DecodingError:
            self = .decodingOfUsedProperty(error)
        default:
            self = .unknown(error)
        }
    }

    func log(_ message: String) {
        switch self {
        case .decodingOfUsedProperty(let error as Error),
             .unknown(let error):
            Logger.log(.error, "\(message): \(error).")
        case .decodingOfUnusedProperty:
            break
        }
    }
}

// MARK: - Context

public enum CodingContext {
    case payload
    case coreDataRelationship
    case clientQueueRequest

    fileprivate static let key = CodingUserInfoKey(rawValue: "context")
}

public extension JSONDecoder {
    func set(context: CodingContext) {
        guard let key = CodingContext.key else { return }
        userInfo[key] = context
    }
}

public extension Decoder {
    var context: CodingContext {
        if let key = CodingContext.key, let context = userInfo[key] as? CodingContext {
            return context
        } else {
            Logger.log(.error, "\(Decoder.self): \(CodingContext.self) is missing. Defaulting to `.payload`.", assert: true)
            return .payload
        }
    }
}

public extension JSONEncoder {
    func set(context: CodingContext) {
        guard let key = CodingContext.key else { return }
        userInfo[key] = context
    }
}

public extension Encoder {
    var context: CodingContext {
        if let key = CodingContext.key, let context = userInfo[key] as? CodingContext {
            return context
        } else {
            Logger.log(.error, "\(Encoder.self): \(CodingContext.self) is missing. Defaulting to `.payload`.", assert: true)
            return .payload
        }
    }
}

// MARK: - Decodable Types

public final class Seconds: Time, Codable {

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let seconds = try container.decode(Double.self)
        self.init(seconds: seconds)
    }
}

public final class Milliseconds: Time, Codable {

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let milliseconds = try container.decode(Double.self)
        self.init(seconds: milliseconds / 1000)
    }
}

extension Color: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        hex = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}

public struct PermissiveBool: Decodable {

    public let value: Bool

    public init(_ value: Bool) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            switch intValue {
            case 0:
                value = false
            case 1:
                value = true
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Int \(intValue) can't convert to a boolean.")
            }
        } else if let stringValue = try? container.decode(String.self) {
            switch stringValue.lowercased() {
            case "false", "0":
                value = false
            case "true", "1":
                value = true
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "String \(stringValue) can't convert to a boolean.")
            }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid value type.")
        }
    }
}

extension FailableValue: Decodable where T: Decodable {

    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(T.self)
            self = .value(value)
        } catch {
            self = .error(error)
        }
    }
}

extension PayloadRelationship: Decodable where P: Decodable {

    private struct CustomKey: CodingKey {
        let stringValue: String
        var intValue: Int?

        init?(intValue: Int) {
            return nil
        }

        init(stringValue: String) {
            self.stringValue = stringValue
        }
    }

    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(P.self)
            self = .value(value)
        } catch let valueDecodingError {
            DecodingErrorWrapper(valueDecodingError).log("\(PayloadRelationship.self): Error while decoding relationship")
            do {
                let identifierKey = P.identifierKey
                let container = try decoder.container(keyedBy: CustomKey.self)
                let identifier = try container.decode(P.Identifier.self, forKey: CustomKey(stringValue: identifierKey))
                self = .identifier(identifier)
            }
        }
    }
}

// MARK: - Lazy

private enum LazyKeys: String, CodingKey {
    case value
    case requested
}

extension Lazy: Decodable where T: Decodable {

    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: LazyKeys.self)
            let value = try container.decode(T?.self, forKey: .value)
            let requested = try container.decode(Bool.self, forKey: .requested)
            self = Lazy<T>(value: value, requested: requested)
        } catch {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(T?.self)
            self = Lazy<T>(value: value, requested: true)
        }
    }
}

extension Lazy: Encodable where T: Encodable {

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LazyKeys.self)
        try container.encode(value(), forKey: .value)
        try container.encode(wasRequested, forKey: .requested)
    }
}

public extension Lazy {

    func lazyAny<K>() -> Lazy<AnySequence<K>> where T == [K] {
        switch self {
        case .requested(let array):
            return .requested(array.lazy.any)
        case .unrequested:
            return .unrequested
        }
    }

    func lazyAny<K>() -> Lazy<AnySequence<K>?> where T == [K]? {
        switch self {
        case .requested(let array):
            return .requested(array?.lazy.any)
        case .unrequested:
            return .unrequested
        }
    }
}

// MARK: - Decoding Utils

public extension KeyedDecodingContainer {

    private func resolveKey(from keys: [Key]) throws -> Key {
        guard let lastKey = keys.last else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: keys, debugDescription: "At least one key is needed to decode.")
            )
        }

        return keys.first(where: { contains($0) }) ?? lastKey
    }

    func decode<O>(_ type: O.Type, forKey key: Key, defaultValue: O? = nil, logError: Bool) throws -> O where O: Decodable {
        return try decode(type, forKeys: [key], defaultValue: defaultValue, logError: logError)
    }

    func decode<O>(_ type: O.Type, forKeys keys: [Key], defaultValue: O? = nil, logError: Bool) throws -> O where O: Decodable {
        let key = try resolveKey(from: keys)
        if let defaultValue = defaultValue {
            return try decode(type, forKey: key, defaultValue: defaultValue, logError: logError) ?? defaultValue
        } else {
            return try decode(O.self, forKey: key)
        }
    }

    func decode<O>(_ type: O.Type, forKey key: Key, defaultValue: O? = nil, logError: Bool) throws -> O? where O: Decodable {
        return try decode(type, forKeys: [key], defaultValue: defaultValue, logError: logError)
    }

    func decode<O>(_ type: O.Type, forKeys keys: [Key], defaultValue: O? = nil, logError: Bool) throws -> O? where O: Decodable {
        let key = try resolveKey(from: keys)
        do {
            return try decodeIfPresent(O.self, forKey: key) ?? defaultValue
        } catch {
            if logError {
                let error = DecodingErrorWrapper(error)
                if let defaultValue = defaultValue {
                    error.log("\(KeyedDecodingContainer.self): Error while decoding, defaulting to \(defaultValue)")
                } else {
                    error.log("\(KeyedDecodingContainer.self): Error while decoding")
                }
            }
            return defaultValue
        }
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKey key: Key, defaultValue: [O]? = nil, logError: Bool) throws -> AnySequence<O> where O: Decodable {
        return try decodeSequence(type, forKeys: [key], defaultValue: defaultValue, logError: logError)
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKeys keys: [Key], defaultValue: [O]? = nil, logError: Bool) throws -> AnySequence<O> where O: Decodable {
        let key = try resolveKey(from: keys)
        if let defaultValue = defaultValue {
            return try decodeSequence(type, forKey: key, defaultValue: defaultValue, logError: logError) ?? defaultValue.lazy.any
        } else {
            return try decode([FailableValue<O>].self, forKey: key).lazy.compactMap {
                $0.value(logError: logError)
            }.any
        }
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKey key: Key, defaultValue: [O]? = nil, logError: Bool) throws -> AnySequence<O>? where O: Decodable {
        return try decodeSequence(type, forKeys: [key], defaultValue: defaultValue, logError: logError)
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKeys keys: [Key], defaultValue: [O]? = nil, logError: Bool) throws -> AnySequence<O>? where O: Decodable {
        let key = try resolveKey(from: keys)
        do {
            guard let values = try decodeIfPresent([FailableValue<O>].self, forKey: key) else {
                return defaultValue?.lazy.any
            }
            return values.lazy.compactMap { $0.value(logError: logError) }.any
        } catch {
            if logError {
                let error = DecodingErrorWrapper(error)
                if let defaultValue = defaultValue {
                    error.log("\(KeyedDecodingContainer.self): Error while decoding, defaulting to \(defaultValue)")
                } else {
                    error.log("\(KeyedDecodingContainer.self): Error while decoding")
                }
            }
            return defaultValue?.lazy.any
        }
    }

    func decode<O>(_ type: DualHashDictionary<O.Identifier, O>.Type,
                   forKey key: Key,
                   defaultValue: DualHashDictionary<O.Identifier, O>? = nil,
                   logError: Bool) throws -> DualHashDictionary<O.Identifier, O> where O: Decodable, O: EntityIdentifiable {
        return try decode(type, forKeys: [key], defaultValue: defaultValue, logError: logError)
    }

    func decode<O>(_ type: DualHashDictionary<O.Identifier, O>.Type,
                   forKeys keys: [Key],
                   defaultValue: DualHashDictionary<O.Identifier, O>? = nil,
                   logError: Bool) throws -> DualHashDictionary<O.Identifier, O> where O: Decodable, O: EntityIdentifiable {
        let key = try resolveKey(from: keys)
        if let defaultValue = defaultValue {
            return try decode(type, forKey: key, defaultValue: defaultValue, logError: logError) ?? defaultValue
        } else {
            return DualHashDictionary(try decode([FailableValue<O>].self, forKey: key).lazy.compactMap {
                guard let value = $0.value(logError: logError) else { return nil }
                return (value.identifier, value)
            })
        }
    }

    func decode<O>(_ type: DualHashDictionary<O.Identifier, O>.Type,
                   forKey key: Key,
                   defaultValue: DualHashDictionary<O.Identifier, O>? = nil,
                   logError: Bool) throws -> DualHashDictionary<O.Identifier, O>? where O: Decodable, O: EntityIdentifiable {
        return try decode(type, forKeys: [key], defaultValue: defaultValue, logError: logError)
    }

    func decode<O>(_ type: DualHashDictionary<O.Identifier, O>.Type,
                   forKeys keys: [Key],
                   defaultValue: DualHashDictionary<O.Identifier, O>? = nil,
                   logError: Bool) throws -> DualHashDictionary<O.Identifier, O>? where O: Decodable, O: EntityIdentifiable {
        let key = try resolveKey(from: keys)
        do {
            guard let values = try decodeIfPresent([FailableValue<O>].self, forKey: key) else {
                return defaultValue
            }
            return DualHashDictionary(values.lazy.compactMap {
                guard let value = $0.value(logError: logError) else { return nil }
                return (value.identifier, value)
            })
        } catch {
            if logError {
                let error = DecodingErrorWrapper(error)
                if let defaultValue = defaultValue {
                    error.log("\(KeyedDecodingContainer.self): Error while decoding, defaulting to \(defaultValue)")
                } else {
                    error.log("\(KeyedDecodingContainer.self): Error while decoding")
                }
            }
            return defaultValue
        }
    }

    // MARK: - PayloadType

    func decode<O>(_ type: O.Type, forKey key: Key, logError: Bool) throws -> O.PayloadType where O: Decodable, O: PayloadConvertable {
        return try decode(type, forKeys: [key], logError: logError)
    }

    func decode<O>(_ type: O.Type, forKeys keys: [Key], logError: Bool) throws -> O.PayloadType where O: Decodable, O: PayloadConvertable {
        let key = try resolveKey(from: keys)
        return try decode(O.self, forKey: key).rootPayload
    }

    func decode<O>(_ type: O.Type, forKey key: Key, logError: Bool) throws -> O.PayloadType? where O: Decodable, O: PayloadConvertable {
        return try decode(type, forKeys: [key], logError: logError)
    }

    func decode<O>(_ type: O.Type, forKeys keys: [Key], logError: Bool) throws -> O.PayloadType? where O: Decodable, O: PayloadConvertable {
        let key = try resolveKey(from: keys)
        do {
            return try decodeIfPresent(O.self, forKey: key)?.rootPayload
        } catch {
            if logError {
                DecodingErrorWrapper(error).log("\(KeyedDecodingContainer.self): Error while decoding, defaulting to nil")
            }
            return nil
        }
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKey key: Key, logError: Bool) throws -> AnySequence<O.PayloadType> where O: Decodable, O: PayloadConvertable {
        return try decodeSequence(type, forKeys: [key], logError: logError)
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKeys keys: [Key], logError: Bool) throws -> AnySequence<O.PayloadType> where O: Decodable, O: PayloadConvertable {
        let key = try resolveKey(from: keys)
        return try decode([FailableValue<O>].self, forKey: key).lazy.compactMap {
            $0.value(logError: logError)?.rootPayload
        }.any
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKey key: Key, logError: Bool) throws -> AnySequence<O.PayloadType>? where O: Decodable, O: PayloadConvertable {
        return try decodeSequence(type, forKeys: [key], logError: logError)
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKeys keys: [Key], logError: Bool) throws -> AnySequence<O.PayloadType>? where O: Decodable, O: PayloadConvertable {
        let key = try resolveKey(from: keys)
        do {
            guard let values = try decodeIfPresent([FailableValue<O>].self, forKey: key) else { return nil }
            return values.lazy.compactMap { $0.value(logError: logError)?.rootPayload }.any
        } catch {
            if logError {
                DecodingErrorWrapper(error).log("\(KeyedDecodingContainer.self): Error while decoding, defaulting to nil")
            }
            return nil
        }
    }

    // MARK: - PayloadRelationship & PayloadType

    func decode<O>(_ type: O.Type, forKey key: Key, logError: Bool) throws -> PayloadRelationship<O> where O: Decodable {
        return try decode(type, forKeys: [key], logError: logError)
    }

    func decode<O>(_ type: O.Type, forKeys keys: [Key], logError: Bool) throws -> PayloadRelationship<O> where O: Decodable {
        let key = try resolveKey(from: keys)
        return try decode(PayloadRelationship<O>.self, forKey: key)
    }

    func decode<O>(_ type: O.Type, forKey key: Key, logError: Bool) throws -> PayloadRelationship<O>? where O: Decodable {
        return try decode(type, forKeys: [key], logError: logError)
    }

    func decode<O>(_ type: O.Type, forKeys keys: [Key], logError: Bool) throws -> PayloadRelationship<O>? where O: Decodable {
        let key = try resolveKey(from: keys)
        do {
            return try decodeIfPresent(PayloadRelationship<O>.self, forKey: key)
        } catch {
            if logError {
                DecodingErrorWrapper(error).log("\(KeyedDecodingContainer.self): Error while decoding, defaulting to nil")
            }
            return nil
        }
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKey key: Key, logError: Bool) throws -> AnySequence<PayloadRelationship<O>> where O: Decodable {
        return try decodeSequence(type, forKeys: [key], logError: logError)
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKeys keys: [Key], logError: Bool) throws -> AnySequence<PayloadRelationship<O>> where O: Decodable {
        let key = try resolveKey(from: keys)
        return try decode([PayloadRelationship<O>].self, forKey: key).lazy.any
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKey key: Key, logError: Bool) throws -> AnySequence<PayloadRelationship<O>>? where O: Decodable {
        return try decodeSequence(type, forKeys: [key], logError: logError)
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKeys keys: [Key], logError: Bool) throws -> AnySequence<PayloadRelationship<O>>? where O: Decodable {
        let key = try resolveKey(from: keys)
        do {
            guard let values = try decodeIfPresent([PayloadRelationship<O>].self, forKey: key) else { return nil }
            return values.lazy.any
        } catch {
            if logError {
                DecodingErrorWrapper(error).log("\(KeyedDecodingContainer.self): Error while decoding, defaulting to nil")
            }
            return nil
        }
    }

    // MARK: NestedContainer

    func nestedContainer(forKeyChain keyChain: [Key]) throws -> KeyedDecodingContainer {
        guard let key = keyChain.first else { return self }
        return try nestedContainer(keyedBy: K.self, forKey: key).nestedContainer(forKeyChain: Array(keyChain.dropFirst()))
    }

    // MARK: - Time

    func decode(_ type: Seconds.Type, forKey key: Key, defaultValue: Double? = nil, logError: Bool) throws -> Seconds {
        return try decode(type, forKeys: [key], defaultValue: defaultValue, logError: logError)
    }

    func decode(_ type: Seconds.Type, forKeys keys: [Key], defaultValue: Double? = nil, logError: Bool) throws -> Seconds {
        let key = try resolveKey(from: keys)
        if let defaultValue = defaultValue {
            let defaultTime = Seconds(seconds: defaultValue)
            return try decode(type, forKey: key, defaultValue: defaultTime, logError: logError) ?? defaultTime
        } else {
            return try decode(Seconds.self, forKey: key)
        }
    }

    func decode(_ type: Milliseconds.Type, forKey key: Key, defaultValue: Double? = nil, logError: Bool) throws -> Milliseconds {
        return try decode(type, forKeys: [key], defaultValue: defaultValue, logError: logError)
    }

    func decode(_ type: Milliseconds.Type, forKeys keys: [Key], defaultValue: Double? = nil, logError: Bool) throws -> Milliseconds {
        let key = try resolveKey(from: keys)
        if let defaultValue = defaultValue {
            let defaultTime = Milliseconds(seconds: defaultValue / 1000)
            return try decode(type, forKey: key, defaultValue: defaultTime, logError: logError) ?? defaultTime
        } else {
            return try decode(Milliseconds.self, forKey: key)
        }
    }

    // MARK: - Lazy

    func decode<O>(_ type: O.Type, forKeys keys: [Key], defaultValue: O? = nil, logError: Bool) throws -> Lazy<O> where O: Decodable {
        let key = try resolveKey(from: keys)
        if contains(key) == false {
            return .unrequested
        } else if let value = try decodeIfPresent(Lazy<O>.self, forKey: key) {
            return value
        } else if let defaultValue = defaultValue {
            return .requested(defaultValue)
        } else {
            return try decode(Lazy<O>.self, forKey: key)
        }
    }

    func decode<O>(_ type: O?.Type, forKeys keys: [Key], defaultValue: O? = nil, logError: Bool) throws -> Lazy<O?> where O: Decodable {
        do {
            let key = try resolveKey(from: keys)
            if contains(key) == false {
                return .unrequested
            }
            let value = try decodeIfPresent(O.self, forKey: key)
            if value == nil, let defaultValue = defaultValue {
                return .requested(defaultValue)
            } else {
                return .requested(value)
            }
        } catch {
            return .unrequested
        }
    }

    func decode<O>(_ type: O.Type, forKeys keys: [Key], defaultValue: O? = nil, logError: Bool) throws -> Lazy<O?> where O: Decodable {
        return try decode(O?.self, forKeys: keys, defaultValue: defaultValue, logError: logError)
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKeys keys: [Key], defaultValue: [O]? = nil, logError: Bool) throws -> Lazy<AnySequence<O>> where O: Decodable {
        return try decode([O].self, forKeys: keys, defaultValue: defaultValue, logError: logError).lazyAny()
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKeys keys: [Key], defaultValue: [O]? = nil, logError: Bool) throws -> Lazy<AnySequence<O>?> where O: Decodable {
        return try decode([O]?.self, forKeys: keys, defaultValue: defaultValue, logError: logError).lazyAny()
    }

    func decode<O>(_ type: O.Type, forKeys keys: [Key], logError: Bool) throws -> Lazy<PayloadRelationship<O>> where O: Decodable {
        return try decode(PayloadRelationship<O>.self, forKeys: keys, defaultValue: nil, logError: logError)
    }

    func decode<O>(_ type: O.Type, forKeys keys: [Key], logError: Bool) throws -> Lazy<PayloadRelationship<O>?> where O: Decodable {
        return try decode(PayloadRelationship<O>?.self, forKeys: keys, defaultValue: nil, logError: logError)
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKeys keys: [Key], logError: Bool) throws -> Lazy<AnySequence<PayloadRelationship<O>>> where O: Decodable {
        return try decode([PayloadRelationship<O>].self, forKeys: keys, defaultValue: nil, logError: logError).lazyAny()
    }

    func decodeSequence<O>(_ type: AnySequence<O>.Type, forKeys keys: [Key], logError: Bool) throws -> Lazy<AnySequence<PayloadRelationship<O>>?> where O: Decodable {
        return try decode([PayloadRelationship<O>]?.self, forKeys: keys, defaultValue: nil, logError: logError).lazyAny()
    }
}

extension AnySequence: Codable where Element: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try container.decode([Element].self).any
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.array)
    }
}
