//
//  SwiftCodeGenerator.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 12/4/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import LucidCodeGen
import PathKit
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

final class SwiftCodeGenerator {
 
    private let generators: [InternalSwiftCodeGenerator]
    
    init(to target: Target,
         descriptions: [String: Descriptions],
         appVersion: String,
         shouldGenerateDataModel: Bool,
         descriptionsHash: String,
         responseHandlerFunction: String?,
         coreDataMigrationsFunction: String?,
         reactiveKit: Bool,
         useCoreDataLegacyNaming: Bool,
         lexicon: [String],
         entitySuffix: String,
         logger: Logger) {

        String.Configuration.setLexicon(lexicon)
        String.Configuration.entitySuffix = entitySuffix

        let platforms = Set(descriptions.flatMap { $0.value.platforms }).sorted()
        let descriptionVariants: [(Platform?, [String: Descriptions])]
        
        if platforms.isEmpty {
            descriptionVariants = [(nil, descriptions)]
        } else {
            descriptionVariants = platforms.map { platform in
                (platform, descriptions.mapValues { $0.variant(for: platform) })
            }
        }
        
        generators = descriptionVariants.map {
            InternalSwiftCodeGenerator(to: target,
                                       descriptions: $1,
                                       appVersion: appVersion,
                                       shouldGenerateDataModel: shouldGenerateDataModel,
                                       descriptionsHash: descriptionsHash,
                                       platform: $0,
                                       responseHandlerFunction: responseHandlerFunction,
                                       coreDataMigrationsFunction: coreDataMigrationsFunction,
                                       reactiveKit: reactiveKit,
                                       useCoreDataLegacyNaming: useCoreDataLegacyNaming,
                                       logger: logger)
        }
    }
    
    func generate() throws {
        for generator in generators {
            try generator.generate()
        }
    }
}

private final class InternalSwiftCodeGenerator {
    
    private let target: Target
    private let descriptions: [String: Descriptions]
    private let appVersion: String
    private let shouldGenerateDataModel: Bool
    private let descriptionsHash: String
    private let platform: Platform?
    private let responseHandlerFunction: String?
    private let coreDataMigrationsFunction: String?
    private let reactiveKit: Bool
    private let useCoreDataLegacyNaming: Bool
    
    private let logger: Logger
    
    private var currentDescriptions: Descriptions {
        guard let currentDescriptions = descriptions[appVersion] else {
            fatalError("Could not find descriptions for version: \(appVersion)")
        }
        return currentDescriptions
    }

    private lazy var sqliteFileName = "\(currentDescriptions.targets.app.moduleName)_\(appVersion.replacingOccurrences(of: ".", with: "_")).sqlite"

    private lazy var sqliteFiles: [String] = (target.outputPath + "\(platform.flatMap { "\($0)/" } ?? "")SQLite")
        .glob("*.sqlite")
        .map { $0.lastComponent }
        .filter { $0 != sqliteFileName }
        .sorted()
    
    private lazy var sqliteFile = Path("SQLite") + sqliteFileName

    init(to target: Target,
         descriptions: [String: Descriptions],
         appVersion: String,
         shouldGenerateDataModel: Bool,
         descriptionsHash: String,
         platform: Platform?,
         responseHandlerFunction: String?,
         coreDataMigrationsFunction: String?,
         reactiveKit: Bool,
         useCoreDataLegacyNaming: Bool,
         logger: Logger) {
        
        self.target = target
        self.descriptions = descriptions
        self.appVersion = appVersion
        self.shouldGenerateDataModel = shouldGenerateDataModel
        self.descriptionsHash = descriptionsHash
        self.platform = platform
        self.responseHandlerFunction = responseHandlerFunction
        self.coreDataMigrationsFunction = coreDataMigrationsFunction
        self.reactiveKit = reactiveKit
        self.useCoreDataLegacyNaming = useCoreDataLegacyNaming
        self.logger = logger
    }
    
    func generate() throws {
        
        logger.moveToChild("Generating Code \(platform.flatMap { "for platform: \($0), " } ?? "")for target: '\(target.name.rawValue)'...")
        
        // App Target
        
        try generate(with: SubtypesGenerator(descriptions: currentDescriptions, reactiveKit: reactiveKit),
                     in: .subtypes,
                     for: .app,
                     deleteExtraFiles: true)
        
        try generate(with: EntitiesGenerator(descriptions: currentDescriptions,
                                             reactiveKit: reactiveKit,
                                             useCoreDataLegacyNaming: useCoreDataLegacyNaming),
                     in: .entities,
                     for: .app,
                     deleteExtraFiles: true)
        
        try generate(with: EndpointPayloadsGenerator(descriptions: currentDescriptions, reactiveKit: reactiveKit),
                     in: .payloads,
                     for: .app,
                     deleteExtraFiles: true)
        
        try generate(with: CoreManagerContainersGenerator(descriptions: currentDescriptions,
                                                          responseHandlerFunction: responseHandlerFunction,
                                                          coreDataMigrationsFunction: coreDataMigrationsFunction,
                                                          reactiveKit: reactiveKit),
                     in: .support,
                     for: .app)

        try generate(with: LocalStoreCleanupManagerGenerator(descriptions: currentDescriptions, reactiveKit: reactiveKit),
                     in: .support,
                     for: .app)
        
        try generate(with: EntityGraphGenerator(descriptions: currentDescriptions,
                                                reactiveKit: reactiveKit,
                                                useCoreDataLegacyNaming: useCoreDataLegacyNaming),
                     in: .support,
                     for: .app)

        if shouldGenerateDataModel {
            try generate(with: CoreDataXCDataModelGenerator(version: appVersion,
                                                            useCoreDataLegacyNaming: useCoreDataLegacyNaming,
                                                            descriptions: descriptions),
                         in: .coreDataModel(version: appVersion),
                         for: .app)
        }
        
        // App Tests Target

        try generate(with: PayloadTestsGenerator(descriptions: currentDescriptions, reactiveKit: reactiveKit),
                     in: .payloadTests,
                     for: .appTests,
                     deleteExtraFiles: true)
        
        try generate(with: CoreDataTestsGenerator(descriptions: currentDescriptions, reactiveKit: reactiveKit),
                     in: .coreDataTests,
                     for: .appTests,
                     deleteExtraFiles: true)
        
        if shouldGenerateDataModel {
            try generate(with: ExportSQLiteFileTestGenerator(descriptions: currentDescriptions,
                                                             descriptionsHash: descriptionsHash,
                                                             sqliteFile: sqliteFile,
                                                             platform: platform,
                                                             reactiveKit: reactiveKit),
                         in: .coreDataMigrationTests,
                         for: .appTests)

            try generate(with: CoreDataMigrationTestsGenerator(descriptions: currentDescriptions,
                                                               sqliteFiles: sqliteFiles,
                                                               appVersion: appVersion,
                                                               platform: platform,
                                                               reactiveKit: reactiveKit),
                         in: .coreDataMigrationTests,
                         for: .appTests)
        }

        // App Test Support Target
        
        try generate(with: FactoriesGenerator(descriptions: currentDescriptions, reactiveKit: reactiveKit),
                     in: .factories,
                     for: .appTestSupport,
                     deleteExtraFiles: true)

        try generate(with: SpyGenerator(descriptions: currentDescriptions, reactiveKit: reactiveKit),
                     in: .doubles,
                     for: .appTestSupport,
                     deleteExtraFiles: true)

        logger.moveToParent()
    }
    
    private func generate<G: Generator>(with generator: G,
                                        in directory: OutputDirectory,
                                        for targetName: TargetName,
                                        deleteExtraFiles: Bool = false) throws {

        guard let descriptions = self.descriptions[appVersion] else {
            fatalError("Could not find descriptions for version: \(appVersion)")
        }

        guard targetName == target.name else { return }
        
        logger.moveToChild("Generating \(generator.name)...")
        
        let directory: Path = {
            var _directory = target.outputPath
            if let platform = platform {
                _directory = _directory + Path(platform)
            }
            return _directory + directory.path(appModuleName: descriptions.targets.app.moduleName)
        }()
        
        let preExistingFiles = Set(directory.glob("*.swift").map { $0.string })
        var generatedFiles = Set<String>()
        
        for element in descriptions {
            do {
                guard let file = try generator.generate(for: element, in: directory) else {
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
        if deleteExtraFiles && extraFiles.isEmpty == false {
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
