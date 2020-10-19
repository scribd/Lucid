//
//  Codable.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 3/27/19.
//

import Foundation

// MARK: - Defaults

public enum DescriptionDefaults {
    public static let identifier = EntityIdentifier(
        identifierType: .void,
        equivalentIdentifierName: nil,
        objc: DescriptionDefaults.objc,
        atomic: nil
    )
    public static let remote = true
    public static let persist = false
    public static let useForEquality = true
    public static let idOnly = false
    public static let failableItems = true
    public static let isTarget = false
    public static let nullable = false
    public static let mutable = false
    public static let objc = false
    public static let objcNoneCase = false
    public static let unused = false
    public static let logError = true
    public static let lazy = false
    public static let matchExactKey = false
    public static let platforms = Set<Platform>()
    public static let lastRemoteRead = false
    public static let queryContext = false
    public static let clientQueueName = Entity.mainClientQueueName
    public static let ignoreMigrationChecks = false
    public static let ignorePropertyMigrationChecksOn = [String]()
    public static let httpMethod: EndpointPayloadTest.HTTPMethod = .get
}

public extension Entity {
    static let mainClientQueueName = "main"
}

// MARK: - Payloads

extension EndpointPayload: Codable {
    
    private enum Keys: String, CodingKey {
        case name
        case baseKey
        case entity
        case entityVariations
        case excludedPaths
        case metadata
        case tests
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        name = try container.decode(String.self, forKey: .name)
        baseKey = try container.decodeIfPresent(String.self, forKey: .baseKey)
        entity = try container.decode(EndpointPayloadEntity.self, forKey: .entity)
        entityVariations = try container.decodeIfPresent([EndpointPayloadEntityVariation].self, forKey: .entityVariations)
        excludedPaths = try container.decodeIfPresent([String].self, forKey: .excludedPaths) ?? []
        metadata = try container.decodeIfPresent([MetadataProperty].self, forKey: .metadata)
        tests = try container.decodeIfPresent([EndpointPayloadTest].self, forKey: .tests) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(baseKey, forKey: .baseKey)
        try container.encode(entity, forKey: .entity)
        try container.encodeIfPresent(entityVariations, forKey: .entityVariations)
        try container.encodeIfPresent(excludedPaths.isEmpty ? nil : excludedPaths, forKey: .excludedPaths)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(tests.isEmpty ? nil : tests, forKey: .tests)
    }
}

extension EndpointPayloadTest: Codable {
    
    private enum Keys: String, CodingKey {
        case name
        case url
        case httpMethod
        case body
        case contexts
        case endpoints
        case entities
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(URL.self, forKey: .url)
        httpMethod = try container.decodeIfPresent(HTTPMethod.self, forKey: .httpMethod) ?? .get
        body = try container.decodeIfPresent(String.self, forKey: .body)
        entities = try container.decode([Entity].self, forKey: .entities)
        // for parsing from previous versions
        do {
            contexts = try container.decode([String].self, forKey: .contexts)
            endpoints = []
        } catch {
            endpoints = try container.decode([String].self, forKey: .endpoints)
            contexts = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(httpMethod == DescriptionDefaults.httpMethod ? nil : httpMethod, forKey: .httpMethod)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encode(entities, forKey: .entities)
        try container.encodeIfPresent(contexts, forKey: .contexts)
        try container.encodeIfPresent(endpoints, forKey: .endpoints)
    }
}

extension EndpointPayloadTest.HTTPMethod: Codable { }

extension EndpointPayloadTest.Entity: Codable {
    
    private enum Keys: String, CodingKey {
        case name
        case count
        case isTarget
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        name = try container.decode(String.self, forKey: .name)
        count = try container.decodeIfPresent(Int.self, forKey: .count)
        isTarget = try container.decodeIfPresent(Bool.self, forKey: .isTarget) ?? DescriptionDefaults.isTarget
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(count, forKey: .count)
        try container.encodeIfPresent(isTarget == DescriptionDefaults.isTarget ? nil : isTarget, forKey: .isTarget)
    }
}

extension EndpointPayloadEntity: Codable {
    
    private enum Keys: String, CodingKey {
        case entityKey
        case entityName
        case structure
        case nullable
        case legacyOptional = "optional"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        entityKey = try container.decodeIfPresent(String.self, forKey: .entityKey)
        entityName = try container.decode(String.self, forKey: .entityName)
        structure = try container.decode(Structure.self, forKey: .structure)
        nullable = try container.decodeIfPresent(Bool.self, forKey: .nullable) ?? container.decodeIfPresent(Bool.self, forKey: .legacyOptional) ?? DescriptionDefaults.nullable
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encodeIfPresent(entityKey, forKey: .entityKey)
        try container.encode(entityName, forKey: .entityName)
        try container.encode(structure, forKey: .structure)
        try container.encodeIfPresent(nullable == DescriptionDefaults.nullable ? nil : nullable, forKey: .nullable)
    }
}

extension EndpointPayloadEntity.Structure: Codable {}

// MARK: - Entity

extension Entity: Codable {
    
    private enum Keys: String, CodingKey {
        case name
        case remote
        case persist
        case identifier
        case metadata
        case properties
        case systemProperties
        case uid
        case legacyPreviousName
        case previousName
        case addedAtVersion
        case versionHistory
        case persistedName
        case platforms
        case lastRemoteRead
        case queryContext
        case clientQueueName
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        let name = try container.decode(String.self, forKey: .name)
        self.name = name
        remote = try container.decodeIfPresent(Bool.self, forKey: .remote) ?? DescriptionDefaults.remote
        persist = try container.decodeIfPresent(Bool.self, forKey: .persist) ?? DescriptionDefaults.persist
        identifier = try container.decodeIfPresent(EntityIdentifier.self, forKey: .identifier) ?? DescriptionDefaults.identifier
        metadata = try container.decodeIfPresent([MetadataProperty].self, forKey: .metadata)
        properties = try container.decode([EntityProperty].self, forKey: .properties).sorted(by: { $0.name < $1.name })
        systemProperties = try container.decodeIfPresent([SystemProperty].self, forKey: .systemProperties)?.sorted(by: { $0.name.rawValue < $1.name.rawValue }) ?? []
        identifierTypeID = try container.decodeIfPresent(String.self, forKey: .uid)
        legacyPreviousName = try container.decodeIfPresent(String.self, forKey: .legacyPreviousName) ?? container.decodeIfPresent(String.self, forKey: .previousName)
        versionHistory = try container.decodeIfPresent([VersionHistoryItem].self, forKey: .versionHistory) ?? []
        if versionHistory.isEmpty {
            legacyAddedAtVersion = try container.decodeIfPresent(Version.self, forKey: .addedAtVersion)
        } else {
            legacyAddedAtVersion = nil
        }
        persistedName = try container.decodeIfPresent(String.self, forKey: .persistedName)
        platforms = try container.decodeIfPresent(Set<Platform>.self, forKey: .platforms) ?? DescriptionDefaults.platforms
        queryContext = try container.decodeIfPresent(Bool.self, forKey: .queryContext) ?? DescriptionDefaults.queryContext
        clientQueueName = try container.decodeIfPresent(String.self, forKey: .clientQueueName) ?? DescriptionDefaults.clientQueueName

        let systemPropertiesSet = Set(SystemPropertyName.allCases.map { $0.rawValue })
        for property in properties where systemPropertiesSet.contains(property.name) {
           throw CodeGenError.systemPropertyNameCollision(property.name)
        }

        if let legacyLastRemoteRead = try container.decodeIfPresent(Bool.self, forKey: .lastRemoteRead) {
            let systemPropertyNames = systemProperties.map { $0.name }
            guard systemPropertyNames.contains(.lastRemoteRead) == false else {
                throw CodeGenError.incompatiblePropertyKey("last_remote_read")
            }
            if legacyLastRemoteRead {
                systemProperties.append(SystemProperty(name: .lastRemoteRead, useCoreDataLegacyNaming: true, addedAtVersion: nil))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(name, forKey: .name)
        try container.encode(remote, forKey: .remote)
        try container.encode(persist, forKey: .persist)
        try container.encode(identifier, forKey: .identifier)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(properties, forKey: .properties)
        try container.encodeIfPresent(systemProperties.isEmpty ? nil : systemProperties, forKey: .systemProperties)
        try container.encodeIfPresent(identifierTypeID, forKey: .uid)
        try container.encodeIfPresent(versionHistory.isEmpty ? nil : versionHistory, forKey: .versionHistory)
        try container.encodeIfPresent(legacyPreviousName, forKey: .legacyPreviousName)
        try container.encodeIfPresent(persistedName, forKey: .persistedName)
        try container.encodeIfPresent(platforms == DescriptionDefaults.platforms ? nil : platforms, forKey: .platforms)
        try container.encodeIfPresent(queryContext == DescriptionDefaults.queryContext ? nil : queryContext, forKey: .queryContext)
        try container.encodeIfPresent(clientQueueName == DescriptionDefaults.clientQueueName ? nil : clientQueueName, forKey: .clientQueueName)
    }
}

extension VersionHistoryItem: Codable {
    
    private enum Keys: String, CodingKey {
        case version
        case previousName
        case ignoreMigrationChecks
        case ignorePropertyMigrationChecksOn
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)

        version = try container.decode(Version.self, forKey: .version)
        previousName = try container.decodeIfPresent(String.self, forKey: .previousName)
        ignoreMigrationChecks = try container.decodeIfPresent(Bool.self, forKey: .ignoreMigrationChecks) ?? DescriptionDefaults.ignoreMigrationChecks
        ignorePropertyMigrationChecksOn = try container.decodeIfPresent([String].self, forKey: .ignorePropertyMigrationChecksOn) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(previousName, forKey: .previousName)
        try container.encodeIfPresent(ignoreMigrationChecks == DescriptionDefaults.ignoreMigrationChecks ? nil : ignoreMigrationChecks, forKey: .ignoreMigrationChecks)
        try container.encodeIfPresent(ignorePropertyMigrationChecksOn == DescriptionDefaults.ignorePropertyMigrationChecksOn ? nil : ignorePropertyMigrationChecksOn, forKey: .ignorePropertyMigrationChecksOn)
    }
}

extension EndpointPayloadEntityVariation: Codable {
    
    private enum Keys: String, CodingKey {
        case entityName
        case propertyRenames
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        self.entityName = try container.decode(String.self, forKey: .entityName)
        self.propertyRenames = try container.decodeIfPresent([Rename].self, forKey: .propertyRenames)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(entityName, forKey: .entityName)
        try container.encodeIfPresent(propertyRenames, forKey: .propertyRenames)
    }
}

extension EntityIdentifier: Codable {
    
    private enum Keys: String, CodingKey {
        case type
        case derivedFromRelationships
        case equivalentToIdentifierOf
        case propertyName
        case objc
        case atomic
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        objc = try container.decodeIfPresent(Bool.self, forKey: .objc) ?? DescriptionDefaults.objc
        
        let lowerCaseType = try container.decode(String.self, forKey: .type)
        switch lowerCaseType {
        case "property":
            identifierType = .property(try container.decode(String.self, forKey: .propertyName))
        default:
            do {
                let relationshipIDs: [EntityIdentifierType.RelationshipID] = try container
                    .decode([String].self, forKey: .derivedFromRelationships)
                    .map { entityName in
                        EntityIdentifierType.RelationshipID(variableName: entityName, entityName: entityName)
                    }
                
                guard let scalarType = PropertyScalarType(lowerCaseType) else {
                    throw DecodingError.dataCorruptedError(forKey: Keys.type, in: container, debugDescription: "Unknown value type \(lowerCaseType.capitalized).")
                }
                
                identifierType = .relationships(scalarType, relationshipIDs)
            } catch {
                guard let scalarType = PropertyScalarType(lowerCaseType) else {
                    throw DecodingError.dataCorruptedError(forKey: Keys.type, in: container, debugDescription: "Unknown value type \(lowerCaseType.capitalized).")
                }
                identifierType = .scalarType(scalarType)
            }
        }
        
        equivalentIdentifierName = try container.decodeIfPresent(String.self, forKey: .equivalentToIdentifierOf)
        atomic = try container.decodeIfPresent(Bool.self, forKey: .atomic)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encodeIfPresent(objc == DescriptionDefaults.objc ? nil : objc, forKey: .objc)
        try container.encodeIfPresent(equivalentIdentifierName, forKey: .equivalentToIdentifierOf)

        switch identifierType {
        case .property(let name):
            try container.encode("property", forKey: .type)
            try container.encode(name, forKey: .propertyName)

        case .relationships(let scalarType, let relationshipIDs):
            try container.encode(scalarType.stringValue, forKey: .type)
            try container.encode(relationshipIDs.map { $0.entityName }, forKey: .derivedFromRelationships)

        case .scalarType(let scalarType):
            try container.encode(scalarType.rawValue.lowercased(), forKey: .type)

        case .void:
            break
        }
    }
}

extension DefaultValue: Codable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Float.self) {
            self = .float(value)
        } else if let value = try? container.decode(Date.self) {
            self = .date(value)
        } else if let value = try? container.decode(String.self) {
            if value == "current_date" {
                self = .currentDate
            } else if value == "nil" {
                self = .nil
            } else if value.reversed().starts(with: "s") {
                var value = value
                value.removeLast()
                self = .seconds(Float(value) ?? 0)
            } else if value.reversed().starts(with: "ms".reversed()) {
                var value = value
                value.removeLast(2)
                self = .milliseconds(Float(value) ?? 0)
            } else if value.starts(with: ".") {
                var value = value
                value.removeFirst()
                self = .enumCase(value)
            } else {
                self = .string(value)
            }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown default value type.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension MetadataProperty: Codable {
    
    private enum Keys: String, CodingKey {
        case name
        case key
        case propertyType
        case nullable
        case legacyOptional = "optional"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        name = try container.decode(String.self, forKey: .name)

        let value = try container.decode(String.self, forKey: .propertyType)
        let propertyType: PropertyType = PropertyScalarType(value.arrayElementType()).flatMap {
            .scalar($0)
        } ?? .subtype(value.arrayElementType())
        if value.isArray {
            self.propertyType = .array(propertyType)
        } else {
            self.propertyType = propertyType
        }
        
        nullable = try container.decodeIfPresent(Bool.self, forKey: .nullable) ?? container.decodeIfPresent(Bool.self, forKey: .legacyOptional) ?? DescriptionDefaults.nullable
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(name, forKey: .name)

        func propertyTypeString(_ propertyType: PropertyType) -> String {
            switch propertyType {
            case .array(let propertyType):
                return "[\(propertyTypeString(propertyType))]"
            case .scalar(let scalarType):
                return scalarType.stringValue
            case .subtype(let subtype):
                return subtype
            }
        }
        try container.encode(propertyTypeString(propertyType), forKey: .propertyType)
        try container.encodeIfPresent(nullable == DescriptionDefaults.nullable ? nil : nullable, forKey: .nullable)
    }
}

extension EntityProperty: Codable {
    
    private enum Keys: String, CodingKey {
        case name
        case previousName
        case addedAtVersion
        case key
        case propertyType
        case nullable
        case legacyOptional = "optional"
        case defaultValue
        case logError
        case useForEquality
        case mutable
        case objc
        case unused
        case lazy
        case legacyExtra = "extra"
        case matchExactKey
        case platforms
        case persistedName
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        name = try container.decode(String.self, forKey: .name)
        previousName = try container.decodeIfPresent(String.self, forKey: .previousName)
        addedAtVersion = try container.decodeIfPresent(Version.self, forKey: .addedAtVersion)

        do {
            let relationship = try container.decode(EntityRelationship.self, forKey: .propertyType)
            propertyType = .relationship(relationship)
        } catch {
            let value = try container.decode(String.self, forKey: .propertyType)
            let propertyType: PropertyType
            if let scalarType = PropertyScalarType(value.arrayElementType()) {
                propertyType = .scalar(scalarType)
            } else {
                propertyType = .subtype(value.arrayElementType())
            }
            if value.isArray {
                self.propertyType = .array(propertyType)
            } else {
                self.propertyType = propertyType
            }
        }
        
        key = try container.decodeIfPresent(String.self, forKey: .key) ?? container.decode(String.self, forKey: .name)
        matchExactKey = try container.decodeIfPresent(Bool.self, forKey: .matchExactKey) ?? DescriptionDefaults.matchExactKey
        nullable = try container.decodeIfPresent(Bool.self, forKey: .nullable) ?? container.decodeIfPresent(Bool.self, forKey: .legacyOptional) ?? DescriptionDefaults.nullable
        defaultValue = try container.decodeIfPresent(DefaultValue.self, forKey: .defaultValue)
        logError = try container.decodeIfPresent(Bool.self, forKey: .logError) ?? DescriptionDefaults.logError
        useForEquality = try container.decodeIfPresent(Bool.self, forKey: .useForEquality) ?? DescriptionDefaults.useForEquality
        mutable = try container.decodeIfPresent(Bool.self, forKey: .mutable) ?? DescriptionDefaults.mutable
        objc = try container.decodeIfPresent(Bool.self, forKey: .objc) ?? DescriptionDefaults.objc
        unused = try container.decodeIfPresent(Bool.self, forKey: .unused) ?? DescriptionDefaults.unused
        lazy = try container.decodeIfPresent(Bool.self, forKey: .lazy) ?? container.decodeIfPresent(Bool.self, forKey: .legacyExtra) ?? DescriptionDefaults.lazy
        platforms = try container.decodeIfPresent(Set<Platform>.self, forKey: .platforms) ?? DescriptionDefaults.platforms
        persistedName = try container.decodeIfPresent(String.self, forKey: .persistedName)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(previousName, forKey: .previousName)
        try container.encodeIfPresent(addedAtVersion, forKey: .addedAtVersion)

        func propertyTypeString(_ propertyType: PropertyType) -> String {
            switch propertyType {
            case .array(let propertyType):
                return "[\(propertyTypeString(propertyType))]"
            case .scalar(let scalarType):
                return scalarType.stringValue
            case .subtype(let subType):
                return subType
            case .relationship:
                return String()
            }
        }

        switch propertyType {
        case .relationship(let relationship):
            try container.encode(relationship, forKey: .propertyType)
        default:
            try container.encode(propertyTypeString(propertyType), forKey: .propertyType)
        }

        try container.encodeIfPresent(key == name ? nil : key, forKey: .key)
        try container.encodeIfPresent(matchExactKey == DescriptionDefaults.matchExactKey ? nil : matchExactKey, forKey: .matchExactKey)
        try container.encodeIfPresent(nullable == DescriptionDefaults.nullable ? nil : nullable, forKey: .nullable)
        try container.encodeIfPresent(defaultValue, forKey: .defaultValue)
        try container.encodeIfPresent(logError == DescriptionDefaults.logError ? nil : logError, forKey: .logError)
        try container.encodeIfPresent(useForEquality == DescriptionDefaults.useForEquality ? nil : useForEquality, forKey: .useForEquality)
        try container.encodeIfPresent(mutable == DescriptionDefaults.mutable ? nil : mutable, forKey: .mutable)
        try container.encodeIfPresent(objc == DescriptionDefaults.objc ? nil : objc, forKey: .objc)
        try container.encodeIfPresent(unused == DescriptionDefaults.unused ? nil : unused, forKey: .unused)
        try container.encodeIfPresent(lazy == DescriptionDefaults.lazy ? nil : lazy, forKey: .lazy)
        try container.encodeIfPresent(platforms == DescriptionDefaults.platforms ? nil : platforms.sorted(), forKey: .platforms)
        try container.encodeIfPresent(persistedName, forKey: .persistedName)
    }
}

extension EntityRelationship: Codable {
    
    private enum Keys: String, CodingKey {
        case entityName
        case association
        case idOnly
        case failableItems
        case platforms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        entityName = try container.decode(String.self, forKey: .entityName)
        association = try container.decode(Association.self, forKey: .association)
        idOnly = try container.decodeIfPresent(Bool.self, forKey: .idOnly) ?? DescriptionDefaults.idOnly
        failableItems = try container.decodeIfPresent(Bool.self, forKey: .failableItems) ?? DescriptionDefaults.failableItems
        platforms = try container.decodeIfPresent([Platform].self, forKey: .platforms)?.sorted() ?? Array(DescriptionDefaults.platforms)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(entityName, forKey: .entityName)
        try container.encode(association, forKey: .association)
        try container.encodeIfPresent(idOnly == DescriptionDefaults.idOnly ? nil : idOnly, forKey: .idOnly)
        try container.encodeIfPresent(failableItems == DescriptionDefaults.failableItems ? nil : failableItems, forKey: .failableItems)
        try container.encodeIfPresent(platforms == Array(DescriptionDefaults.platforms) ? nil : platforms.sorted(), forKey: .platforms)
    }
}

extension EntityRelationship.Association: Codable {}

// MARK: - Subtype

extension Subtype: Decodable {
    
    private enum Keys: String, CodingKey {
        case name
        case customDecoder
        case cases
        case unusedCases
        case options
        case unusedOptions
        case properties
        case manualImplementations
        case objc
        case objcNoneCase
        case platforms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
       
        name = try container.decode(String.self, forKey: .name)
        manualImplementations = Set(try container.decodeIfPresent([`Protocol`].self, forKey: .manualImplementations) ?? [])
        platforms = try container.decodeIfPresent(Set<Platform>.self, forKey: .platforms) ?? DescriptionDefaults.platforms
        
        if let usedCases = try container.decodeIfPresent([String].self, forKey: .cases) {
            let unusedCases = try container.decodeIfPresent([String].self, forKey: .unusedCases) ?? []
            objc = try container.decodeIfPresent(Bool.self, forKey: .objc) ?? DescriptionDefaults.objcNoneCase
            let objcNoneCase = try container.decodeIfPresent(Bool.self, forKey: .objcNoneCase) ?? DescriptionDefaults.objc
            items = .cases(
                used: usedCases.sorted(),
                unused: unusedCases.sorted(),
                objcNoneCase: objcNoneCase
            )
        } else if let options = try container.decodeIfPresent([String].self, forKey: .options) {
            let unusedOptions = try container.decodeIfPresent([String].self, forKey: .unusedOptions) ?? []
            objc = try container.decodeIfPresent(Bool.self, forKey: .objc) ?? DescriptionDefaults.objc
            items = .options(
                used: options,
                unused: unusedOptions
            )
        } else if let properties = try container.decodeIfPresent([Property].self, forKey: .properties) {
            items = .properties(properties.filter { !$0.unused }.sorted { $0.name < $1.name })
            objc = try container.decodeIfPresent(Bool.self, forKey: .objc) ?? properties.contains { $0.objc }
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [Keys.cases, Keys.options, Keys.properties],
                debugDescription: "No items key was found."
            ))
        }
    }
}

extension Subtype.Property: Decodable {
    
    private enum Keys: String, CodingKey {
        case name
        case key
        case propertyType
        case nullable
        case legacyOptional = "optional"
        case objc
        case unused
        case defaultValue
        case logError
        case platforms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
      
        name = try container.decode(String.self, forKey: .name)
        key = try container.decodeIfPresent(String.self, forKey: .key)
        propertyType = try container.decode(PropertyType.self, forKey: .propertyType)
        objc = try container.decodeIfPresent(Bool.self, forKey: .objc) ?? DescriptionDefaults.objc
        unused = try container.decodeIfPresent(Bool.self, forKey: .unused) ?? DescriptionDefaults.unused
        nullable = try container.decodeIfPresent(Bool.self, forKey: .nullable) ?? container.decodeIfPresent(Bool.self, forKey: .legacyOptional) ?? DescriptionDefaults.nullable

        let defaultValue = try container.decodeIfPresent(DefaultValue.self, forKey: .defaultValue)
        let logError = try container.decodeIfPresent(Bool.self, forKey: .logError) ?? DescriptionDefaults.logError

        guard logError == true || defaultValue != nil else {
            throw DecodingError.dataCorruptedError(forKey: Keys.logError,
                                                   in: container,
                                                   debugDescription: "log_error can only be true if default value is set.")
        }

        self.defaultValue = defaultValue
        self.logError = logError
        self.platforms = try container.decodeIfPresent(Set<Platform>.self, forKey: .platforms) ?? DescriptionDefaults.platforms
    }
}

extension Subtype.Property.PropertyType: Decodable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        let value = try container.decode(String.self)
        if let scalarType = PropertyScalarType(value) {
            self = .scalar(scalarType)
        } else {
            self = .custom(value)
        }
    }
}

extension SystemProperty: Codable {

    private enum Keys: String, CodingKey {
        case name
        case addedAtVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)

        name = try container.decode(SystemPropertyName.self, forKey: .name)
        addedAtVersion = try container.decodeIfPresent(Version.self, forKey: .addedAtVersion)
        useCoreDataLegacyNaming = false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(addedAtVersion, forKey: .addedAtVersion)
    }
}

extension Version: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(try container.decode(String.self), source: .description)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
