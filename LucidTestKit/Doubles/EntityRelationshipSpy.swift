//
//  EntityRelationshipSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 8/7/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

#if LUCID_REACTIVE_KIT
import Lucid_ReactiveKit
#else
import Lucid
#endif

// MARK: - EntityRelationshipSpy

public struct EntityRelationshipSpyPayload: Codable {
    public let title: String
}

public final class EntityRelationshipSpyIdentifier: RemoteIdentifier, CoreDataIdentifier, AnyCoreDataRelationshipIdentifier {

    public typealias RemoteValueType = Int
    public typealias LocalValueType = String

    public let _remoteSynchronizationState: PropertyBox<RemoteSynchronizationState>

    private let property: PropertyBox<IdentifierValueType<String, Int>>
    public var value: IdentifierValueType<String, Int> {
        return property.value
    }

    public static let entityTypeUID = "entity_relationship_spy"
    public let identifierTypeID: String

    public init(value: IdentifierValueType<String, Int>,
                identifierTypeID: String? = nil,
                remoteSynchronizationState: RemoteSynchronizationState? = nil) {
        self._remoteSynchronizationState = PropertyBox(remoteSynchronizationState ?? .synced, atomic: true)
        self.identifierTypeID = identifierTypeID ?? EntityRelationshipSpy.identifierTypeID
        property = PropertyBox(value, atomic: true)
    }

    public static func < (lhs: EntityRelationshipSpyIdentifier, rhs: EntityRelationshipSpyIdentifier) -> Bool {
        return lhs.value < rhs.value
    }

    public static func == (_ lhs: EntityRelationshipSpyIdentifier, _ rhs: EntityRelationshipSpyIdentifier) -> Bool {
        return lhs.value == rhs.value && lhs.identifierTypeID == rhs.identifierTypeID
    }

    public func hash(into hasher: inout DualHasher) {
        hasher.combine(value)
        hasher.combine(identifierTypeID)
    }

    public func update(with newValue: EntityRelationshipSpyIdentifier) {
        property.value.merge(with: newValue.value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(property.value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        property = PropertyBox(try container.decode(IdentifierValueType<String, Int>.self), atomic: true)
        _remoteSynchronizationState = PropertyBox(.synced, atomic: true)
        identifierTypeID = EntityRelationshipSpy.identifierTypeID
    }

    public var description: String {
        return "\(EntityRelationshipSpyIdentifier.self):\(identifierTypeID):\(value.description)"
    }

    public var coreDataIdentifierValue: CoreDataRelationshipIdentifierValueType {
        return value.coreDataIdentifierValue
    }

    public func toRelationshipID<ID>() -> Optional<ID> where ID: EntityIdentifier {
        return self as? ID
    }
}

public enum EntityRelationshipSpyIndexName {
    case title
    case relationships
}

extension EntityRelationshipSpyIndexName: CoreDataIndexName {

    public var predicateString: String {
        switch self {
        case .title:
            return "_title"
        case .relationships:
            return "_relationships"
        }
    }

    public var isOneToOneRelationship: Bool {
        switch self {
        case .title:
            return false
        case .relationships:
            return false
        }
    }

    public var identifierTypeIDRelationshipPredicateString: String? {
        switch self {
        case .title,
             .relationships:
            return nil
        }
    }
}

public final class EntityRelationshipEndpointResultPayloadSpy: ResultPayloadConvertible {

    public typealias Endpoint = Int

    private let data: Data?

    private let endpoint: Endpoint?

    private let decoder: JSONDecoder?

    public var stubEntities: [EntityRelationshipSpy]?

    public init(stubEntities: [EntityRelationshipSpy]) {
        self.data = nil
        self.endpoint = nil
        self.decoder = nil
        self.stubEntities = stubEntities
    }

    public init(from data: Data,
                endpoint: Endpoint,
                decoder: JSONDecoder) throws {
        self.data = data
        self.endpoint = endpoint
        self.decoder = decoder
    }

    public var metadata: EndpointResultMetadata {
        return .empty
    }

    public func getEntity<E>(for identifier: E.Identifier) -> E? where E: Entity {
        if identifier is EntityRelationshipSpyIdentifier {
            return stubEntities?.first as? E
        }

        return nil
    }

    public func allEntities<E>() -> AnySequence<E> where E: Entity {
        if E.self is EntityRelationshipSpy.Type {
            return stubEntities?.any as? AnySequence<E> ?? [].any
        }

        return [].any
    }
}

public final class EntityRelationshipSpy: RemoteEntity {

    public typealias Metadata = VoidMetadata
    public typealias ResultPayload = EntityRelationshipEndpointResultPayloadSpy
    public typealias QueryContext = Never

    public static let identifierTypeID = "entity_relationship_spy"

    // MARK: - Records

    public static var remotePathRecords = [RemotePath<EntityRelationshipSpy>]()

    public static var endpointInvocationCount: Int = 0

    public static var indexNameRecords = [IndexName]()

    public static var dataRecords = [Data]()

    public static var endpointResultPayloadRecords = [EntityRelationshipEndpointResultPayloadSpy]()

    public static var filterRecords = [Query<EntityRelationshipSpy>.Filter?]()

    public static var identifierRecords = [Identifier]()

    public static func resetRecords() {
        remotePathRecords.removeAll()
        endpointInvocationCount = 0
        indexNameRecords.removeAll()
        dataRecords.removeAll()
        endpointResultPayloadRecords.removeAll()
        filterRecords.removeAll()
        identifierRecords.removeAll()
    }

    // MARK: - API

    public typealias Identifier = EntityRelationshipSpyIdentifier
    public typealias IndexName = EntityRelationshipSpyIndexName

    public let identifier: EntityRelationshipSpyIdentifier
    public let title: String
    public let relationships: [EntityRelationshipSpyIdentifier]

    public init(identifier: EntityRelationshipSpyIdentifier,
                title: String,
                relationships: [EntityRelationshipSpyIdentifier] = []) {
        self.identifier = identifier
        self.title = title
        self.relationships = relationships
    }

    public func merging(_ updated: EntityRelationshipSpy) -> EntityRelationshipSpy {
        return updated
    }

    public func entityIndexValue(for indexName: EntityRelationshipSpyIndexName) -> EntityIndexValue<EntityRelationshipSpyIdentifier, VoidSubtype> {
        EntityRelationshipSpy.indexNameRecords.append(indexName)
        switch indexName {
        case .title:
            return .string(title)
        case .relationships:
            return .array(relationships.map { .relationship($0) }.any)
        }
    }

    public var entityRelationshipIndices: [EntityRelationshipSpyIndexName] {
        return [.relationships]
    }

    public var entityRelationshipEntityTypeUIDs: [String] {
        return [EntityRelationshipSpyIdentifier.entityTypeUID]
    }

    public static func requestConfig(for remotePath: RemotePath<EntityRelationshipSpy>) -> APIRequestConfig? {
        EntityRelationshipSpy.remotePathRecords.append(remotePath)
        return APIRequestConfig(method: .get, path: .path("fake_relationship_entity") / remotePath.identifier())
    }

    public static func endpoint(for remotePath: RemotePath<EntityRelationshipSpy>) -> EntityRelationshipEndpointResultPayloadSpy.Endpoint? {
        EntitySpy.endpointInvocationCount += 1
        return 42
    }

    public static func entities(from remotePayload: EntityRelationshipEndpointResultPayloadSpy, for filter: Query<EntityRelationshipSpy>.Filter?) -> AnySequence<EntityRelationshipSpy> {
        EntityRelationshipSpy.endpointResultPayloadRecords.append(remotePayload)
        EntityRelationshipSpy.filterRecords.append(filter)

        if let stubEntities = remotePayload.stubEntities {
            return stubEntities.any
        }

        return [
            EntityRelationshipSpy(identifier: EntityRelationshipSpyIdentifier(value: .remote(42, nil)), title: "fake_title"),
            EntityRelationshipSpy(identifier: EntityRelationshipSpyIdentifier(value: .remote(24, nil)), title: "fake_title")
        ].any
    }

    public static func entity(from remotePayload: EntityRelationshipEndpointResultPayloadSpy, for identifier: Identifier) -> EntityRelationshipSpy? {
        EntityRelationshipSpy.endpointResultPayloadRecords.append(remotePayload)
        EntityRelationshipSpy.identifierRecords.append(identifier)

        return EntityRelationshipSpy(identifier: identifier, title: "fake_title")
    }

    public static func == (lhs: EntityRelationshipSpy, rhs: EntityRelationshipSpy) -> Bool {
        guard lhs.identifier == rhs.identifier else { return false }
        guard lhs.title == rhs.title else { return false }
        guard lhs.relationships == rhs.relationships else { return false }
        return true
    }
}

extension EntityRelationshipSpy: CoreDataEntity {

    public static func entity(from coreDataEntity: ManagedEntityRelationshipSpy) -> EntityRelationshipSpy? {
        do {
            return try EntityRelationshipSpy(coreDataEntity: coreDataEntity)
        } catch {
            Logger.log(.error, "\(EntityRelationshipSpy.self): \(error)", domain: "Tests", assert: true)
            return nil
        }
    }

    public func merge(into coreDataEntity: ManagedEntityRelationshipSpy) {
        coreDataEntity.__type_uid = identifier.identifierTypeID
        coreDataEntity.setProperty(Identifier.remotePredicateString, value: identifier.value.remoteValue?.coreDataValue())
        coreDataEntity.__identifier = identifier.value.localValue?.coreDataValue()
        coreDataEntity._title = title.coreDataValue()
        coreDataEntity._relationships = relationships.coreDataValue()
    }

    private convenience init(coreDataEntity: ManagedEntityRelationshipSpy) throws {
        self.init(identifier: try coreDataEntity.identifierValueType(EntityRelationshipSpyIdentifier.self,
                                                                     identifierTypeID: EntityRelationshipSpy.identifierTypeID),
                  title: try coreDataEntity._title.stringValue(propertyName: "_title"),
                  relationships: coreDataEntity._relationships.entityRelationshipSpyArrayValue().array)
    }
}

public extension EntityRelationshipSpy {

    convenience init(idValue: IdentifierValueType<String, Int> = .remote(1, nil),
                     title: String? = nil,
                     relationships: [EntityRelationshipSpyIdentifier] = []) {

        self.init(identifier: EntityRelationshipSpyIdentifier(value: idValue, remoteSynchronizationState: .outOfSync),
                  title: title ?? "fake_title_\(idValue.remoteValue?.description ?? "none")",
                  relationships: relationships)
    }
}

private extension Data {
    func entitySpyArrayValue() -> AnySequence<FailableValue<EntityRelationshipSpyIdentifier>>? {
        guard let values: AnySequence<IdentifierValueType<String, Int>> = identifierValueTypeArrayValue(EntityRelationshipSpyIdentifier.self) else {
            return nil
        }
        return values.lazy.map { .value(EntityRelationshipSpyIdentifier(value: $0)) }.any
    }
}

private extension Optional where Wrapped == Data {
    func entitySpyArrayValue() -> AnySequence<FailableValue<EntityRelationshipSpyIdentifier>> {
        return self?.entitySpyArrayValue() ?? .empty
    }
}
