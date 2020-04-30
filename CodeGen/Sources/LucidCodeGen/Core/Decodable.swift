//
//  Decodable.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/27/19.
//

import Foundation

// MARK: - Defaults

private enum Defaults {
    static let identifier = EntityIdentifier(identifierType: .void, equivalentIdentifierName: nil, objc: false)
    static let remote = true
    static let persist = false
    static let useForEquality = true
    static let idOnly = false
    static let failableItems = true
    static let isTarget = false
    static let optional = false
    static let mutable = false
    static let objc = false
    static let objcNoneCase = false
    static let unused = false
    static let logError = true
    static let extra = false
    static let matchExactKey = false
    static let platforms = Set<Platform>()
    static let lastRemoteRead = false
}

// MARK: - Payloads

extension EndpointPayload: Decodable {
    
    private enum Keys: String, CodingKey {
        case name
        case baseKey
        case entity
        case entityVariations
        case metadata
        case tests
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        name = try container.decode(String.self, forKey: .name).camelCased(separators: "_/")
        baseKey = try container.decodeIfPresent(String.self, forKey: .baseKey)
        entity = try container.decode(EndpointPayloadEntity.self, forKey: .entity)
        entityVariations = try container.decodeIfPresent([EndpointPayloadEntityVariation].self, forKey: .entityVariations)
        metadata = try container.decodeIfPresent([MetadataProperty].self, forKey: .metadata)
        tests = try container.decodeIfPresent([EndpointPayloadTest].self, forKey: .tests) ?? []
    }
}

extension EndpointPayloadTest: Decodable {
    
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
        name = try container.decode(String.self, forKey: .name).camelCased()
        url = try container.decode(URL.self, forKey: .url)
        httpMethod = (try? container.decode(HTTPMethod.self, forKey: .httpMethod)) ?? .get
        body = try? container.decode(String.self, forKey: .body)
        entities = try container.decode([Entity].self, forKey: .entities)
        // for parsing from previous versions
        do {
            contexts = try container.decode([String].self, forKey: .contexts).map { $0.camelCased().variableCased }
            endpoints = []
        } catch {
            endpoints = try container.decode([String].self, forKey: .endpoints)
            contexts = []
        }
    }
}

extension EndpointPayloadTest.HTTPMethod: Decodable { }

extension EndpointPayloadTest.Entity: Decodable {
    
    private enum Keys: String, CodingKey {
        case name
        case count
        case isTarget
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        name = try container.decode(String.self, forKey: .name).camelCased()
        count = try container.decodeIfPresent(Int.self, forKey: .count)
        isTarget = try container.decodeIfPresent(Bool.self, forKey: .isTarget) ?? Defaults.isTarget
    }
}

extension EndpointPayloadEntity: Decodable {
    
    private enum Keys: String, CodingKey {
        case entityKey
        case entityName
        case structure
        case optional
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        entityKey = try container.decodeIfPresent(String.self, forKey: .entityKey)
        entityName = try container.decode(String.self, forKey: .entityName).camelCased().versionedName()
        structure = try container.decode(Structure.self, forKey: .structure)
        optional = try container.decodeIfPresent(Bool.self, forKey: .optional) ?? Defaults.optional
    }
}

extension EndpointPayloadEntity.Structure: Decodable {}

// MARK: - Entity

extension Entity: Decodable {
    
    private enum Keys: String, CodingKey {
        case name
        case remote
        case previousName
        case addedAtVersion
        case persist
        case identifier
        case metadata
        case properties
        case uid
        case modelMappingHistory
        case persistedName
        case platforms
        case lastRemoteRead
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        let name = try container.decode(String.self, forKey: .name).camelCased().versionedName()
        self.name = name
        remote = try container.decodeIfPresent(Bool.self, forKey: .remote) ?? Defaults.remote
        previousName = try container.decodeIfPresent(String.self, forKey: .previousName).flatMap { try $0.camelCased().versionedName() }
        addedAtVersion = try container.decodeIfPresent(String.self, forKey: .addedAtVersion)
        persist = try container.decodeIfPresent(Bool.self, forKey: .persist) ?? Defaults.persist
        identifier = try container.decodeIfPresent(EntityIdentifier.self, forKey: .identifier) ?? Defaults.identifier
        metadata = try container.decodeIfPresent([MetadataProperty].self, forKey: .metadata)
        properties = try container.decode([EntityProperty].self, forKey: .properties).sorted(by: { $0.name < $1.name })
        identifierTypeID = try container.decodeIfPresent(String.self, forKey: .uid)
        modelMappingHistory = try container.decodeIfPresent([ModelMapping].self, forKey: .modelMappingHistory)
        persistedName = try container.decodeIfPresent(String.self, forKey: .persistedName)
        platforms = try container.decodeIfPresent(Set<Platform>.self, forKey: .platforms) ?? Defaults.platforms
        lastRemoteRead = try container.decodeIfPresent(Bool.self, forKey: .lastRemoteRead) ?? Defaults.lastRemoteRead
    }
}

extension ModelMapping: Decodable {
    
    private enum Keys: String, CodingKey {
        case from
        case to
        case ignoreMigrationChecksOn
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        ignoreMigrationChecksOn = (try container.decodeIfPresent([String].self, forKey: .ignoreMigrationChecksOn) ?? []).map {
            $0.camelCased().variableCased
        }
    }
}

extension EndpointPayloadEntityVariation: Decodable {
    
    private enum Keys: String, CodingKey {
        case entityName
        case propertyRenames
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        let snakeCaseEntityName = try container.decode(String.self, forKey: .entityName)
        self.entityName = try snakeCaseEntityName.camelCased().versionedName()
        self.propertyRenames = try container.decodeIfPresent([Rename].self, forKey: .propertyRenames)
    }
}

extension EntityIdentifier: Decodable {
    
    private enum Keys: String, CodingKey {
        case type
        case derivedFromRelationships
        case equivalentToIdentifierOf
        case propertyName
        case objc
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        objc = try container.decodeIfPresent(Bool.self, forKey: .objc) ?? Defaults.objc
        
        let lowerCaseType = try container.decode(String.self, forKey: .type)
        switch lowerCaseType {
        case "property":
            let snakeCaseName = try container.decode(String.self, forKey: .propertyName)
            identifierType = .property(snakeCaseName.camelCased().variableCased)
        default:
            do {
                let relationshipIDs: [EntityIdentifierType.RelationshipID] = try container
                    .decode([String].self, forKey: .derivedFromRelationships)
                    .map { snakeCaseEntityName in
                        let camelCaseName = snakeCaseEntityName.camelCased()
                        return EntityIdentifierType.RelationshipID(variableName: camelCaseName.variableCased,
                                                                   entityName: try camelCaseName.versionedName())
                }
                
                guard let scalarType = PropertyScalarType(lowerCaseType.capitalized) else {
                    throw DecodingError.dataCorruptedError(forKey: Keys.type, in: container, debugDescription: "Unknown value type \(lowerCaseType.capitalized).")
                }
                
                identifierType = .relationships(scalarType, relationshipIDs)
            } catch {
                guard let scalarType = PropertyScalarType(lowerCaseType.capitalized) else {
                    throw DecodingError.dataCorruptedError(forKey: Keys.type, in: container, debugDescription: "Unknown value type \(lowerCaseType.capitalized).")
                }
                identifierType = .scalarType(scalarType)
            }
        }
        
        equivalentIdentifierName = try container.decodeIfPresent(String.self, forKey: .equivalentToIdentifierOf)?.camelCased().versionedName()
    }
}

extension DefaultValue: Decodable {
    
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
            } else if value.starts(with: ".") {
                var value = value
                value.removeFirst()
                self = .enumCase(value.camelCased().variableCased)
            } else {
                self = .string(value)
            }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown default value type.")
        }
    }
}

extension MetadataProperty: Decodable {
    
    private enum Keys: String, CodingKey {
        case name
        case key
        case propertyType
        case optional
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        name = try container.decode(String.self, forKey: .name).camelCased().variableCased
        key = try container.decodeIfPresent(String.self, forKey: .key)?.camelCased().variableCased
        
        let value = try container.decode(String.self, forKey: .propertyType).capitalized.camelCased()
        let propertyType: PropertyType = try PropertyScalarType(try value.arrayElementType()).flatMap { .scalar($0) } ?? .subtype(try value.versionedName())
        if value.isArray {
            self.propertyType = .array(propertyType)
        } else {
            self.propertyType = propertyType
        }
        
        optional = try container.decodeIfPresent(Bool.self, forKey: .optional) ?? Defaults.optional
    }
}

extension EntityProperty: Decodable {
    
    private enum Keys: String, CodingKey {
        case name
        case previousName
        case addedAtVersion
        case key
        case propertyType
        case optional
        case defaultValue
        case logError
        case useForEquality
        case mutable
        case objc
        case unused
        case extra
        case matchExactKey
        case platforms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        name = try container.decode(String.self, forKey: .name)
            .split(separator: ".")
            .map { String($0).camelCased().variableCased }
            .joined(separator: "_")
        
        previousName = try container.decodeIfPresent(String.self, forKey: .previousName)?
            .split(separator: ".")
            .map { String($0).camelCased().variableCased }
            .joined(separator: "_")
        
        addedAtVersion = try container.decodeIfPresent(String.self, forKey: .addedAtVersion)
        
        do {
            let relationship = try container.decode(EntityRelationship.self, forKey: .propertyType)
            propertyType = .relationship(relationship)
        } catch {
            let value = try container.decode(String.self, forKey: .propertyType).capitalized.camelCased()
            let propertyType: PropertyType
            if let scalarType = PropertyScalarType(try value.arrayElementType()) {
                propertyType = .scalar(scalarType)
            } else {
                propertyType = .subtype(try value.arrayElementType().versionedName())
            }
            if value.isArray {
                self.propertyType = .array(propertyType)
            } else {
                self.propertyType = propertyType
            }
        }
        
        key = try container.decodeIfPresent(String.self, forKey: .key) ?? container.decode(String.self, forKey: .name)
        matchExactKey = try container.decodeIfPresent(Bool.self, forKey: .matchExactKey) ?? Defaults.matchExactKey
        optional = try container.decodeIfPresent(Bool.self, forKey: .optional) ?? Defaults.optional
        defaultValue = try container.decodeIfPresent(DefaultValue.self, forKey: .defaultValue)
        logError = try container.decodeIfPresent(Bool.self, forKey: .logError) ?? Defaults.logError
        useForEquality = try container.decodeIfPresent(Bool.self, forKey: .useForEquality) ?? Defaults.useForEquality
        mutable = try container.decodeIfPresent(Bool.self, forKey: .mutable) ?? Defaults.mutable
        objc = try container.decodeIfPresent(Bool.self, forKey: .objc) ?? Defaults.objc
        unused = try container.decodeIfPresent(Bool.self, forKey: .unused) ?? Defaults.unused
        extra = try container.decodeIfPresent(Bool.self, forKey: .extra) ?? Defaults.extra
        platforms = try container.decodeIfPresent(Set<Platform>.self, forKey: .platforms) ?? Defaults.platforms
    }
}

extension EntityRelationship: Decodable {
    
    private enum Keys: String, CodingKey {
        case entityName
        case association
        case idOnly
        case failableItems
        case platforms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        let snakeCaseEntityName = try container.decode(String.self, forKey: .entityName)
        self.entityName = try snakeCaseEntityName.camelCased().versionedName()
        self.association = try container.decode(Association.self, forKey: .association)
        self.idOnly = try container.decodeIfPresent(Bool.self, forKey: .idOnly) ?? Defaults.idOnly
        self.failableItems = try container.decodeIfPresent(Bool.self, forKey: .failableItems) ?? Defaults.failableItems
        self.platforms = try container.decodeIfPresent([Platform].self, forKey: .platforms)?.sorted() ?? []
    }
}

extension EntityRelationship.Association: Decodable {}

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
       
        name = try container.decode(String.self, forKey: .name).camelCased().versionedName()
        manualImplementations = Set(try container.decodeIfPresent([`Protocol`].self, forKey: .manualImplementations) ?? [])
        platforms = try container.decodeIfPresent(Set<Platform>.self, forKey: .platforms) ?? Defaults.platforms
        
        if let usedCases = try container.decodeIfPresent([String].self, forKey: .cases) {
            let unusedCases = try container.decodeIfPresent([String].self, forKey: .unusedCases) ?? []
            objc = try container.decodeIfPresent(Bool.self, forKey: .objc) ?? Defaults.objcNoneCase
            let objcNoneCase = try container.decodeIfPresent(Bool.self, forKey: .objcNoneCase) ?? Defaults.objc
            items = .cases(
                used: usedCases.map { $0.camelCased().variableCased }.sorted(),
                unused: unusedCases.map { $0.camelCased().variableCased }.sorted(),
                objcNoneCase: objcNoneCase
            )
        } else if let options = try container.decodeIfPresent([String].self, forKey: .options) {
            let unusedOptions = try container.decodeIfPresent([String].self, forKey: .unusedOptions) ?? []
            objc = try container.decodeIfPresent(Bool.self, forKey: .objc) ?? Defaults.objc
            items = .options(
                used: options.map { $0.camelCased().variableCased },
                unused: unusedOptions.map { $0.camelCased().variableCased }
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
        case optional
        case objc
        case unused
        case defaultValue
        case logError
        case platforms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
      
        name = try container.decode(String.self, forKey: .name).camelCased().variableCased
        key = try container.decodeIfPresent(String.self, forKey: .key)
        propertyType = try container.decode(PropertyType.self, forKey: .propertyType)
        objc = try container.decodeIfPresent(Bool.self, forKey: .objc) ?? Defaults.objc
        unused = try container.decodeIfPresent(Bool.self, forKey: .unused) ?? Defaults.unused
        optional = try container.decodeIfPresent(Bool.self, forKey: .optional) ?? Defaults.optional

        let defaultValue = try container.decodeIfPresent(DefaultValue.self, forKey: .defaultValue)
        let logError = try container.decodeIfPresent(Bool.self, forKey: .logError) ?? Defaults.logError

        guard logError == true || defaultValue != nil else {
            throw DecodingError.dataCorruptedError(forKey: Keys.logError,
                                                   in: container,
                                                   debugDescription: "log_error can only be true if default value is set.")
        }

        self.defaultValue = defaultValue
        self.logError = logError
        self.platforms = try container.decodeIfPresent(Set<Platform>.self, forKey: .platforms) ?? Defaults.platforms
    }
}

extension Subtype.Property.PropertyType: Decodable {
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        let value = try container.decode(String.self)
        if let scalarType = PropertyScalarType(value) {
            self = .scalar(scalarType)
        } else {
            self = .custom(try value.camelCased().versionedName())
        }
    }
    
    var stringRepresentation: String {
        switch self {
        case .scalar(let type): return type.rawValue
        case .custom(let value): return value
        }
    }
}
