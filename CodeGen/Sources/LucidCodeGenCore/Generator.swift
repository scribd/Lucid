//
//  Generator.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 3/20/19.
//

import Meta
import PathKit

public struct SwiftFile {
    
    public let content: String
    
    public let path: Path

    public init(content: String, path: Path) {
        self.content = content
        self.path = path
    }
}

public struct GeneratorParameters {

    public let appVersion: Version

    public let coreDataMigrationsFunction: String?

    public let currentDescriptions: Descriptions

    public let currentDescriptionsHash: String

    public let descriptions: [Version: Descriptions]

    public let historyVersions: [Version]

    public let targetModuleName: String

    public let oldestModelVersion: Version

    public let platform: Platform?

    public let reactiveKit: Bool

    public let responseHandlerFunction: String?

    public let shouldGenerateDataModel: Bool

    public let sqliteFile: Path

    public let sqliteFiles: [String]

    public let useCoreDataLegacyNaming: Bool

    public init(appVersion: Version,
                coreDataMigrationsFunction: String?,
                currentDescriptions: Descriptions,
                currentDescriptionsHash: String,
                descriptions: [Version: Descriptions],
                historyVersions: [Version],
                targetModuleName: String,
                oldestModelVersion: Version,
                platform: Platform?,
                reactiveKit: Bool,
                responseHandlerFunction: String?,
                shouldGenerateDataModel: Bool,
                sqliteFile: Path,
                sqliteFiles: [String],
                useCoreDataLegacyNaming: Bool) {

        self.appVersion = appVersion
        self.coreDataMigrationsFunction = coreDataMigrationsFunction
        self.currentDescriptions = currentDescriptions
        self.currentDescriptionsHash = currentDescriptionsHash
        self.descriptions = descriptions
        self.historyVersions = historyVersions
        self.targetModuleName = targetModuleName
        self.oldestModelVersion = oldestModelVersion
        self.platform = platform
        self.reactiveKit = reactiveKit
        self.responseHandlerFunction = responseHandlerFunction
        self.shouldGenerateDataModel = shouldGenerateDataModel
        self.sqliteFile = sqliteFile
        self.sqliteFiles = sqliteFiles
        self.useCoreDataLegacyNaming = useCoreDataLegacyNaming
    }
}

public protocol Generator {

    init(_ parameters: GeneratorParameters)
    
    var name: String { get }

    var outputDirectory: OutputDirectory { get }

    var targetName: TargetName { get }

    var deleteExtraFiles: Bool { get }

    func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile?
}

extension Generator {

    public var deleteExtraFiles: Bool { return false }
}

public protocol ExtensionsGenerator {

    var name: String { get }

    func generate(for element: Description, in directory: Path, organizationName: String) throws -> [SwiftFile]
}

public extension File {
    
    func swiftFile(in directory: Path) -> SwiftFile {
        return SwiftFile(content: swiftString, path: directory + name)
    }
}

public enum OutputDirectory {
    case entities
    case payloads
    case endpointPayloads
    case subtypes
    case support
    case factories
    case doubles
    case coreDataModel(version: Version)
    case coreDataModelVersion
    case jsonPayloads(String)
    case payloadTests
    case coreDataTests
    case coreDataMigrationTests
    case sqliteFiles
    case extensions
}
