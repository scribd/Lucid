//
//  Entity.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/21/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import AVFoundation
import UIKit
import CoreData

// MARK: - IdentifierValueType

public enum IdentifierValueType<LocalValueType, RemoteValueType>: DualHashable, Comparable where
    LocalValueType: Comparable,
    LocalValueType: Hashable,
    RemoteValueType: Comparable,
    RemoteValueType: Hashable {

    case remote(RemoteValueType, LocalValueType?)
    case local(LocalValueType)

    public var remoteValue: RemoteValueType? {
        switch self {
        case .remote(let value, _):
            return value
        case .local:
            return nil
        }
    }

    public var localValue: LocalValueType? {
        switch self {
        case .remote(_, let value):
            return value
        case .local(let value):
            return value
        }
    }

    public mutating func merge(with otherIdentifier: IdentifierValueType<LocalValueType, RemoteValueType>) {

        if let localValue = localValue, let otherLocalValue = otherIdentifier.localValue, localValue != otherLocalValue {
            Logger.log(.error, "\(IdentifierValueType.self): Cannot merge identifiers with two different local values: \(self) vs \(otherIdentifier).", assert: true)
            return
        }
        if let remoteValue = remoteValue, let otherRemoteValue = otherIdentifier.remoteValue, remoteValue != otherRemoteValue {
            Logger.log(.error, "\(IdentifierValueType.self): Cannot merge identifiers with two different remote values: \(self) vs \(otherIdentifier).", assert: true)
            return
        }

        let localValue = self.localValue ?? otherIdentifier.localValue
        if let remoteValue = self.remoteValue ?? otherIdentifier.remoteValue {
            self = .remote(remoteValue, localValue)
        } else if let localValue = localValue {
            self = .local(localValue)
        } else {
            Logger.log(.error, "\(IdentifierValueType.self): Cannot merge empty identifiers: \(self) vs \(otherIdentifier).", assert: true)
            return
        }
    }
}

public extension IdentifierValueType where RemoteValueType: CoreDataValueType, LocalValueType: CoreDataValueType {

    var coreDataIdentifierValue: CoreDataRelationshipIdentifierValueType {
        switch self {
        case .remote(let remoteValue, let localValue):
            return .remote(remoteValue, localValue)
        case .local(let localValue):
            return .local(localValue)
        }
    }
}

public extension CoreDataIdentifier {
    var coreDataIdentifierValue: CoreDataRelationshipIdentifierValueType {
        return identifier.value.coreDataIdentifierValue
    }
}

// MARK: - Identifiable

/// Identifier which can be represented by a raw value.
public protocol RawIdentifiable: Comparable {

    /// Local raw value type of the identifier.
    associatedtype LocalValueType: Hashable, Comparable, Codable

    /// Remote raw value type of the identifier.
    associatedtype RemoteValueType: Hashable, Comparable, Codable

    /// Raw value of the identifier.
    var value: IdentifierValueType<LocalValueType, RemoteValueType> { get }
}

extension RawIdentifiable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.value < rhs.value
    }
}

// MARK: - Identifier

public protocol IdentifierTypeIDConvertible {

    /// Type of the entity this identifier comes from.
    var identifierTypeID: String { get }
}

public protocol EntityIdentifierTypeIDConvertible {

    /// Type taken by identifiers built from this type.
    static var identifierTypeID: String { get }
}

public protocol EntityTypeUIDConvertible {

    /// Unique type of an entity.
    static var entityTypeUID: String { get }

    /// Unique type of an entity.
    var entityTypeUID: String { get }
}

extension EntityTypeUIDConvertible {

    public var entityTypeUID: String {
        return Self.entityTypeUID
    }
}

/// Representation of an entity's identifier.
///
/// - Note: Entity's identifiers are mostly used for storing into key value caches like the `EndpointResultPayload` caches.
public protocol EntityIdentifier: IdentifierTypeIDConvertible, EntityTypeUIDConvertible, DualHashable, Comparable, Codable, CustomStringConvertible {

    /// State of synchronization of identified entity with the remotes. Defaults to nil for non remote identifiers.
    var remoteSynchronizationState: RemoteSynchronizationState? { get }
}

extension EntityIdentifier {

    public var remoteSynchronizationState: RemoteSynchronizationState? {
        return nil
    }
}

// MARK: - RemoteIdentifier

/// Identifier which can be used to build requests to a remote store.
public protocol RemoteIdentifier: RawIdentifiable, EntityIdentifier where LocalValueType: CustomStringConvertible, RemoteValueType: CustomStringConvertible {

    /// State of synchronization of identified entity with the remotes. Defaults to nil for non remote identifiers.
    var _remoteSynchronizationState: PropertyBox<RemoteSynchronizationState> { get }
}

extension RemoteIdentifier {

    public var remoteSynchronizationState: RemoteSynchronizationState? {
        return _remoteSynchronizationState.value
    }
}

// MARK: - CoreDataIdentifier

/// Identifier which can be used as a `CoreData` identifier.
public protocol CoreDataIdentifier: RawIdentifiable, EntityIdentifier, PayloadIdentifiable where
    LocalValueType: CustomStringConvertible,
    LocalValueType: CoreDataPrimitiveValue,
    LocalValueType: CoreDataValueType,
    RemoteValueType: CustomStringConvertible,
    RemoteValueType: CoreDataPrimitiveValue,
    RemoteValueType: CoreDataValueType {

    /// Key used to select the local identifier in a predicate.
    static var localPredicateString: String { get }

    /// Key used to select the remote identifier in a predicate.
    static var remotePredicateString: String { get }

    /// Key used to select the entity type ID in a predicate.
    static var identifierTypeIDPredicateString: String { get }

    init(value: IdentifierValueType<LocalValueType, RemoteValueType>,
         identifierTypeID: String?,
         remoteSynchronizationState: RemoteSynchronizationState?)
}

/// Value type which can be used to search in Core Data.
public protocol CoreDataValueType {

    /// Value used to search in a predicate.
    var predicateValue: Any { get }
}

/// Value type which used to match relationships in Core Data.
public enum CoreDataRelationshipIdentifierValueType {
    case remote(CoreDataValueType, CoreDataValueType?)
    case local(CoreDataValueType)
    case none

    public var remoteValue: CoreDataValueType? {
        switch self {
        case .remote(let value, _):
            return value
        case .local,
             .none:
            return nil
        }
    }

    public var localValue: CoreDataValueType? {
        switch self {
        case .remote(_, .some(let value)),
             .local(let value):
            return value
        case .remote,
             .none:
            return nil
        }
    }
}

public extension CoreDataIdentifier {

    var identifier: Self {
        return self
    }

    static var localPredicateString: String {
        return "__identifier"
    }

    static var remotePredicateString: String {
        return "_identifier"
    }

    static var identifierTypeIDPredicateString: String {
        return LucidConfiguration.useCoreDataLegacyNaming ? "__typeUID" : "__type_uid"
    }
}

extension Int: CoreDataValueType {
    public var predicateValue: Any {
        return self as NSNumber
    }
}

extension String: CoreDataValueType {
    public var predicateValue: Any {
        return self
    }
}

// MARK: - RelationshipIdentifier

public protocol AnyRelationshipIdentifierConvertible: IdentifierTypeIDConvertible, EntityTypeUIDConvertible, CustomStringConvertible {

    func toRelationshipID<ID>() -> ID? where ID: EntityIdentifier
}

public protocol AnyRelationshipIdentifier: AnyRelationshipIdentifierConvertible, DualHashable, Comparable {}

public protocol AnyCoreDataRelationshipIdentifier: AnyRelationshipIdentifier {

    var coreDataIdentifierValue: CoreDataRelationshipIdentifierValueType { get }
}

// MARK: - Subtype

public protocol AnySubtype: Hashable, Comparable {}

public protocol AnyCoreDataSubtype: AnySubtype {

    /// Converts to a value which can be used in a predicate.
    var predicateValue: Any? { get }
}

// MARK: - Entity

public protocol EntityIdentifiable {

    /// Entity's identifier type.
    associatedtype Identifier: EntityIdentifier

    /// Entity's identifier used for cache/storage indexation.
    var identifier: Identifier { get }
}

public protocol EntityIndexing {

    /// Property descriptions which can be used to perform search queries.
    associatedtype IndexName: Hashable, QueryResultConvertible

    /// Identifier type used for referencing any type of relationships.
    associatedtype RelationshipIdentifier: AnyRelationshipIdentifier

    /// Type used for referencing any type of subtypes.
    associatedtype Subtype: AnySubtype

    /// Retrieve the entity's relationships' index.
    var entityRelationshipIndices: [IndexName] { get }

    /// Retrieve the entity's relationships' type UID.
    var entityRelationshipEntityTypeUIDs: [String] { get }

    /// Retrieve an index's associated value.
    func entityIndexValue(for indexName: IndexName) -> EntityIndexValue<RelationshipIdentifier, Subtype>
}

/// An `Entity` represents a type of data served by the backend.
///
/// - Note: This is the central type of the `Lucid` architecture. Every `Store` and `CoreManager` are
///         derived from an `Entity` type.
public protocol Entity: Equatable, EntityIdentifiable, EntityIdentifierTypeIDConvertible, EntityIndexing {

    /// Entity's metadata type
    associatedtype Metadata: EntityMetadata

    /// Any endpoint type used for parsing responses' body.
    associatedtype ResultPayload: ResultPayloadConvertible

    /// Contextual information a store could need for retrieving the entities' data.
    associatedtype QueryContext: Equatable
}

public protocol EntityConvertible: CustomStringConvertible {

    init?<E>(_ entity: E) where E: Entity
}

// MARK: - MutableEntity

public protocol MutableEntity: Entity {

    /// Merge the remote identifier received from the server with the locally created identifier.
    func merge(identifier: Identifier)
}

// MARK: - EndpointResultPayloadRepresentable

public protocol AnyResultPayloadConvertible {

    /// Metadata type representing the singular endpoint
    var metadata: EndpointResultMetadata { get }
}

/// Type convertible to any type of endpoint payload.
public protocol ResultPayloadConvertible: AnyResultPayloadConvertible {

    /// Type representing any type of endpoint.
    associatedtype Endpoint

    /// Init from JSON data.
    ///
    /// - Parameters:
    ///     - data: payload JSON data representation.
    ///     - endpoint: the endpoint to decode.
    ///     - decoder: JSON decoder which should be used to decode the data.
    init(from data: Data, endpoint: Endpoint, decoder: JSONDecoder) throws

    func getEntity<E>(for identifier: E.Identifier) -> E? where E: Entity

    func allEntities<E>() -> AnySequence<E> where E: Entity
}

// MARK: - LocalEntity

public protocol LocalEntity: Entity {

    /// Determine if the entity is sufficiently different from the locally stored vesion. If `false`, the CacheStore will
    /// ignore the change on a `set` action.
    func shouldOverwrite(with updated: Self) -> Bool

    /// Merge two entities and return the result. New properties overwrite existing ones, except for unrequested Extras.
    func merging(_ updated: Self) -> Self
}

extension LocalEntity {

    public func shouldOverwrite(with updated: Self) -> Bool {
        return updated != self
    }
}

// MARK: - RemoteEntity

/// An `Entity` which can be used with a `RemoteStore`.
public protocol RemoteEntity: Entity where Identifier: RemoteIdentifier {

    /// Build a read request configuration associated to the combination CRUD method / application context.
    ///
    /// - Parameter remotePath: CRUD method + parameters.
    /// - Returns: Request configuration to reach the remote's endpoint.
    static func requestConfig(for remotePath: RemotePath<Self>) -> APIRequestConfig?

    /// Build a payload containing the endpoint's served data. The type of payload to build is chosen based on `remotePath`.
    ///
    /// - Parameter remotePath: CRUD method + parameters.
    /// - Returns: The endpoint the `remotePath` is supported, nil otherwise.
    static func endpoint(for remotePath: RemotePath<Self>) -> ResultPayload.Endpoint?
}

public extension RemoteEntity {

    static func requestConfig(for remotePath: RemotePath<Self>) -> APIRequestConfig? {
        return nil
    }

    static func endpoint(for remotePath: RemotePath<Self>) -> ResultPayload.Endpoint? {
        return nil
    }
}

extension RemoteEntity {

    static func unwrappedEndpoint(for remotePath: RemotePath<Self>) throws -> ResultPayload.Endpoint {
        guard let value = endpoint(for: remotePath) else {
            Logger.log(.error, "\(Self.self) has not implemented the RemoteEntity function \(#function). Override and set this value.", assert: true)
            throw StoreError.invalidContext
        }
        return value
    }
}
// MARK: - Synchronization State

/// Synchronization status with the remotes.
///
/// - Warning: Renaming any of these cases requires a hard core data migration.
public enum RemoteSynchronizationState: String {
    case outOfSync // Not sent to the remotes yet.
    case pending // Sent to the remotes but no response was received.
    case synced // Sent to the remotes and a response has been received.
}

// MARK: - RemotePath

/// Represent a CRUD method with its parameters.
public enum RemotePath<E>: Equatable where E: RemoteEntity {
    case get(E.Identifier)
    case search(Query<E>)
    case set(RemoteSetPath<E>)
    case remove(E.Identifier)
    case removeAll(Query<E>)

    public func identifier<ID>() -> ID? where ID: RemoteIdentifier, ID == E.Identifier {
        switch self {
        case .get(let identifier),
             .remove(let identifier):
            return identifier

        case .set(let path):
            return path.identifier()

        case .removeAll,
             .search:
            return nil
        }
    }
}

/// Represent CRUD options for a set action
public enum RemoteSetPath<E>: Equatable where E: Entity {
    case create(E)
    case update(E)

    public func identifier<ID>() -> ID? where ID: RemoteIdentifier, ID == E.Identifier {
        switch self {
        case .create(let entity),
             .update(let entity):
            return entity.identifier
        }
    }
}

// MARK: - CoreDataEntity

/// An `Entity` which can be stored in `CoreData`.
public protocol CoreDataEntity: LocalEntity where IndexName: CoreDataIndexName, Identifier: CoreDataIdentifier, Subtype: AnyCoreDataSubtype, RelationshipIdentifier: AnyCoreDataRelationshipIdentifier {

    /// Associated type managed by `CoreData`.
    associatedtype CoreDataObject: NSManagedObject

    /// Convert an associated managed object to an entity.
    ///
    /// - Parameters:
    ///     - coreDataObject: Managed object to convert.
    /// - Returns: An entity if convertion succeeded, nil otherwise.
    static func entity(from coreDataObject: CoreDataObject) -> Self?

    /// Merge an associated managed object into an entity.
    ///
    /// - Parameters: coreDataEntity: Managed object to update with this entity's data.
    func merge(into coreDataEntity: CoreDataObject)
}

// MARK: - VoidEntityIdentifier

/// A void type to represent an absence of identifier.
public struct VoidEntityIdentifier: RemoteIdentifier, CoreDataIdentifier {

    public let value: IdentifierValueType<Int, Int> = .local(0)

    public typealias LocalValueType = Int
    public typealias RemoteValueType = Int

    public static var entityTypeUID = "void"

    public let identifierTypeID = "void"

    public let _remoteSynchronizationState: PropertyBox<RemoteSynchronizationState>

    public init(remoteSynchronizationState: RemoteSynchronizationState = .synced) {
        _remoteSynchronizationState = PropertyBox<RemoteSynchronizationState>(remoteSynchronizationState, atomic: true)
    }

    public static func < (lhs: VoidEntityIdentifier, rhs: VoidEntityIdentifier) -> Bool { return false }

    public let description = "\(VoidEntityIdentifier.self)"

    public func hash(into hasher: inout DualHasher) {
        // no-op
    }

    public func encode(to encoder: Encoder) throws {
        // no-op
    }

    public init(value: IdentifierValueType<Int, Int>,
                identifierTypeID: String?,
                remoteSynchronizationState: RemoteSynchronizationState?) {
        self.init(remoteSynchronizationState: .synced)
    }

    public init(from decoder: Decoder) throws {
        _remoteSynchronizationState = PropertyBox<RemoteSynchronizationState>(.synced, atomic: true)
    }
}

// MARK: - CoreDataIndexName

/// `IndexName` which can be used to search in core data.
public protocol CoreDataIndexName: Hashable {

    /// Key used to select a regular index in a predicate
    var predicateString: String { get }

    /// True if the index name correspond with a one to one relationship.
    var isOneToOneRelationship: Bool { get }

    /// Key used to select a local relationship index in a predicate.
    ///
    /// - Note:
    ///     - Only called if `isOneToOneRelationship` is true.
    ///     - Default imlementation returns `"_" + predicateString`.
    var localRelationshipPredicateString: String { get }

    /// Key used to select a remote relationship index in a predicate.
    ///
    /// - Note:
    ///     - Only called if `isOneToOneRelationship` is true.
    ///     - Default imlementation returns `predicateString`.
    var remoteRelationshipPredicateString: String { get }

    /// Key used to select a relationship ID type UID in a predicate.
    var identifierTypeIDRelationshipPredicateString: String? { get }
}

public extension CoreDataIndexName {

    var localRelationshipPredicateString: String {
        return "_\(predicateString)"
    }

    var remoteRelationshipPredicateString: String {
        return predicateString
    }
}

/// An `Entity` representing a batch of homogeneous `Object`s.
public protocol BatchEntity: RemoteEntity where Identifier == VoidEntityIdentifier, IndexName == VoidIndexName {

    /// Associated type to be batched
    associatedtype BatchableObject

    /// Return the batch
    var objects: [BatchableObject] { get }

    init(objects: [BatchableObject])
}

// MARK: - VoidIndexName

/// A void type to represent an absence of index.
public struct VoidIndexName: Hashable, QueryResultConvertible {

    public let requestValue: String = String()
}

public extension Entity where IndexName == VoidIndexName {

    func entityIndexValue(for indexName: IndexName) -> EntityIndexValue<RelationshipIdentifier, Subtype> {
        return .void
    }

    var entityRelationshipIndices: [IndexName] {
        return []
    }

    var entityRelationshipEntityTypeUIDs: [String] {
        return []
    }
}

extension VoidIndexName: CoreDataIndexName {

    public var predicateString: String {
        return String()
    }

    public var isOneToOneRelationship: Bool {
        return false
    }

    public var identifierTypeIDRelationshipPredicateString: Optional<String> {
        return nil
    }
}

// MARK: - QueryResultConvertible

public protocol QueryResultConvertible {
    var requestValue: String { get }
}

// MARK: - VoidRelationshipIdentifier

/// A void type to represent an absence of relationship identifier.
public struct VoidRelationshipIdentifier: AnyRelationshipIdentifier {
    public func toRelationshipID<ID>() -> ID? where ID: EntityIdentifier {
        return nil
    }

    public static func < (lhs: VoidRelationshipIdentifier, rhs: VoidRelationshipIdentifier) -> Bool {
        return false
    }

    public func hash(into hasher: inout DualHasher) {
        // no-op
    }

    public let identifierTypeID = "void"

    public static let entityTypeUID = "void"

    public let description = "\(VoidRelationshipIdentifier.self)"
}

// MARK: - VoidSubtype

/// A void type to represent an absence of subtype.
public struct VoidSubtype: AnyCoreDataSubtype, Comparable {
    public var predicateValue: Any? {
        return nil
    }

    public static func < (lhs: VoidSubtype, rhs: VoidSubtype) -> Bool {
        return false
    }
}

// MARK: - VoidRequestSupport

public struct VoidRequestSupport: Hashable { }

// MARK: - Comparable

extension IdentifierValueType {

    public static func < (lhs: IdentifierValueType<LocalValueType, RemoteValueType>, rhs: IdentifierValueType<LocalValueType, RemoteValueType>) -> Bool {
        switch (lhs, rhs) {
        case (.remote(let lhs, _), .remote(let rhs, _)):
            return lhs < rhs
        case (.local(let lhs), .local(let rhs)),
             (.remote(_, .some(let lhs)), .local(let rhs)),
             (.local(let lhs), .remote(_, .some(let rhs))):
            return lhs < rhs
        case (.local, .remote):
            return false
        case (.remote, .local):
            return true
        }
    }
}

extension IdentifierValueType where LocalValueType == RemoteValueType {

    public static func < (lhs: IdentifierValueType<LocalValueType, RemoteValueType>, rhs: IdentifierValueType<LocalValueType, RemoteValueType>) -> Bool {
        switch (lhs, rhs) {
        case (.remote(let lhs, _), .remote(let rhs, _)):
            return lhs < rhs
        case (.local(let lhs), .local(let rhs)),
             (.remote(_, .some(let lhs)), .local(let rhs)),
             (.local(let lhs), .remote(_, .some(let rhs))):
            return lhs < rhs
        case (.local(let lhs), .remote(let rhs, nil)):
            return lhs < rhs
        case (.remote(let lhs, nil), .local(let rhs)):
            return lhs < rhs
        }
    }
}

// MARK: - Equatable

extension IdentifierValueType {

    public static func == (_ lhs: IdentifierValueType<LocalValueType, RemoteValueType>, _ rhs: IdentifierValueType<LocalValueType, RemoteValueType>) -> Bool {
        switch (lhs, rhs) {
        case (.remote(let lhs, _), .remote(let rhs, _)):
            return lhs == rhs
        case (.local(let lhs), .local(let rhs)),
             (.remote(_, .some(let lhs)), .local(let rhs)),
             (.local(let lhs), .remote(_, .some(let rhs))):
            return lhs == rhs
        case (.local, _),
             (.remote, _):
            return false
        }
    }
}

// MARK: - DualHashable

extension IdentifierValueType {

    public func hash(into hasher: inout DualHasher) {
        switch self {
        case .remote(let remoteValue, .some(let localValue)):
            hasher.combine(firstValue: localValue)
            hasher.combine(secondValue: remoteValue)
        case .remote(let value, _):
            hasher.combine(secondValue: value)
        case .local(let value):
            hasher.combine(firstValue: value)
        }
    }
}

// MARK: - Codable

extension IdentifierValueType: Codable where LocalValueType: Codable, RemoteValueType: Codable {

    private enum Keys: String, CodingKey {
        case local
        case remote
    }

    public init(from decoder: Decoder) throws {
        switch decoder.context {
        case .payload:
            let container = try decoder.singleValueContainer()
            self = .remote(try container.decode(RemoteValueType.self), nil)

        case .coreDataRelationship,
             .clientQueueRequest:
            let container = try decoder.container(keyedBy: Keys.self)
            if let localValue = try container.decodeIfPresent(LocalValueType.self, forKey: .local) {
                self = .local(localValue)
            } else if let remoteValue = try container.decodeIfPresent(RemoteValueType.self, forKey: .remote) {
                self = .remote(remoteValue, try container.decodeIfPresent(LocalValueType.self, forKey: .local))
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "No remote/local value could be found."))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch encoder.context {
        case .payload:
            var container = encoder.singleValueContainer()
            try container.encode(remoteValue)

        case .coreDataRelationship,
             .clientQueueRequest:
            var container = encoder.container(keyedBy: Keys.self)
            switch self {
            case .local(let value):
                try container.encode(value, forKey: .local)
            case .remote(let remoteValue, let localValue):
                try container.encode(remoteValue, forKey: .remote)
                try container.encode(localValue, forKey: .local)
            }
        }
    }
}

// MARK: - CustomStringConvertible

extension IdentifierValueType: CustomStringConvertible where LocalValueType: CustomStringConvertible, RemoteValueType: CustomStringConvertible {

    public var description: String {
        switch self {
        case .local(let value):
            return "local:\(value.description)"
        case .remote(let value, let local):
            return "remote:\(value.description)\(local.flatMap { "|local:\($0)" } ?? String())"
        }
    }
}

// MARK: - EntityIdentifierCodingKeys

public enum EntityIdentifierCodingKeys: String, CodingKey {
    case value
    case identifierTypeID = "entityTypeUID" // former key was named `entityTypeUID`. Do not alter unless handled by a local storage migration.
}
