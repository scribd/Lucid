//
//  Accessors.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 3/27/19.
//

import Foundation

public extension Descriptions {
    
    func subtype(for name: String) throws -> Subtype {
        guard let subtype = subtypesByName[name] else {
            throw CodeGenError.subtypeNotFound(name)
        }
        return subtype
    }
    
    func entity(for name: String) throws -> Entity {
        guard let entity = entitiesByName[name] else {
            throw CodeGenError.entityNotFound(name)
        }
        return entity
    }
    
    func endpoint(for name: String) throws -> EndpointPayload {
        guard let endpoint = endpointsByName[name] else {
            throw CodeGenError.endpointPayloadNotFound(name)
        }
        return endpoint
    }

    func modelMappingHistory(derivedFrom allVersions: [Version]) throws -> [Version] {
        var history = Set<Version>()

        entities.forEach { entity in
            guard let addedAtVersion = entity.addedAtVersion else { return }
            entity.modelVersions.forEach { version in
                history.insert(version)
                if version != addedAtVersion, let previousVersion = allVersions.first(where: { $0 < version && $0.isRelease && Version.isMatchingRelease(version, $0) == false }) {
                    history.insert(previousVersion)
                }
            }
        }

        return history.sorted().reversed()
    }

    var clientQueueNames: [String] {
        var names = Set(entities.map { $0.clientQueueName })
        names.insert(Entity.mainClientQueueName)
        return names.sorted { lhs, rhs in
                if lhs == Entity.mainClientQueueName {
                    return true
                } else if rhs == Entity.mainClientQueueName {
                    return false
                } else {
                    return lhs < rhs
                }
        }
    }
}

public extension Entity {
    
    func property(for name: String) throws -> EntityProperty {
        guard let property = properties.first(where: { $0.name == name }) else {
            throw CodeGenError.propertyNotFound(self, name)
        }
        return property
    }
    
    var usedProperties: [EntityProperty] {
        return properties.filter { $0.unused == false }
    }
    
    var values: [EntityProperty] {
        return usedProperties.filter { $0.isValue }
    }

    var relationships: [EntityProperty] {
        return usedProperties.filter { $0.isRelationship }
    }

    var valuesThenRelationships: [EntityProperty] {
        return values + relationships
    }

    var relationshipsForIdentifierDerivation: [String: [(property: EntityProperty, relationship: EntityRelationship)]] {
        return usedProperties.reduce(into: [:]) { relationships, property in
            guard let relationship = property.relationship else { return }
            let values = relationships[relationship.entityName] ?? []
            relationships[relationship.entityName] = values + [(property, relationship)]
        }
    }
    
    func extractablePropertyEntities(_ descriptions: Descriptions) throws -> [Entity] {
        return try Set(try extractablePropertyEntityNames(descriptions, history: Set()))
            .sorted()
            .map { try descriptions.entity(for: $0) }
    }
    
    private func extractablePropertyEntityNames(_ descriptions: Descriptions, history: Set<String>) throws -> [String] {
        guard !history.contains(name) else { return [] }
        var history = history
        history.insert(name)
        
        return try usedProperties.flatMap { property -> [String] in
            guard let relationship = property.relationship, relationship.idOnly == false else {
                return []
            }
            let relationshipEntity = try descriptions.entity(for: relationship.entityName)
            return try [relationshipEntity.name] + relationshipEntity.extractablePropertyEntityNames(descriptions, history: history)
        }
    }
    
    var mutable: Bool {
        return properties.contains { $0.mutable }
    }
    
    var objc: Bool {
        return identifier.objc || properties.contains { $0.objc }
    }
    
    func coreDataName(for version: Version, useCoreDataLegacyNaming: Bool = false) -> String {
        let name: String
        if useCoreDataLegacyNaming {
            name = self.name.camelCased(ignoreLexicon: true).suffixedName()
        } else {
            name = persistedName?.suffixedName() ?? self.name
        }
        return "\(name)_\(version.sqlDescription)"
    }

    func ignoredVersionRangesByPropertyName() throws -> [String: [(from: Version, to: Version)]] {
        guard let addedAtVersion = addedAtVersion else {
            throw CodeGenError.entityAddedAtVersionNotFound(name)
        }
        var from = addedAtVersion
        return versionHistory.reduce(into: [:]) {
            for propertyName in $1.ignorePropertyMigrationChecksOn {
                var ranges = $0[propertyName] ?? []
                ranges.append((from, $1.version))
                $0[propertyName] = ranges
                from = $1.version
            }
        }
    }

    var addedAtVersion: Version? {
        return modelVersions.first ?? legacyAddedAtVersion
    }

    var modelVersions: [Version] {
        return versionHistory.map { $0.version }
    }

    func nameForVersion(_ version: Version) -> String {
        if versionHistory.isEmpty {
            // legacy check
            return name
        }

        return versionHistory.first {
            $0.version > version && $0.previousName != nil
        }?.previousName ?? name
    }

    var previousNameForCoreData: String? {
        return versionHistory.first { $0.previousName != nil }?.previousName
    }
}

public extension EntityIdentifier {
    
    func relationshipIDs(_ entity: Entity, _ descriptions: Descriptions) throws -> [EntityIdentifierType.RelationshipID] {
        switch identifierType {
        case .void,
             .scalarType:
            return []
        case .property(let propertyName):
            let property = entity.properties.filter { $0.name == propertyName }

            if let entityName = property.first?.relationship?.entityName {
                let relationshipEntity = try descriptions.entity(for: entityName)
                return [
                    EntityIdentifierType.RelationshipID(variableName: propertyName,
                                                        entityName: relationshipEntity.name)
                ]
            } else {
                return []
            }
        case .relationships(_, let relationships):
            return relationships
        }
    }
    
    func equivalentIdentifierTypeID(_ entity: Entity, _ descriptions: Descriptions) throws -> String? {
        
        if let equivalentIdentifierName = equivalentIdentifierName {
            return try descriptions.entity(for: equivalentIdentifierName).identifierTypeID
        }
        
        switch identifierType {
        case .void,
             .scalarType,
             .relationships:
            return nil
            
        case .property(let propertyName):
            let property = entity.properties.filter { $0.name == propertyName }
            let relationshipName: String? = property.first.flatMap {
                switch $0.propertyType {
                case .relationship(let relationship):
                    return relationship.entityName
                case .array,
                     .scalar,
                     .subtype:
                    return nil
                }
            }
            
            if let entityName = relationshipName {
                return try descriptions.entity(for: entityName).identifierTypeID
            } else {
                return nil
            }
        }
    }
}

public extension EntityProperty {
    
    var relationship: EntityRelationship? {
        return propertyType.relationship
    }
    
    var isRelationship: Bool {
        return propertyType.isRelationship
    }
    
    var isValue: Bool {
        return propertyType.isValue
    }
    
    var isSubtype: Bool {
        return propertyType.isSubtype
    }
    
    var isArray: Bool {
        return propertyType.isArray
    }
    
    var keysPathComponents: [[String]] {
        return [key].map { key in
            key.split(separator: ".").map {
                String($0).camelCased(ignoreLexicon: true).variableCased(ignoreLexicon: true)
            }
        }
    }

    var previousSearchableName: String? {
        return previousName?.snakeCased.camelCased().variableCased()
    }

    func coreDataName(useCoreDataLegacyNaming: Bool) -> String {
        if useCoreDataLegacyNaming {
            return persistedName ?? name.camelCased(ignoreLexicon: true).variableCased(ignoreLexicon: true)
        } else {
            return persistedName ?? name
        }
    }
}

public extension EntityProperty.PropertyType {
    
    var relationship: EntityRelationship? {
        switch self {
        case .relationship(let relationship),
             .array(.relationship(let relationship)):
            return relationship
        case .subtype,
             .scalar,
             .array:
            return nil
        }
    }
    
    var isRelationship: Bool {
        return relationship != nil
    }
    
    var isValue: Bool {
        return isRelationship == false
    }
    
    var isSubtype: Bool {
        switch self {
        case .subtype,
             .array(.subtype):
            return true
        case .relationship,
             .scalar,
             .array:
            return false
        }
    }
    
    func subtype(_ descriptions: Descriptions) throws -> Subtype? {
        switch self {
        case .subtype(let name):
            return try descriptions.subtype(for: name)
        default:
            return nil
        }
    }
    
    var scalarType: PropertyScalarType? {
        switch self {
        case .scalar(let scalarType):
            return scalarType
        default:
            return nil
        }
    }
    
    var isArray: Bool {
        switch self {
        case .array:
            return true
        case .relationship(let relationship) where relationship.association == .toMany:
            return true
        case .relationship,
             .scalar,
             .subtype:
            return false
        }
    }
}

public extension EntityIdentifier {
    
    var isRelationship: Bool {
        switch identifierType {
        case .relationships:
            return true
        default:
            return false
        }
    }
    
    var isScalarType: Bool {
        switch identifierType {
        case .scalarType:
            return true
        default:
            return false
        }
    }
    
    var isProperty: Bool {
        switch identifierType {
        case .property:
            return true
        default:
            return false
        }
    }
}

public extension MetadataProperty {
    
    var isArray: Bool {
        return propertyType.isArray
    }
}

public extension MetadataProperty.PropertyType {

    var isArray: Bool {
        switch self {
        case .scalar,
             .subtype:
            return false
        case .array:
            return true
        }
    }
}

public extension EndpointPayloadEntity.Structure {
    
    var isArray: Bool {
        switch self {
        case .array,
             .nestedArray:
            return true
        case .single:
            return false
        }
    }
}

public extension EndpointPayload {

    enum InitializerType {
        case initFromRoot(_ subkey: String?)
        case initFromKey(_ key: String)
        case initFromSubkey(key: String, subkey: String)
        case mapFromSubstruct(key: String, subkey: String)
    }
    
    func initializerType() throws -> InitializerType {

        if let key = baseKey, let subkey = entity.entityKey {
            switch entity.structure {
            case .single,
                 .array:
                return .initFromSubkey(key: key, subkey: subkey)
            case .nestedArray:
                return .mapFromSubstruct(key: key, subkey: subkey)
            }
        } else if let key = baseKey {
            return .initFromKey(key)
        } else {
            return .initFromRoot(entity.entityKey)
        }
    }
}

public extension Subtype {
    
    var isStruct: Bool {
        switch items {
        case .cases,
             .options:
            return false
        case .properties:
            return true
        }
    }
    
    var isEnum: Bool {
        switch items {
        case .cases:
            return true
        case .options,
             .properties:
            return false
        }
    }
}
