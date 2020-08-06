//
//  main.swift
//  ParsingTester
//
//  Created by Stephane Magne on 12/4/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import LucidCodeGen
import LucidCodeGenCore
import Commander
import PathKit

// MARK: - Commands

let main = Group {

    $0.command(
        "swift",
        Option<String>("config-path", default: ".lucid.yaml", description: "Configuration file location."),
        Option<String>("current-version", default: String(), description: "Current app version."),
        Option<String>("cache-path", default: String(), description: "Cache files location."),
        Option<String>("no-repo-update", default: String(), description: "Skips repository update for version checking."),
        Option<String>("force-build-new-db-model", default: String(), description: "Force to build a new Database Model regardless of changes."),
        VariadicOption<String>("force-build-new-db-model-for-versions", default: [], description: "Force to build a new Database Model regardless of changes for versions."),
        Option<String>("reactive-kit", default: String(), description: "Weither to use ReactiveKit's API."),
        VariadicOption<String>("selected-targets", default: [], description: "List of targets to generate.")
    ) { configPath, currentVersion, cachePath, noRepoUpdate, forceBuildNewDBModel, forceBuildNewDBModelForVersions, reactiveKit, selectedTargets in
        
        let logger = Logger()

        logger.moveToChild("Reading configuration file.")
        let configuration = try SwiftCommandConfiguration.make(with: configPath,
                                                               currentVersion: currentVersion.isEmpty ? nil : currentVersion,
                                                               cachePath: cachePath.isEmpty ? nil : cachePath,
                                                               noRepoUpdate: noRepoUpdate == "true" ? true : noRepoUpdate == "false" ? false : nil,
                                                               forceBuildNewDBModel: forceBuildNewDBModel == "true" ? true : forceBuildNewDBModel == "false" ? false : nil,
                                                               forceBuildNewDBModelForVersions: forceBuildNewDBModelForVersions.isEmpty ? nil : Set(forceBuildNewDBModelForVersions),
                                                               selectedTargets: Set(selectedTargets),
                                                               reactiveKit: reactiveKit == "true" ? true : reactiveKit == "false" ? false : nil,
                                                               logger: logger)

        let currentAppVersion = try Version(configuration.currentVersion, source: .description)
        let currentDescriptionsParser = DescriptionsParser(inputPath: configuration.inputPath,
                                                           targets: configuration.targets,
                                                           logger: logger)
        let currentDescriptions = try currentDescriptionsParser.parse(version: currentAppVersion)

        logger.moveToChild("Validating entity version histories")
        try validateEntityVersionHistory(using: currentDescriptions, logger: logger)
        logger.moveToParent()

        logger.moveToParent()

        logger.moveToChild("Resolving release tags.")
        
        let descriptionsVersionManager = try DescriptionsVersionManager(workingPath: configuration._workingPath,
                                                                        outputPath: configuration.cachePath,
                                                                        inputPath: configuration._inputPath,
                                                                        gitRemote: configuration.gitRemote,
                                                                        noRepoUpdate: configuration.noRepoUpdate,
                                                                        logger: logger)

        var modelMappingHistoryVersions = try currentDescriptions.modelMappingHistory(derivedFrom: descriptionsVersionManager.allVersionsFromGitTags())
        modelMappingHistoryVersions.removeAll { $0 == currentAppVersion }

        var descriptions = try modelMappingHistoryVersions.reduce(into: [Version: Descriptions]()) { descriptions, appVersion in
            guard appVersion < currentAppVersion else { return }
            let releaseTag = try descriptionsVersionManager.resolveLatestReleaseTag(excluding: false, appVersion: appVersion)
            let descriptionsPath = try descriptionsVersionManager.fetchDescriptionsVersion(releaseTag: releaseTag)
            let descriptionsParser = DescriptionsParser(inputPath: descriptionsPath, logger: Logger(level: .none))
            descriptions[appVersion] = try descriptionsParser.parse(version: appVersion)
        }
        
        descriptions[currentAppVersion] = currentDescriptions
        
        let _shouldGenerateDataModel: Bool
        if configuration.forceBuildNewDBModel || forceBuildNewDBModelForVersions.contains(currentVersion) {
            _shouldGenerateDataModel = true
        } else if let latestReleaseTag = try? descriptionsVersionManager.resolveLatestReleaseTag(excluding: true,
                                                                                                 appVersion: currentAppVersion) {
            
            let latestDescriptionsPath = try descriptionsVersionManager.fetchDescriptionsVersion(releaseTag: latestReleaseTag)
            let latestDescriptionsParser = DescriptionsParser(inputPath: latestDescriptionsPath,
                                                              targets: configuration.targets,
                                                              logger: Logger(level: .none))
            let appVersion = try Version(latestReleaseTag, source: .description)
            let latestDescriptions = try latestDescriptionsParser.parse(version: appVersion)

            _shouldGenerateDataModel = try shouldGenerateDataModel(byComparing: latestDescriptions,
                                                                   to: currentDescriptions,
                                                                   appVersion: currentAppVersion,
                                                                   logger: logger)
            
            try validateDescriptions(byComparing: latestDescriptions,
                                     to: currentDescriptions,
                                     logger: logger)
        } else {
            _shouldGenerateDataModel = false
        }
        logger.moveToParent()
        
        logger.moveToChild("Starting code generation...")
        for target in configuration.targets.all where target.isSelected {
            let descriptionsHash = try descriptionsVersionManager.descriptionsHash(absoluteInputPath: configuration.inputPath)
            let generator = try SwiftCodeGenerator(to: target,
                                                   descriptions: descriptions,
                                                   appVersion: currentAppVersion,
                                                   historyVersions: modelMappingHistoryVersions,
                                                   shouldGenerateDataModel: _shouldGenerateDataModel,
                                                   descriptionsHash: descriptionsHash,
                                                   responseHandlerFunction: configuration.responseHandlerFunction,
                                                   coreDataMigrationsFunction: configuration.coreDataMigrationsFunction,
                                                   reactiveKit: configuration.reactiveKit,
                                                   useCoreDataLegacyNaming: configuration.useCoreDataLegacyNaming,
                                                   organizationName: configuration.organizationName,
                                                   logger: logger)
            try generator.generate()
        }
        logger.moveToParent()
        
        logger.br()
        logger.done("Finished successfully.")
    }
    
    $0.command(
        "json-payloads",
        Option<String>("input-path", default: ".", description: "Description files location."),
        Option<String>("output-path", default: "generated", description: "Where to generate JSON payloads."),
        Option<String>("auth-token", default: "", description: "Authorization token."),
        VariadicOption<String>("endpoint", default: [], description: "Specific endpoint to fetch.")
    ) { inputPath, outputPath, authToken, endpoints in
        
        let logger = Logger()
        let parser = DescriptionsParser(inputPath: Path(inputPath), logger: logger)
        let descriptions = try parser.parse(version: Version.zeroVersion)
        
        let authToken = authToken.isEmpty ? nil : authToken
        let generator = JSONPayloadsGenerator(to: Path(outputPath),
                                              descriptions: descriptions,
                                              authToken: authToken,
                                              endpointFilter: endpoints.isEmpty ? nil : endpoints,
                                              logger: logger)
        try generator.generate()
    }

    $0.command(
        "bootstrap",
        Option<String>("config-path", default: ".lucid.yaml", description: "Configuration file location."),
        Option<String>("source-code-path", default: String(), description: "Source code directory location.")
    ) { configPath, sourceCodePathString in

        let logger = Logger()
        logger.moveToChild("Reading configuration file.")
        let configuration = try SwiftCommandConfiguration.make(with: configPath)
        logger.moveToParent()

        logger.moveToChild("Generating folders.")
        if configuration.inputPath.exists == false {
            logger.info("Adding \(configuration.inputPath).")
            try configuration.inputPath.mkdir()

            let endpointsPath = configuration.inputPath + OutputDirectory.endpointPayloads.path(appModuleName: configuration.targets.app.moduleName)
            logger.info("Adding \(endpointsPath).")
            try endpointsPath.mkdir()

            let entitiesPath = configuration.inputPath + OutputDirectory.entities.path(appModuleName: configuration.targets.app.moduleName)
            logger.info("Adding \(entitiesPath).")
            try entitiesPath.mkdir()

            let subtypesPath = configuration.inputPath + OutputDirectory.subtypes.path(appModuleName: configuration.targets.app.moduleName)
            logger.info("Adding \(subtypesPath).")
            try subtypesPath.mkdir()
        } else {
            logger.info("Folder \(configuration.inputPath) already exists.")
        }

        let lucidSourcePath = Path(sourceCodePathString)
        if let customExtensionsPath = configuration.customExtensionsPath {

            // Directories

            if customExtensionsPath.exists == false {
                logger.info("Adding \(customExtensionsPath).")
                try customExtensionsPath.mkdir()
            } else {
                logger.info("Folder \(customExtensionsPath) already exists.")
            }

            let targetExtensionsDirectory = customExtensionsPath + Extensions.DirectoryName.extensions
            if targetExtensionsDirectory.exists == false {
                logger.info("Adding \(targetExtensionsDirectory).")
                try targetExtensionsDirectory.mkdir()
            } else {
                logger.info("Folder \(targetExtensionsDirectory) already exists.")
            }

            let targetSourcesDirectory = customExtensionsPath + "Sources"
            if targetSourcesDirectory.exists == false {
                logger.info("Adding \(targetSourcesDirectory).")
                try targetSourcesDirectory.mkdir()
            } else {
                logger.info("Folder \(targetSourcesDirectory) already exists.")
            }

            let targetCodeGenCustomDirectory = customExtensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenCustomExtensions
            if targetCodeGenCustomDirectory.exists == false {
                logger.info("Adding \(targetCodeGenCustomDirectory).")
                try targetCodeGenCustomDirectory.mkdir()
            } else {
                logger.info("Folder \(targetCodeGenCustomDirectory) already exists.")
            }

            let targetGeneratorsDirectory = customExtensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenCustomExtensions + Extensions.DirectoryName.generators
            if targetGeneratorsDirectory.exists == false {
                logger.info("Adding \(targetGeneratorsDirectory).")
                try targetGeneratorsDirectory.mkdir()
            } else {
                logger.info("Folder \(targetGeneratorsDirectory) already exists.")
            }

            let targetMetaDirectory = customExtensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenCustomExtensions + Extensions.DirectoryName.meta
            if targetMetaDirectory.exists == false {
                logger.info("Adding \(targetMetaDirectory).")
                try targetMetaDirectory.mkdir()
            } else {
                logger.info("Folder \(targetMetaDirectory) already exists.")
            }

            // Symlink Directories

            let targetCodeGenCoreLink = customExtensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenCore
            if targetCodeGenCoreLink.exists == false {
                logger.info("Adding symlink \(targetCodeGenCoreLink).")
                let sourceCodeGenCoreLink = lucidSourcePath + Extensions.SourcePath.Directory.lucidCodeGenCore
                try targetCodeGenCoreLink.relativeSymlink(sourceCodeGenCoreLink)
            } else {
                logger.info("Folder symlink \(targetCodeGenCoreLink) already exists.")
            }

            let targetCommandLink = customExtensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCommandCustomExtensions
            if targetCommandLink.exists == false {
                logger.info("Adding symlink \(targetCommandLink).")
                let sourceCommandLink = lucidSourcePath + Extensions.SourcePath.Directory.lucidCommandCustomExtensions
                try targetCommandLink.relativeSymlink(sourceCommandLink)
            } else {
                logger.info("Folder symlink  \(targetCommandLink) already exists.")
            }

            // Files

            let targetMakefilePath = customExtensionsPath + Extensions.FileName.makefile
            if targetMakefilePath.exists == false {
                logger.info("Adding \(targetMakefilePath).")
                let sourceMakefilePath = lucidSourcePath + Extensions.SourcePath.File.makefile
                try sourceMakefilePath.copy(targetMakefilePath)
            } else {
                logger.info("File \(targetMakefilePath) already exists.")
            }

            let targetPackagePath = customExtensionsPath + Extensions.FileName.package
            if targetPackagePath.exists == false {
                logger.info("Adding \(targetPackagePath).")
                let sourcePackagePath = lucidSourcePath + Extensions.SourcePath.File.package
                try sourcePackagePath.copy(targetPackagePath)
            } else {
                logger.info("File \(targetPackagePath) already exists.")
            }

            let targetGitignorePath = customExtensionsPath + Extensions.FileName.gitignore
            if targetGitignorePath.exists == false {
                logger.info("Adding \(targetGitignorePath).")
                let sourceGitignorePath = lucidSourcePath + Extensions.SourcePath.File.gitignore
                try sourceGitignorePath.copy(targetGitignorePath)
            } else {
                logger.info("File \(targetGitignorePath) already exists.")
            }

            let targetVersionPath = customExtensionsPath + Extensions.FileName.version
            if targetVersionPath.exists == false {
                logger.info("Adding \(targetVersionPath).")
                let sourceVersionPath = lucidSourcePath + Extensions.SourcePath.File.version
                try sourceVersionPath.copy(targetVersionPath)
            } else {
                logger.info("File \(targetVersionPath) already exists.")
            }

            let targetSwiftVersionPath = customExtensionsPath + Extensions.FileName.swiftversion
            if targetSwiftVersionPath.exists == false {
                logger.info("Adding \(targetSwiftVersionPath).")
                let sourceSwiftVersionPath = lucidSourcePath + Extensions.SourcePath.File.swiftversion
                try sourceSwiftVersionPath.copy(targetSwiftVersionPath)
            } else {
                logger.info("File \(targetSwiftVersionPath) already exists.")
            }

            let targetMetaEntityFile = targetExtensionsDirectory + Extensions.FileName.metaEntityCustomExtensions
            if targetMetaEntityFile.exists == false {
                logger.info("Adding \(targetMetaEntityFile).")
                let sourceMetaEntityFile = lucidSourcePath + Extensions.SourcePath.File.metaEntityCustomExtensions
                try sourceMetaEntityFile.copy(targetMetaEntityFile)
            } else {
                logger.info("File \(targetMetaEntityFile) already exists.")
            }

            let targetMetaSubtypeFile = targetExtensionsDirectory + Extensions.FileName.metaSubtypeCustomExtensions
            if targetMetaSubtypeFile.exists == false {
                logger.info("Adding \(targetMetaSubtypeFile).")
                let sourceMetaSubtypeFile = lucidSourcePath + Extensions.SourcePath.File.metaSubtypeCustomExtensions
                try sourceMetaSubtypeFile.copy(targetMetaSubtypeFile)
            } else {
                logger.info("File \(targetMetaSubtypeFile) already exists.")
            }

            // Symlink Files

            let targetGeneratorLink = customExtensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenCustomExtensions + Extensions.DirectoryName.generators + Extensions.FileName.customExtensionsGenerator
            if targetGeneratorLink.exists == false {
                logger.info("Adding symlink \(targetGeneratorLink).")
                let sourceGeneratorLink = lucidSourcePath + Extensions.SourcePath.File.customExtensionsGenerator
                try targetGeneratorLink.relativeSymlink(sourceGeneratorLink)
            } else {
                logger.info("File symlink \(targetGeneratorLink) already exists.")
            }

            let targetMetaEntityLink = customExtensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenCustomExtensions + Extensions.DirectoryName.meta + Extensions.FileName.metaEntityCustomExtensions
            if targetMetaEntityLink.exists == false {
                let sourceMetaEntityLink = customExtensionsPath + Extensions.DirectoryName.extensions + Extensions.FileName.metaEntityCustomExtensions
                logger.info("Adding symlink \(targetMetaEntityLink) from \(sourceMetaEntityLink).")
                try targetMetaEntityLink.relativeSymlink(sourceMetaEntityLink)
            } else {
                logger.info("File symlink \(targetMetaEntityLink) already exists.")
            }

            let targetMetaSubtypeLink = customExtensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenCustomExtensions + Extensions.DirectoryName.meta + Extensions.FileName.metaSubtypeCustomExtensions
            if targetMetaSubtypeLink.exists == false {
                logger.info("Adding symlink \(targetMetaSubtypeLink).")
                let sourceMetaSubtypeLink = customExtensionsPath + Extensions.DirectoryName.extensions + Extensions.FileName.metaSubtypeCustomExtensions
                try targetMetaSubtypeLink.relativeSymlink(sourceMetaSubtypeLink)
            } else {
                logger.info("File symlink \(targetMetaSubtypeLink) already exists.")
            }
        }

        logger.moveToParent()
    }
}

main.run()
