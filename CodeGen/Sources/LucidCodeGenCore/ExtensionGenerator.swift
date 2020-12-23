//
//  ExtensionGenerator.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 12/23/20.
//

import Foundation
import PathKit
import Meta

public struct GeneratorParameters: Codable {

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

public struct ExtensionGeneratorConfiguration: Codable {

    public let name: String

    public let outputDirectory: OutputDirectory

    public let targetName: TargetName

    public init(name: String,
                outputDirectory: OutputDirectory,
                targetName: TargetName) {

        self.name = name
        self.outputDirectory = outputDirectory
        self.targetName = targetName
    }
}

public struct ExtensionGeneratorInput: Codable {

    public let parameters: GeneratorParameters

    public let elements: [Description]

    public let directory: Path

    public let organizationName: String

    public init(paramters: GeneratorParameters,
                elements: [Description],
                directory: Path,
                organizationName: String) {
        self.parameters = paramters
        self.elements = elements
        self.directory = directory
        self.organizationName = organizationName
    }
}
