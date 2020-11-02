//
// Genre.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid
import CoreData

// MARK: - Identifier

public final class GenreIdentifier: Codable, CoreDataIdentifier, RemoteIdentifier {

    public typealias LocalValueType = String
    public typealias RemoteValueType = Int

    public let _remoteSynchronizationState: PropertyBox<RemoteSynchronizationState>

    fileprivate let property: PropertyBox<IdentifierValueType<String, Int>>
    public var value: IdentifierValueType<String, Int> {
        return property.value
    }

    public static let entityTypeUID = "genre"
    public let identifierTypeID: String

    public init(from decoder: Decoder) throws {
        _remoteSynchronizationState = PropertyBox(.synced, atomic: false)
        switch decoder.context {
        case .payload, .clientQueueRequest:
            let container = try decoder.singleValueContainer()
            property = PropertyBox(try container.decode(IdentifierValueType<String, Int>.self), atomic: false)
            identifierTypeID = Genre.identifierTypeID
        case .coreDataRelationship:
            let container = try decoder.container(keyedBy: EntityIdentifierCodingKeys.self)
            property = PropertyBox(
                try container.decode(IdentifierValueType<String, Int>.self, forKey: .value),
                atomic: false
            )
            identifierTypeID = try container.decode(String.self, forKey: .identifierTypeID)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch encoder.context {
        case .payload, .clientQueueRequest:
            var container = encoder.singleValueContainer()
            try container.encode(property.value)
        case .coreDataRelationship:
            var container = encoder.container(keyedBy: EntityIdentifierCodingKeys.self)
            try container.encode(property.value, forKey: .value)
            try container.encode(identifierTypeID, forKey: .identifierTypeID)
        }
    }

    public convenience init(value: IdentifierValueType<String, Int>,
                            identifierTypeID: Optional<String> = nil,
                            remoteSynchronizationState: Optional<RemoteSynchronizationState> = nil) {
        self.init(
            value: value,
            identifierTypeID: identifierTypeID,
            remoteSynchronizationState: remoteSynchronizationState ?? .synced
        )
    }

    public init(value: IdentifierValueType<String, Int>,
                identifierTypeID: Optional<String>,
                remoteSynchronizationState: RemoteSynchronizationState) {
        property = PropertyBox(value, atomic: false)
        self.identifierTypeID = identifierTypeID ?? Genre.identifierTypeID
        self._remoteSynchronizationState = PropertyBox(remoteSynchronizationState, atomic: false)
    }

    public static func == (_ lhs: GenreIdentifier,
                           _ rhs: GenreIdentifier) -> Bool { return lhs.value == rhs.value && lhs.identifierTypeID == rhs.identifierTypeID }

    public func hash(into hasher: inout DualHasher) {
        hasher.combine(value)
        hasher.combine(identifierTypeID)
    }

    public var description: String {
        return "\(identifierTypeID):\(value.description)"
    }
}

// MARK: - Identifiable

public protocol GenreIdentifiable {
    var genreIdentifier: GenreIdentifier { get }
}

extension GenreIdentifier: GenreIdentifiable {
    public var genreIdentifier: GenreIdentifier {
        return self
    }
}

// MARK: - Genre

public final class Genre: Codable {

    public typealias Metadata = VoidMetadata
    public typealias ResultPayload = EndpointResultPayload
    public typealias RelationshipIdentifier = EntityRelationshipIdentifier
    public typealias Subtype = EntitySubtype
    public typealias QueryContext = Never
    public typealias RelationshipIndexName = VoidRelationshipIndexName<AppAnyEntity>

    // IdentifierTypeID
    public static let identifierTypeID = "genre"

    // identifier
    public let identifier: GenreIdentifier

    // properties
    public let name: String

    init(identifier: GenreIdentifiable,
         name: String) {

        self.identifier = identifier.genreIdentifier
        self.name = name
    }
}

// MARK: - GenrePayload Initializer

extension Genre {
    convenience init(payload: GenrePayload) { self.init(identifier: payload.identifier, name: payload.name) }
}

// MARK: - LocalEntiy, RemoteEntity

extension Genre: LocalEntity, RemoteEntity {

    public func entityIndexValue(for indexName: GenreIndexName) -> EntityIndexValue<EntityRelationshipIdentifier, EntitySubtype> {
        switch indexName {
        case .name:
            return .string(name)
        }
    }

    public var entityRelationshipIndices: Array<GenreIndexName> {
        return []
    }

    public static func == (lhs: Genre,
                           rhs: Genre) -> Bool {
        guard lhs.identifier == rhs.identifier else { return false }
        guard lhs.name == rhs.name else { return false }
        return true
    }
}

// MARK: - CoreDataIndexName

extension GenreIndexName: CoreDataIndexName {

    public var predicateString: String {
        switch self {
        case .name:
            return "_name"
        }
    }

    public var isOneToOneRelationship: Bool {
        switch self {
        case .name:
            return false
        }
    }

    public var identifierTypeIDRelationshipPredicateString: Optional<String> {
        switch self {
        case .name:
            return nil
        }
    }
}

// MARK: - CoreDataEntity

extension Genre: CoreDataEntity {

    public static func entity(from coreDataEntity: ManagedGenre_1_0_0) -> Optional<Genre> {
        do {
            return try Genre(coreDataEntity: coreDataEntity)
        } catch {
            Logger.log(.error, "\(Genre.self): \(error)", domain: "Lucid", assert: true)
            return nil
        }
    }

    public func merge(into coreDataEntity: ManagedGenre_1_0_0) {
        coreDataEntity.setProperty(GenreIdentifier.remotePredicateString, value: identifier.remoteCoreDataValue())
        coreDataEntity.setProperty(GenreIdentifier.localPredicateString, value: identifier.localCoreDataValue())
        coreDataEntity.__type_uid = identifier.identifierTypeID
        coreDataEntity._remote_synchronization_state = identifier._remoteSynchronizationState.value.coreDataValue()
        coreDataEntity._name = name.coreDataValue()
    }

    private convenience init(coreDataEntity: ManagedGenre_1_0_0) throws {
        self.init(
            identifier: try coreDataEntity.identifierValueType(
                GenreIdentifier.self,
                identifierTypeID: coreDataEntity.__type_uid,
                remoteSynchronizationState: coreDataEntity._remote_synchronization_state?.synchronizationStateValue
            ),
            name: try coreDataEntity._name.stringValue(propertyName: "_name")
        )
    }
}

// MARK: - Cross Entities CoreData Conversion Utils

extension Data {
    func genreArrayValue() -> Optional<AnySequence<GenreIdentifier>> {
        guard let values: AnySequence<IdentifierValueType<String, Int>> = identifierValueTypeArrayValue(GenreIdentifier.self) else {
            return nil
        }
        return values.lazy.map { GenreIdentifier(value: $0) }.any
    }
}

extension Optional where Wrapped == Data {
    func genreArrayValue(propertyName: String) throws -> AnySequence<GenreIdentifier> {
        guard let values = self?.genreArrayValue() else {
            throw CoreDataConversionError.corruptedProperty(name: propertyName)
        }
        return values
    }

    func genreArrayValue() -> Optional<AnySequence<GenreIdentifier>> { return self?.genreArrayValue() }
}

// MARK: - Entity Merging

extension Genre {
    public func merging(_ updated: Genre) -> Genre { return updated }
}

// MARK: - IndexName

public enum GenreIndexName {
    case name
}

extension GenreIndexName: QueryResultConvertible {
    public var requestValue: String {
        switch self {
        case .name:
            return "name"
        }
    }
}
