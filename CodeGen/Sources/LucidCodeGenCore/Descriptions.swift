//
//  Descriptions.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 3/20/19.
//

import Foundation
import Meta
import PathKit

// MARK: - Descriptions

public enum Description: Equatable {
    case all
    case subtype(String)
    case entity(String)
    case endpoint(String)
    
    public var subtypeName: String? {
        if case .subtype(let name) = self {
            return name
        } else {
            return nil
        }
    }
    
    public var entityName: String? {
        if case .entity(let name) = self {
            return name
        } else {
            return nil
        }
    }
    
    public var endpointName: String? {
        if case .endpoint(let name) = self {
            return name
        } else {
            return nil
        }
    }
}

public enum TargetName: String, CaseIterable, Decodable {
    case app = "app"
    case appTests = "app_tests"
    case appTestSupport = "app_test_support"
}

public protocol Targets {
    
    var app: Target { get }
    
    var appTests: Target { get }
    
    var appTestSupport: Target { get }
}

public extension Targets {
    
    var all: [Target] {
        return [app, appTests, appTestSupport]
    }
}

public protocol Target {
    
    var name: TargetName { get }
    
    /// Target's module name. Mostly used for imports.
    var moduleName: String { get }
    
    /// Where to generate the boilerplate code.
    var outputPath: Path { get }
    
    /// Is target selected to be generated.
    var isSelected: Bool { get }
}

public typealias Platform = String

public protocol Descriptions {
    
    var subtypes: [Subtype] { get }
    
    var entities: [Entity] { get }
    
    var endpoints: [EndpointPayload] { get }
    
    var subtypesByName: [String: Subtype] { get }
    
    var entitiesByName: [String: Entity] { get }
    
    var endpointsByName: [String: EndpointPayload] { get }
    
    var targets: Targets { get }

    var version: Version { get }
}

// MARK: - EndpointPayload

public struct EndpointPayload: Equatable {
    
    public let name: String
    
    public let baseKey: String?

    public let entity: EndpointPayloadEntity
    
    public let entityVariations: [EndpointPayloadEntityVariation]?

    public let excludedPaths: [String]

    public let metadata: [MetadataProperty]?
    
    public let tests: [EndpointPayloadTest]

    public init(name: String,
                baseKey: String? = nil,
                entity: EndpointPayloadEntity,
                entityVariations: [EndpointPayloadEntityVariation]? = nil,
                excludedPaths: [String] = [],
                metadata: [MetadataProperty]? = nil,
                tests: [EndpointPayloadTest] = []) {

        self.name = name
        self.baseKey = baseKey
        self.entity = entity
        self.entityVariations = entityVariations
        self.excludedPaths = excludedPaths
        self.metadata = metadata
        self.tests = tests
    }
}

// MARK: - EndpointPayloadTest

public struct EndpointPayloadTest: Equatable {

    public enum HTTPMethod: String {
        case get
        case post
    }

    public struct Entity: Equatable {
        public let name: String
        public let count: Int?
        public let isTarget: Bool
    }
    
    public let name: String

    public let url: URL

    public let httpMethod: HTTPMethod

    public let body: String?

    // for parsing from previous versions
    public let contexts: [String]

    public let endpoints: [String]

    public let entities: [Entity]
}

// MARK: - EndpointPayloadEntity

public struct EndpointPayloadEntity: Equatable {

    public enum Structure: String {
        case single = "single"
        case array = "array"
        case nestedArray = "nested_array"
    }
    
    public let entityKey: String?

    public let entityName: String

    public let structure: Structure

    public let nullable: Bool

    public init(entityKey: String? = nil,
                entityName: String,
                structure: Structure,
                nullable: Bool = DescriptionDefaults.nullable) {

        self.entityKey = entityKey
        self.entityName = entityName
        self.structure = structure
        self.nullable = nullable
    }
}

// MARK: - Variations

public struct EndpointPayloadEntityVariation: Equatable {

    public struct Rename: Codable, Equatable {
        let originalName: String
        let customName: String
    }
    
    public let entityName: String

    public let propertyRenames: [Rename]?
}

// MARK: - PropertyScalarType

public enum PropertyScalarType: String, Equatable {
    case string = "String"
    case int = "Int"
    case date = "Date"
    case double = "Double"
    case float = "Float"
    case bool = "Bool"
    case seconds = "Seconds"
    case milliseconds = "Milliseconds"
    case url = "URL"
    case color = "Color"
}

// MARK: - MetadataProperty

public struct MetadataProperty: Equatable {

    public enum PropertyType: Equatable {
        case scalar(PropertyScalarType)
        case subtype(String)
        indirect case array(PropertyType)
    }

    public let name: String

    public let propertyType: PropertyType

    public let nullable: Bool
}

// MARK: - Entities

public struct Entity: Equatable {
    
    public let name: String
    
    public let persistedName: String?
    
    public let platforms: Set<Platform>
    
    public let remote: Bool
    
    public let persist: Bool
    
    public let identifier: EntityIdentifier
    
    public let metadata: [MetadataProperty]?
    
    public var properties: [EntityProperty]

    public var systemProperties: [SystemProperty]
    
    public let identifierTypeID: String?

    public let legacyPreviousName: String?

    public let legacyAddedAtVersion: Version?

    public let versionHistory: [VersionHistoryItem]

    public let queryContext: Bool

    public let clientQueueName: String

    public init(name: String,
                persistedName: String? = nil,
                platforms: Set<Platform> = DescriptionDefaults.platforms,
                remote: Bool = DescriptionDefaults.remote,
                persist: Bool = DescriptionDefaults.persist,
                identifier: EntityIdentifier = DescriptionDefaults.identifier,
                metadata: [MetadataProperty]? = nil,
                properties: [EntityProperty],
                systemProperties: [SystemProperty] = [],
                identifierTypeID: String? = nil,
                versionHistory: [VersionHistoryItem] = [],
                queryContext: Bool = DescriptionDefaults.queryContext,
                clientQueueName: String = DescriptionDefaults.clientQueueName) {

        self.name = name
        self.persistedName = persistedName
        self.platforms = platforms
        self.remote = remote
        self.persist = persist
        self.identifier = identifier
        self.metadata = metadata
        self.properties = properties
        self.systemProperties = systemProperties
        self.identifierTypeID = identifierTypeID
        self.legacyPreviousName = nil
        self.legacyAddedAtVersion = nil
        self.versionHistory = versionHistory
        self.queryContext = queryContext
        self.clientQueueName = clientQueueName
    }
}

// MARK: - SystemProperties

public struct SystemProperty: Equatable {

    public let name: SystemPropertyName

    public let useCoreDataLegacyNaming: Bool

    public let addedAtVersion: Version?
}

public enum SystemPropertyName: String, CaseIterable, Codable {
    case lastRemoteRead = "last_remote_read"
    case isSynced = "is_synced"
}

// MARK: - VersionHistory

public struct VersionHistoryItem: Equatable {

    public let version: Version

    public let previousName: String?

    public let ignoreMigrationChecks: Bool

    public let ignorePropertyMigrationChecksOn: [String]

    public init(version: Version,
                previousName: String? = nil,
                ignoreMigrationChecks: Bool = DescriptionDefaults.ignoreMigrationChecks,
                ignorePropertyMigrationChecksOn: [String] = DescriptionDefaults.ignorePropertyMigrationChecksOn) {

        self.version = version
        self.previousName = previousName
        self.ignoreMigrationChecks = ignoreMigrationChecks
        self.ignorePropertyMigrationChecksOn = ignorePropertyMigrationChecksOn
    }
}

// MARK: - Identifier

public struct EntityIdentifier: Equatable {
    
    public let identifierType: EntityIdentifierType
    
    public let equivalentIdentifierName: String?
    
    public let objc: Bool

    public init(identifierType: EntityIdentifierType,
                equivalentIdentifierName: String? = nil,
                objc: Bool = DescriptionDefaults.objc) {

        self.identifierType = identifierType
        self.equivalentIdentifierName = equivalentIdentifierName
        self.objc = objc
    }
}

public enum EntityIdentifierType: Equatable {

    public struct RelationshipID: Equatable {
        public let variableName: String
        public var entityName: String
    }
    
    case void
    case scalarType(PropertyScalarType)
    case relationships(PropertyScalarType, [RelationshipID])
    case property(String)
}

// MARK: - DefaultValue

public enum DefaultValue: Equatable {
    case bool(Bool)
    case float(Float)
    case int(Int)
    case string(String)
    case currentDate
    case date(Date)
    case enumCase(String)
    case `nil`
}

// MARK: - Properties

public struct EntityProperty: Equatable {
    
    public enum PropertyType: Equatable {
        case scalar(PropertyScalarType)
        case relationship(EntityRelationship)
        case subtype(String)
        indirect case array(PropertyType)
    }

    public let name: String
    
    public let key: String
    
    public let matchExactKey: Bool
    
    public let previousName: String?

    public let persistedName: String?

    public let addedAtVersion: Version?

    public let propertyType: PropertyType

    public let nullable: Bool

    public let defaultValue: DefaultValue?
    
    public let logError: Bool
    
    public let useForEquality: Bool
    
    public let mutable: Bool
    
    public let objc: Bool
    
    public let unused: Bool
    
    public let lazy: Bool
    
    public let platforms: Set<Platform>

    public init(name: String,
                key: String? = nil,
                matchExactKey: Bool = DescriptionDefaults.matchExactKey,
                previousName: String? = nil,
                persistedName: String? = nil,
                addedAtVersion: Version? = nil,
                propertyType: PropertyType,
                nullable: Bool = DescriptionDefaults.nullable,
                defaultValue: DefaultValue? = nil,
                logError: Bool = DescriptionDefaults.logError,
                useForEquality: Bool = DescriptionDefaults.useForEquality,
                mutable: Bool = DescriptionDefaults.mutable,
                objc: Bool = DescriptionDefaults.objc,
                unused: Bool = DescriptionDefaults.unused,
                lazy: Bool = DescriptionDefaults.lazy,
                platforms: Set<Platform> = DescriptionDefaults.platforms) {

        self.name = name
        self.key = key ?? name
        self.matchExactKey = matchExactKey
        self.previousName = previousName
        self.persistedName = persistedName
        self.addedAtVersion = addedAtVersion
        self.propertyType = propertyType
        self.nullable = nullable
        self.defaultValue = defaultValue
        self.logError = logError
        self.useForEquality = useForEquality
        self.mutable = mutable
        self.objc = objc
        self.unused = unused
        self.lazy = lazy
        self.platforms = platforms
    }
}

// MARK: - Relationships

public struct EntityRelationship: Equatable {

    public enum Association: String {
        case toOne = "to_one"
        case toMany = "to_many"
    }

    public let entityName: String

    public let association: Association

    public let idOnly: Bool

    public let failableItems: Bool
    
    public let platforms: [Platform]
}

// MARK: - Subtype

public struct Subtype: Equatable {
    
    public enum `Protocol`: String, Decodable {
        case codable
    }
    
    public enum Items: Equatable {
        case cases(used: [String], unused: [String], objcNoneCase: Bool)
        case options(used: [String], unused: [String])
        case properties([Property])
    }
    
    public struct Property: Equatable {
        
        public enum PropertyType: Equatable {
            case scalar(PropertyScalarType)
            case custom(String)
        }
        
        public let name: String
        public let key: String?
        public let propertyType: PropertyType
        public let nullable: Bool
        public let objc: Bool
        public let unused: Bool
        public let defaultValue: DefaultValue?
        public let logError: Bool
        public let platforms: Set<Platform>
    }
    
    public let name: String

    public var items: Items

    public let manualImplementations: Set<Protocol>
    
    public let objc: Bool
    
    public let platforms: Set<Platform>
}

// MARK: - Conversions

public extension PropertyScalarType {
    
    init?(_ stringValue: String) {
        switch stringValue.lowercased() {
        case "url":
            self = .url
        case "time":
            self = .seconds
        default:
            self.init(rawValue: stringValue.capitalized)
        }
    }

    var stringValue: String {
        switch self {
        case .url:
            return "url"
        case .seconds:
            return "time"
        default:
            return rawValue.lowercased()
        }
    }
}

extension DefaultValue: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .bool(let value):
            return value.description
        case .currentDate:
            return "current_date"
        case .date(let value):
            return value.description
        case .float(let value):
            return value.description
        case .int(let value):
            return value.description
        case .string(let value):
            return value
        case .enumCase(let value):
            return ".\(value)"
        case .`nil`:
            return "nil"
        }
    }
}

// MARK: - Equatable

public extension DefaultValue {
    
    static func == (_ lhs: DefaultValue, _ rhs: DefaultValue) -> Bool {
        return lhs.description == rhs.description
    }
}

// MARK: - Version

public struct Version: Hashable, Comparable, CustomStringConvertible {

    public enum Tag: Hashable {
        case release(ReleaseType)
        case other
    }
    
    public enum ReleaseType: String, Hashable {
        case beta
        case appStore
    }

    public enum Source: Hashable {
        case description
        case gitTag
        case coreDataModel

        var versionComponents: [String] {
            switch self {
            case .description:
                return ["(\\d+)\\.", "(\\d+)", "(\\.\\d+)?"]
            case .gitTag:
                return ["(\\d+)\\.", "(\\d+)", "(\\.\\d+)?", "(-\\d+)?"]
            case .coreDataModel:
                return ["(\\d+)_", "(\\d+)", "(_\\d+)?"]
            }
        }
    }
    
    public let versionString: String
    public let tag: Tag
    public let major: Int
    public let minor: Int
    public let patch: Int?
    public let build: Int?

    public init(_ versionString: String, source: Source) throws {
        let version = try Version.matchesForVersionComponents(source.versionComponents, in: versionString)
        guard let major = version.major, let minor = version.minor else {
            throw VersionError.couldNotFormFromString(versionString)
        }
        self.major = major
        self.minor = minor
        self.patch = version.patch
        self.build = version.build
        self.tag = Tag(versionString)
        self.versionString = versionString
    }
    
    public static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major < rhs.major { return true }
        guard lhs.major == rhs.major else { return false }

        if lhs.minor < rhs.minor { return true }
        guard lhs.minor == rhs.minor else { return false }

        if (lhs.patch ?? .min) < (rhs.patch ?? .min) { return true }
        guard lhs.patch == rhs.patch else { return false }

        if (lhs.build ?? .min) < (rhs.build ?? .min) { return true }
        guard lhs.build == rhs.build else { return false }

        guard lhs.tag < rhs.tag else { return false }
        return true
    }
    
    public static func isMatchingRelease(_ lhs: Version, _ rhs: Version) -> Bool {
        return lhs.major == rhs.major
            && lhs.minor == rhs.minor
            && lhs.patch == rhs.patch
    }

    public var description: String {
        if let build = build, let patch = patch {
            return "\(major).\(minor).\(patch) (\(build)) - \(tag.description)"
        } else if let patch = patch {
            return "\(major).\(minor).\(patch) - \(tag.description)"
        } else if let build = build {
            return "\(major).\(minor) (\(build)) - \(tag.description)"
        } else {
            return "\(major).\(minor) - \(tag.description)"
        }
    }

    public var dotDescription: String {
        if let patch = patch {
            return "\(major).\(minor).\(patch)"
        } else {
            return "\(major).\(minor)"
        }
    }

    public var sqlDescription: String {
        if let patch = patch {
            return "\(major)_\(minor)_\(patch)"
        } else {
            return "\(major)_\(minor)"
        }
    }

    private init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
        self.patch = nil
        self.build = nil
        self.tag = .other
        self.versionString = String()
    }

    public static var zeroVersion: Version { return Version(major: 0, minor: 0) }
}

private extension Version {
    
    struct UnvalidatedVersion {
        var major: Int?
        var minor: Int?
        var patch: Int?
        var build: Int?
    }
    
    static func matchesForVersionComponents(_ versionComponents: [String], in versionString: String) throws -> UnvalidatedVersion {
        let regexRange = NSRange(location: 0, length: versionString.count)
        
        let regExString = versionComponents.reduce(String()) { $0 + $1 }
        let regEx = try NSRegularExpression(pattern: regExString, options: [])
        
        let matches = regEx.matches(in: versionString, options: [.withoutAnchoringBounds], range: regexRange)
        guard let match = matches.first else {
            throw VersionError.couldNotFindMatchingPatternInString(regExString, versionString)
        }

        let unwantedCharacters = CharacterSet([".", "-", "_"])

        return try matches.lazy
            .flatMap { (0..<$0.numberOfRanges) }
            .map { match.range(at: $0) }
            .compactMap { Range($0, in: versionString) }
            .map { String(versionString[$0]) }
            .dropFirst()
            .reduce(into: UnvalidatedVersion()) { version, component in
                guard let intValue = Int(component.trimmingCharacters(in: unwantedCharacters)) else {
                    throw VersionError.couldNotFormFromString(versionString)
                }
                if component.first == "-" {
                    version.build = intValue
                } else if version.major == nil {
                    version.major = intValue
                } else if version.minor == nil {
                    version.minor = intValue
                } else {
                    version.patch = intValue
                }
            }
    }
}

public enum VersionError: Error, CustomStringConvertible {
    case couldNotFindMatchingPatternInString(_ pattern: String, _ string: String)
    case couldNotFindMatchingRangeInString(_ range: NSRange, _ string: String)
    case couldNotFormFromString(String)
    
    public var description: String {
        switch self {
        case .couldNotFindMatchingPatternInString(let pattern, let string):
            return "Could not find regular expression '\(pattern)' in string '\(string)'."
        case .couldNotFindMatchingRangeInString(let range, let string):
            return "No substring in the version string '\(string)' matched the range \(range)."
        case .couldNotFormFromString(let string):
            return "Could not form valid version from string '\(string)'"
        }
    }
}

public extension Version {
    
    var isRelease: Bool {
        switch tag {
        case .release:
            return true
        case .other:
            return false
        }
    }
    
    var isAppStoreRelease: Bool {
        switch tag {
        case .release(let releaseType):
            switch releaseType {
            case .appStore:
                return true
            case .beta:
                return false
            }
        case .other:
            return false
        }
    }

    var isBetaRelease: Bool {
        switch tag {
        case .release(let releaseType):
            switch releaseType {
            case .appStore:
                return false
            case .beta:
                return true
            }
        case .other:
            return false
        }
    }
}

extension Version.Tag: Comparable {
    
    public static func < (lhs: Version.Tag, rhs: Version.Tag) -> Bool {
        switch (lhs, rhs) {
        case (.other, .release):
            return true
        case (.other, _),
             (.release, _):
            return false
        }
    }
}

extension Version.ReleaseType: Comparable {
    
    public static func < (lhs: Version.ReleaseType, rhs: Version.ReleaseType) -> Bool {
        switch (lhs, rhs) {
        case (.beta, .appStore):
            return true
        case (.beta, _),
             (.appStore, _):
            return false
        }
    }
}

private extension Version.Tag {

    init(_ versionString: String) {
        if let releaseType = Version.ReleaseType(versionString) {
            self = .release(releaseType)
        } else {
            self = .other
        }
    }

    var description: String {
        switch self {
        case .release(let releaseType):
            return releaseType.rawValue
        case .other:
            return "other"
        }
    }
}

private extension Version.ReleaseType {
    
    init?(_ versionString: String) {
        if versionString.contains("beta_release_") {
            self = .beta
        } else if versionString.contains("release_") {
            self = .appStore
        } else {
            return nil
        }
    }
}
