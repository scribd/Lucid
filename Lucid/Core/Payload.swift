//
//  Payload.swift
//  Lucid
//
//  Created by Théophane Rupin on 8/20/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

// MARK: - Identifiable

public protocol PayloadIdentifiable {

    associatedtype Identifier: EntityIdentifier

    var identifier: Identifier { get }
}

public protocol PayloadIdentifierDecodableKeyProvider: PayloadIdentifiable {
    static var identifierKey: String { get }
}

// MARK: - Convertable

public protocol PayloadConvertable {

    associatedtype PayloadType
    var rootPayload: PayloadType { get }

    associatedtype MetadataPayloadType
    var entityMetadata: MetadataPayloadType { get }
}

// MARK: - Relationship

public enum PayloadRelationship<P> where P: PayloadIdentifierDecodableKeyProvider {
    case identifier(P.Identifier)
    case value(P)

    public var identifier: P.Identifier {
        switch self {
        case .identifier(let identifier):
            return identifier
        case .value(let value):
            return value.identifier
        }
    }

    public var value: P? {
        switch self {
        case .identifier:
            return nil
        case .value(let value):
            return value
        }
    }
}

extension PayloadRelationship: PayloadIdentifiable where P: PayloadIdentifiable { }

// MARK: - FailableValue

public enum FailableValue<T> {

    case value(T)
    case error(Error)

    public func value(logError: Bool = true) -> T? {
        switch self {
        case .value(let value):
            return value
        case .error(let error):
            if logError {
                DecodingErrorWrapper(error).log("\(FailableValue.self): Error while decoding")
            }
            return nil
        }
    }
}

// MARK: - Extra

public enum Extra<T> {

    case requested(T)
    case unrequested
}

public extension Extra where T: PayloadIdentifiable {

    func identifier() -> Extra<T.Identifier> {
        switch self {
        case .requested(let payload):
            return .requested(payload.identifier)
        case .unrequested:
            return .unrequested
        }
    }
}

public extension Extra {

    var wasRequested: Bool {
        switch self {
        case .requested:
            return true
        case .unrequested:
            return false
        }
    }

    func merging(with updated: Extra) -> Extra {
        switch updated {
        case .requested:
            return updated
        case .unrequested:
            return self
        }
    }

    func identifier<P>() -> Extra<P.Identifier?> where P: PayloadIdentifiable, T == P? {
        switch self {
        case .requested(let payload):
            return .requested(payload?.identifier)
        case .unrequested:
            return .unrequested
        }
    }

    func identifier<R: RemoteIdentifier>(from entityIdentifier: R) -> Extra<R> {
        switch self {
        case .requested:
            return .requested(entityIdentifier)
        case .unrequested:
            return .unrequested
        }
    }

    func identifier<R: RemoteIdentifier>(from entityIdentifier: R) -> Extra<R?> {
        switch self {
        case .requested:
            return .requested(entityIdentifier)
        case .unrequested:
            return .unrequested
        }
    }

    func identifiers<P>() -> Extra<AnySequence<P.Identifier>> where P: PayloadIdentifiable, T == AnySequence<P> {
        switch self {
        case .requested(let payload):
            return .requested(payload.lazy.map { $0.identifier }.any)
        case .unrequested:
            return .unrequested
        }
    }

    func identifiers<P>() -> Extra<AnySequence<P.Identifier>?> where P: PayloadIdentifiable, T == AnySequence<P>? {
        switch self {
        case .requested(let payload):
            return .requested(payload?.lazy.map { $0.identifier }.any)
        case .unrequested:
            return .unrequested
        }
    }
}

public extension Extra {

    func extraValue(logError: Bool = false) -> T? {
        switch self {
        case .requested(let value):
            return value
        case .unrequested:
            if logError {
                Logger.log(.debug, "\(Extra.self): Attempting to access unrequested extra.")
            }
            return nil
        }
    }

    func extraValue<K>(logError: Bool = false) -> K? where T == K? {
        switch self {
        case .requested(.some(let value)):
            return value
        case .requested(.none):
            return nil
        case .unrequested:
            if logError {
                Logger.log(.debug, "\(Extra.self): Attempting to access unrequested extra.")
            }
            return nil
        }
    }
}

public extension Extra {

    func value(logError: Bool = true) -> T? {
        return extraValue(logError: logError)
    }

    func value<K>(logError: Bool = true) -> K? where T == K? {
        return extraValue(logError: logError)
    }

    static func ?? <K>(lhs: Extra<K?>, rhs: Extra<K?>) -> K? where T == K? {
        return lhs.value()?.flatMap({ $0 }) ?? rhs.value()?.flatMap({ $0 })
    }
}

extension Extra: Equatable where T: Equatable { }

// MARK: - Conversions to Array

public protocol ArrayConvertable {}

public extension ArrayConvertable {

    func values() -> AnySequence<Self> {
        return [self].lazy.any
    }
}

extension PayloadRelationship: ArrayConvertable where P: ArrayConvertable {

    public func values() -> AnySequence<P> {
        return (value.flatMap { [$0] } ?? []).lazy.any
    }
}

public extension Sequence where Element: ArrayConvertable {

    func values<O>() -> AnySequence<O> where O: PayloadIdentifiable, Element == PayloadRelationship<O> {
        return lazy.compactMap { $0.value }.any
    }

    func values<O>() -> AnySequence<O.Identifier> where O: PayloadIdentifiable, Element == PayloadRelationship<O> {
        return lazy.map { $0.identifier }.any
    }

    func values<O, P>() -> DualHashDictionary<O.Identifier, O> where
        O: EntityIdentifiable, Element == PayloadRelationship<P>,
        P: PayloadConvertable, P.MetadataPayloadType == O?, P: PayloadIdentifiable {

        return DualHashDictionary(lazy.compactMap {
            guard let value = $0.value?.entityMetadata else { return nil }
            return (value.identifier, value)
        })
    }
}

extension Array: ArrayConvertable where Element: ArrayConvertable {}
extension AnySequence: ArrayConvertable where Element: ArrayConvertable {}

public extension Optional where Wrapped: ArrayConvertable {

    func values<O>() -> AnySequence<O> where Wrapped: Sequence, Wrapped.Element == O {
        return self?.lazy.any ?? .empty
    }

    func values<O>() -> AnySequence<O> where O: PayloadIdentifiable, Wrapped: Sequence, Wrapped.Element == PayloadRelationship<O>, O: ArrayConvertable {
        return values().values()
    }

    func values<O>() -> AnySequence<O.Identifier> where O: PayloadIdentifiable, Wrapped: Sequence, Wrapped.Element == PayloadRelationship<O>, O: ArrayConvertable {
        return values().values()
    }

    func values() -> AnySequence<Wrapped> {
        return (flatMap { [$0] } ?? []).lazy.any
    }

    func values<O>() -> AnySequence<O> where O: PayloadIdentifiable, Wrapped == PayloadRelationship<O> {
        return values().lazy.compactMap { $0.value }.any
    }

    func values<O>() -> AnySequence<O.Identifier> where O: PayloadIdentifiable, Wrapped == PayloadRelationship<O> {
        return values().lazy.map { $0.identifier }.any
    }

    func values<O, P>() -> DualHashDictionary<O.Identifier, O>? where
        O: EntityIdentifiable, Wrapped: Sequence, Wrapped.Element == PayloadRelationship<P>,
        P: PayloadConvertable, P.MetadataPayloadType == O?, P: PayloadIdentifiable, P: ArrayConvertable {

        return self?.values()
    }
}
