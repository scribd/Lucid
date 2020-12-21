//
//  SwiftCodeGenerator.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 12/4/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import LucidCodeGen
import LucidCodeGenCore
import PathKit
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

final class SwiftCodeGenerator {
 
    private let generators: [InternalSwiftCodeGenerator]
    
    init(to target: Target,
         descriptions: [Version: Descriptions],
         appVersion: Version,
         historyVersions: [Version],
         shouldGenerateDataModel: Bool,
         descriptionsHash: String,
         responseHandlerFunction: String?,
         coreDataMigrationsFunction: String?,
         reactiveKit: Bool,
         useCoreDataLegacyNaming: Bool,
         organizationName: String,
         logger: Logger) throws {

        guard let latestDescription = descriptions[appVersion] else {
            try logger.throwError("Could not find description for latest app version \(appVersion).")
        }

        let platforms = latestDescription.platforms.sorted()
        let descriptionVariants: [(Platform?, [Version: Descriptions])]

        if platforms.isEmpty {
            descriptionVariants = [(nil, descriptions)]
        } else {
            descriptionVariants = platforms.map { platform in
                (platform, descriptions.mapValues { $0.variant(for: platform) })
            }
        }

        generators = descriptionVariants.map {
            if let platform = $0 {
                logger.moveToChild("Determine oldest data model version for \(platform).")
            } else {
                logger.moveToChild("Determine oldest data model version.")
            }
            let oldestModelVersion: Version
            do {
                guard let currentDescriptions = descriptions[appVersion] else {
                    try logger.throwError("Could not find current descriptions.")
                }
                oldestModelVersion = try SwiftCodeGenerator.determineOldestXcdatamodelVersion(using: currentDescriptions, platform: $0, logger: logger) ?? appVersion
                logger.info("Oldest model version is set at \(oldestModelVersion).")
            } catch {
                logger.warn("\(error) Defaulting to current version \(appVersion).")
                oldestModelVersion = appVersion
            }
            logger.moveToParent()

            return InternalSwiftCodeGenerator(
                to: target,
                descriptions: $1,
                appVersion: appVersion,
                oldestModelVersion: oldestModelVersion,
                historyVersions: historyVersions,
                shouldGenerateDataModel: shouldGenerateDataModel,
                descriptionsHash: descriptionsHash,
                platform: $0,
                responseHandlerFunction: responseHandlerFunction,
                coreDataMigrationsFunction: coreDataMigrationsFunction,
                reactiveKit: reactiveKit,
                useCoreDataLegacyNaming: useCoreDataLegacyNaming,
                organizationName: organizationName,
                logger: logger
            )
        }
    }
    
    func generate() throws {
        for generator in generators {
            try generator.generate()
        }
    }

    private static func determineOldestXcdatamodelVersion(using descriptions: Descriptions,
                                                          platform: Platform?,
                                                          logger: Logger) throws -> Version? {
        let target = descriptions.targets.app
        let appModuleName = target.moduleName
        let prefix = appModuleName
        let suffix = ".xcdatamodel"

        var path = target.outputPath
        if let platform = platform {
            path = path + Path(platform)
        }
        path = path + OutputDirectory.coreDataModelVersion.path(appModuleName: appModuleName)
        let children = try path.children()

        let allVersions: [Version] = try children.filter { $0.string.hasSuffix(suffix) }.map {
            let filename = $0.lastComponent
            var versionName = filename
            if versionName.hasPrefix(prefix) {
                versionName = String(versionName.dropFirst(prefix.count))
            }
            if versionName.hasSuffix(suffix) {
                versionName = String(versionName.dropLast(suffix.count))
            }

            if let version = try? Version(versionName, source: .description) {
                return version
            } else {
                try logger.throwError("Unable to parse version from model name \(filename).")
            }
        }

        return allVersions.sorted().first
    }
}

private final class InternalSwiftCodeGenerator {
    
    private let target: Target
    private let descriptions: [Version: Descriptions]
    private let appVersion: Version
    private let oldestModelVersion: Version
    private let historyVersions: [Version]
    private let shouldGenerateDataModel: Bool
    private let descriptionsHash: String
    private let platform: Platform?
    private let responseHandlerFunction: String?
    private let coreDataMigrationsFunction: String?
    private let reactiveKit: Bool
    private let useCoreDataLegacyNaming: Bool
    private let organizationName: String

    private let logger: Logger
    
    private var currentDescriptions: Descriptions {
        guard let currentDescriptions = descriptions[appVersion] else {
            fatalError("Could not find descriptions for version: \(appVersion)")
        }
        return currentDescriptions
    }

    private lazy var sqliteFileName = "\(currentDescriptions.targets.app.moduleName)_\(appVersion.sqlDescription).sqlite"

    private lazy var sqliteFiles: [String] = (target.outputPath + "\(platform.flatMap { "\($0)/" } ?? "")SQLite")
        .glob("*.sqlite")
        .map { $0.lastComponent }
        .filter { $0 != sqliteFileName }
        .sorted()
    
    private lazy var sqliteFile = Path("SQLite") + sqliteFileName

    init(to target: Target,
         descriptions: [Version: Descriptions],
         appVersion: Version,
         oldestModelVersion: Version,
         historyVersions: [Version],
         shouldGenerateDataModel: Bool,
         descriptionsHash: String,
         platform: Platform?,
         responseHandlerFunction: String?,
         coreDataMigrationsFunction: String?,
         reactiveKit: Bool,
         useCoreDataLegacyNaming: Bool,
         organizationName: String,
         logger: Logger) {
        
        self.target = target
        self.descriptions = descriptions
        self.appVersion = appVersion
        self.oldestModelVersion = oldestModelVersion
        self.historyVersions = historyVersions
        self.shouldGenerateDataModel = shouldGenerateDataModel
        self.descriptionsHash = descriptionsHash
        self.platform = platform
        self.responseHandlerFunction = responseHandlerFunction
        self.coreDataMigrationsFunction = coreDataMigrationsFunction
        self.reactiveKit = reactiveKit
        self.useCoreDataLegacyNaming = useCoreDataLegacyNaming
        self.organizationName = organizationName
        self.logger = logger
    }
    
    func generate() throws {
        
        logger.moveToChild("Generating Code \(platform.flatMap { "for platform: \($0), " } ?? "")for target: '\(target.name.rawValue)'...")

        let parameters = GeneratorParameters(
            appVersion: appVersion,
            coreDataMigrationsFunction: coreDataMigrationsFunction,
            currentDescriptions: currentDescriptions,
            currentDescriptionsHash: descriptionsHash,
            descriptions: descriptions,
            historyVersions: historyVersions,
            targetModuleName: target.moduleName,
            oldestModelVersion: oldestModelVersion,
            platform: platform,
            reactiveKit: reactiveKit,
            responseHandlerFunction: responseHandlerFunction,
            shouldGenerateDataModel: shouldGenerateDataModel,
            sqliteFile: sqliteFile,
            sqliteFiles: sqliteFiles,
            useCoreDataLegacyNaming: useCoreDataLegacyNaming
        )

        let generators: [Generator] = [
            SubtypesGenerator(parameters),
            EntitiesGenerator(parameters),
            EndpointPayloadsGenerator(parameters),
            CoreManagerContainersGenerator(parameters),
            SupportUtilsGenerator(parameters),
            EntityGraphGenerator(parameters),
            CoreDataXCDataModelGenerator(parameters),
            PayloadTestsGenerator(parameters),
            CoreDataTestsGenerator(parameters),
            ExportSQLiteFileTestGenerator(parameters),
            CoreDataMigrationTestsGenerator(parameters),
            FactoriesGenerator(parameters),
            SpyGenerator(parameters)
        ]

        for generator in generators {
            try generate(with: generator)
        }

        logger.moveToParent()
    }
    
    private func generate(with generator: Generator) throws {

        guard let descriptions = self.descriptions[appVersion] else {
            fatalError("Could not find descriptions for version: \(appVersion)")
        }

        guard generator.targetName == target.name else { return }
        
        logger.moveToChild("Generating \(generator.name)...")
        
        let directory: Path = {
            var _directory = target.outputPath
            if let platform = platform {
                _directory = _directory + Path(platform)
            }
            return _directory + generator.outputDirectory.path(appModuleName: descriptions.targets.app.moduleName)
        }()
        
        let preExistingFiles = Set(directory.glob("*.swift").map { $0.string })
        var generatedFiles = Set<String>()
        
        for element in descriptions {
            do {
                guard let file = try generator.generate(for: element, in: directory, organizationName: organizationName) else {
                    continue
                }
                try file.path.parent().mkpath()
                try file.path.write(file.content)
                generatedFiles.insert(file.path.string)
                logger.done("Generated \(file.path).")
            } catch {
                logger.error("Failed to generate '\(element)'.")
                throw error
            }
        }

        let extraFiles = preExistingFiles.subtracting(generatedFiles).map { Path($0) }
        if generator.deleteExtraFiles && extraFiles.isEmpty == false {
            logger.moveToChild("Deleting Extra Files...")

            for file in extraFiles where file.exists {
                try file.delete()
                logger.done("Deleted \(file).")
            }

            logger.moveToParent()
        }
        
        logger.moveToParent()
    }
}
