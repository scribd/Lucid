//
//  EntitySpy.swift
//  LucidTestKit
//
//  Created by Stephane Magne on 3/29/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

#if LUCID_REACTIVE_KIT
import Lucid_ReactiveKit
#else
import Lucid
#endif

// MARK: - EntitySpy

public final class EntitySpyIdentifier: RemoteIdentifier, CoreDataIdentifier {

    public typealias RemoteValueType = Int
    public typealias LocalValueType = String

    public let _remoteSynchronizationState: PropertyBox<RemoteSynchronizationState>

    private let property: PropertyBox<IdentifierValueType<String, Int>>
    public var value: IdentifierValueType<String, Int> {
        return property.value
    }

    public static let entityTypeUID = "entity_spy"
    public let identifierTypeID: String

    public init(value: IdentifierValueType<String, Int>,
                identifierTypeID: String? = nil,
                remoteSynchronizationState: RemoteSynchronizationState? = nil) {
        self._remoteSynchronizationState = PropertyBox(remoteSynchronizationState ?? .synced, atomic: true)
        self.identifierTypeID = identifierTypeID ?? EntitySpy.identifierTypeID
        property = PropertyBox(value, atomic: true)
    }

    public static func < (lhs: EntitySpyIdentifier, rhs: EntitySpyIdentifier) -> Bool {
        return lhs.value < rhs.value
    }

    public static func == (_ lhs: EntitySpyIdentifier, _ rhs: EntitySpyIdentifier) -> Bool {
        return lhs.value == rhs.value && lhs.identifierTypeID == rhs.identifierTypeID
    }

    public func hash(into hasher: inout DualHasher) {
        hasher.combine(value)
        hasher.combine(identifierTypeID)
    }

    public func update(with newValue: EntitySpyIdentifier) {
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
        identifierTypeID = EntitySpy.identifierTypeID
    }

    public var description: String {
        return "\(EntitySpyIdentifier.self):\(value.description)"
    }
}

public enum EntitySpyIndexName: String, CustomStringConvertible {
    case title
    case subtitle
    case lazy
    case oneRelationship
    case manyRelationships

    public var description: String {
        return rawValue
    }
}

extension EntitySpyIndexName: CoreDataIndexName {

    public var predicateString: String {
        switch self {
        case .title:
            return "_title"
        case .subtitle:
            return "_subtitle"
        case .lazy:
            return "_lazy"
        case .oneRelationship:
            return "_oneRelationship"
        case .manyRelationships:
            return "_manyRelationships"
        }
    }

    public var isOneToOneRelationship: Bool {
        switch self {
        case .title,
             .subtitle,
             .lazy,
             .manyRelationships:
            return false
        case .oneRelationship:
            return true
        }
    }

    public var identifierTypeIDRelationshipPredicateString: String? {
        switch self {
        case .title,
             .subtitle,
             .lazy,
             .manyRelationships:
            return nil
        case .oneRelationship:
            return "__oneRelationshipTypeUID"
        }
    }
}

extension EntitySpyIndexName: QueryResultConvertible {

    public var requestValue: String {
        switch self {
        case .title:
            return "title"
        case .subtitle:
            return "subtitle"
        case .lazy:
            return "lazy"
        case .manyRelationships:
            return "many_relationships"
        case .oneRelationship:
            return "one_relationship"
        }
    }
}

public indirect enum EntitySpyRelationshipIndexName: RelationshipPathConvertible {
    public typealias AnyEntity = AnyEntitySpy

    case oneRelationship([EntityRelationshipSpyRelationshipIndexName]?)
    case manyRelationships([EntityRelationshipSpyRelationshipIndexName]?)

    public var paths: [[AnyEntitySpyIndexName]] {
        switch self {
        case .oneRelationship(let children):
            return [[.entitySpy(.manyRelationships)]] + (children ?? []).flatMap { child in
                child.paths.map { path in
                    [.entitySpy(.manyRelationships)] + path
                }
            }
        case .manyRelationships(let children):
            return [[.entitySpy(.manyRelationships)]] + (children ?? []).flatMap { child in
                child.paths.map { path in
                    [.entitySpy(.manyRelationships)] + path
                }
            }
        }
    }
}

public struct EndpointStubData {

    public var stubEntities: [EntitySpy]?

    public var stubEntityMetadata: [EntitySpyMetadata]?

    public var stubEndpointMetadata: EndpointMetadata?

    public static var empty: EndpointStubData { return EndpointStubData() }
}

public final class EntityEndpointResultPayloadSpy: ResultPayloadConvertible {

    public typealias Endpoint = EndpointStubData

    // MARK: Stubs

    public var stubEntities: AnySequence<EntitySpy>?

    public var stubEntityMetadata: AnySequence<EntitySpyMetadata>?

    public var stubEndpointMetadata: EndpointMetadata?

    // MARK: Records

    public private(set) var metadataRecordCount: Int = 0

    public private(set) var getEntityRecords = [String]()

    public private(set) var allEntitiesRecordCount: Int = 0

    // MARK: API

    public required init(stubEntities: [EntitySpy]?, stubEntityMetadata: [EntitySpyMetadata]?, stubEndpointMetadata: EndpointMetadata?) {
        self.stubEntities = stubEntities?.any
        self.stubEntityMetadata = stubEntityMetadata?.any
        self.stubEndpointMetadata = stubEndpointMetadata
    }

    public convenience init(from data: Data,
                            endpoint: EndpointStubData,
                            decoder: JSONDecoder) throws {
        self.init(stubEntities: endpoint.stubEntities,
                  stubEntityMetadata: endpoint.stubEntityMetadata,
                  stubEndpointMetadata: endpoint.stubEndpointMetadata)
    }

    public var metadata: EndpointResultMetadata {
        metadataRecordCount += 1
        return EndpointResultMetadata(endpoint: stubEndpointMetadata,
                                      entity: stubEntityMetadata?.map { $0 as EntityMetadata? }.any ?? [].any)
    }

    public func getEntity<E>(for identifier: E.Identifier) -> E? where E: Entity {
        getEntityRecords.append(identifier.description)
        if let identifier = identifier as? EntitySpyIdentifier {
            return stubEntities?.first { $0.identifier == identifier }  as? E
        }

        return nil
    }

    public func allEntities<E>() -> AnySequence<E> where E: Entity {
        allEntitiesRecordCount += 1
        if E.self is EntitySpy.Type {
            return stubEntities?.any as? AnySequence<E> ?? [].any
        }

        return [].any
    }
}

public struct EntitySpyMetadata: EntityMetadata, EntityIdentifiable {

    let remoteID: Int

    public var identifier: EntitySpyIdentifier { return EntitySpyIdentifier(value: .remote(remoteID, nil)) }
}

public final class EntitySpy: RemoteEntity {

    public typealias Metadata = EntitySpyMetadata
    public typealias ResultPayload = EntityEndpointResultPayloadSpy
    public typealias QueryContext = Never

    public static let identifierTypeID = "entity_spy"

    public static var stubEndpointData: EndpointStubData?

    // MARK: - Records

    public static var remotePathRecords = [RemotePath<EntitySpy>]()

    public static var endpointInvocationCount: Int = 0

    public static var indexNameRecords = [IndexName]()

    public static var mergingRecords = [EntitySpy]()

    public static func resetRecords() {
        stubEndpointData = nil
        remotePathRecords.removeAll()
        endpointInvocationCount = 0
        indexNameRecords.removeAll()
        mergingRecords.removeAll()
    }

    // MARK: - API

    public typealias Identifier = EntitySpyIdentifier
    public typealias IndexName = EntitySpyIndexName
    public typealias RelationshipIndexName = EntitySpyRelationshipIndexName

    public let identifier: EntitySpyIdentifier
    public let title: String
    public let subtitle: String
    public let lazy: Lazy<Int>
    public let oneRelationship: EntityRelationshipSpyIdentifier

    public let manyRelationships: AnySequence<EntityRelationshipSpyIdentifier>

    public init<S>(identifier: EntitySpyIdentifier,
                   title: String,
                   subtitle: String,
                   lazy: Lazy<Int>,
                   oneRelationship: EntityRelationshipSpyIdentifier,
                   manyRelationships: S) where S: Sequence, S.Element == EntityRelationshipSpyIdentifier {

        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.lazy = lazy
        self.oneRelationship = oneRelationship
        self.manyRelationships = manyRelationships.any
    }

    public func merging(_ updated: EntitySpy) -> EntitySpy {
        EntitySpy.mergingRecords.append(updated)
        return EntitySpy(
            identifier: updated.identifier,
            title: updated.title,
            subtitle: updated.subtitle,
            lazy: lazy.merging(with: updated.lazy),
            oneRelationship: updated.oneRelationship,
            manyRelationships: updated.manyRelationships
        )
    }

    public func entityIndexValue(for indexName: EntitySpyIndexName) -> EntityIndexValue<EntityRelationshipSpyIdentifier, VoidSubtype> {
        EntitySpy.indexNameRecords.append(indexName)
        switch indexName {
        case .title:
            return .string(title)
        case .subtitle:
            return .string(subtitle)
        case .lazy:
            return lazy.value().flatMap { lazyValue in .optional(.int(lazyValue)) } ?? .none
        case .oneRelationship:
            return .relationship(oneRelationship)
        case .manyRelationships:
            return .array(manyRelationships.lazy.map { .relationship($0) }.any)
        }
    }

    public var entityRelationshipIndices: [EntitySpyIndexName] {
        return [
            .oneRelationship,
            .manyRelationships
        ]
    }

    public static func requestConfig(for remotePath: RemotePath<EntitySpy>) -> APIRequestConfig? {
        EntitySpy.remotePathRecords.append(remotePath)
        return APIRequestConfig(method: .get, path: .path("fake_entity") / remotePath.identifier())
    }

    public static func endpoint(for remotePath: RemotePath<EntitySpy>) -> EndpointStubData? {
        EntitySpy.endpointInvocationCount += 1
        return stubEndpointData
    }

    public static func == (lhs: EntitySpy, rhs: EntitySpy) -> Bool {
        guard lhs.identifier == rhs.identifier else { return false }
        guard lhs.title == rhs.title else { return false }
        guard lhs.lazy == rhs.lazy else { return false }
        guard lhs.oneRelationship == rhs.oneRelationship else { return false }
        guard lhs.manyRelationships == rhs.manyRelationships else { return false }
        return true
    }
}

extension EntitySpy: CoreDataEntity {

    public static func entity(from coreDataEntity: ManagedEntitySpy) -> EntitySpy? {
        do {
            return try EntitySpy(coreDataEntity: coreDataEntity)
        } catch {
            Logger.log(.error, "\(EntitySpy.self): \(error)", domain: "Tests", assert: true)
            return nil
        }
    }

    public func merge(into coreDataEntity: ManagedEntitySpy) {
        coreDataEntity.__type_uid = identifier.identifierTypeID
        coreDataEntity.setProperty(Identifier.remotePredicateString, value: identifier.value.remoteValue?.coreDataValue())
        coreDataEntity.__identifier = identifier.value.localValue?.coreDataValue()
        coreDataEntity._title = title.coreDataValue()
        coreDataEntity._subtitle = subtitle.coreDataValue()
        coreDataEntity.setProperty("_oneRelationship", value: oneRelationship.remoteCoreDataValue())
        coreDataEntity.__oneRelationship = oneRelationship.localCoreDataValue()
        coreDataEntity.__oneRelationshipTypeUID = oneRelationship.identifierTypeID
        coreDataEntity._manyRelationships = manyRelationships.coreDataValue()
        coreDataEntity.setProperty("_lazy", value: lazy.value().coreDataValue())
        coreDataEntity.setProperty("__lazyLazyFlag", value: lazy.coreDataFlagValue)
    }

    private convenience init(coreDataEntity: ManagedEntitySpy) throws {
        self.init(
            identifier: try coreDataEntity.identifierValueType(EntitySpyIdentifier.self, identifierTypeID: EntitySpy.identifierTypeID),
            title: try coreDataEntity._title.stringValue(propertyName: "_title"),
            subtitle: try coreDataEntity._subtitle.stringValue(propertyName: "_subtitle"),
            lazy: try Lazy(
                value: coreDataEntity.intValue(propertyName: "_lazy"),
                requested: coreDataEntity.boolValue(propertyName: "__lazyLazyFlag")
            ),
            oneRelationship: try coreDataEntity.identifierValueType(EntityRelationshipSpyIdentifier.self, identifierTypeID: EntityRelationshipSpy.identifierTypeID, propertyName: "_oneRelationship"),
            manyRelationships: coreDataEntity._manyRelationships.entityRelationshipSpyArrayValue()
        )
    }
}

extension EntitySpy {

    public convenience init(idValue: IdentifierValueType<String, Int> = .remote(1, nil),
                            remoteSynchronizationState: RemoteSynchronizationState = .outOfSync,
                            title: String? = nil,
                            subtitle: String? = nil,
                            lazy: Lazy<Int> = .unrequested,
                            oneRelationshipIdValue: IdentifierValueType<String, Int> = .remote(1, nil),
                            manyRelationshipsIdValues: [IdentifierValueType<String, Int>] = []) {

        self.init(
            identifier: EntitySpyIdentifier(value: idValue, remoteSynchronizationState: remoteSynchronizationState),
            title: title ?? "fake_title_\(idValue.remoteValue?.description ?? "none")",
            subtitle: subtitle ?? "fake_subtitle_\(idValue.remoteValue?.description ?? "none")",
            lazy: lazy,
            oneRelationship: EntityRelationshipSpyIdentifier(value: oneRelationshipIdValue),
            manyRelationships: manyRelationshipsIdValues.map { EntityRelationshipSpyIdentifier(value: $0) }
        )
    }
}

private extension Data {
    func entityRelationshipSpyArrayValue() -> AnySequence<EntityRelationshipSpyIdentifier>? {
        guard let values: AnySequence<IdentifierValueType<String, Int>> = identifierValueTypeArrayValue(EntityRelationshipSpyIdentifier.self) else {
            return nil
        }
        return values.lazy.map { EntityRelationshipSpyIdentifier(value: $0) }.any
    }
}

extension Optional where Wrapped == Data {
    func entityRelationshipSpyArrayValue() -> AnySequence<EntityRelationshipSpyIdentifier> {
        return self?.entityRelationshipSpyArrayValue() ?? .empty
    }
}
