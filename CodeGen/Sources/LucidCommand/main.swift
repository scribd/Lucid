//
//  main.swift
//  ParsingTester
//
//  Created by Stephane Magne on 12/4/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import LucidCodeGen
import Commander
import PathKit

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
        
        let currentDescriptionsParser = DescriptionsParser(inputPath: configuration.inputPath,
                                                           targets: configuration.targets,
                                                           logger: logger)
        let currentDescriptions = try currentDescriptionsParser.parse()
        logger.moveToParent()

        logger.moveToChild("Resolving release tags.")
        
        let descriptionsVersionManager = try DescriptionsVersionManager(outputPath: configuration.cachePath,
                                                                        inputPath: configuration._inputPath,
                                                                        gitRemote: configuration.gitRemote,
                                                                        noRepoUpdate: configuration.noRepoUpdate,
                                                                        logger: logger)
        
        var appVersions = currentDescriptions.modelMappingHistory
        appVersions.remove(configuration.currentVersion)

        var descriptions = try appVersions.reduce(into: [String: Descriptions]()) { descriptions, appVersion in
            let releaseTag = try descriptionsVersionManager.resolveLatestReleaseTag(excluding: false, appVersion: appVersion)
            let descriptionsPath = try descriptionsVersionManager.fetchDescriptionsVersion(releaseTag: releaseTag)
            let descriptionsParser = DescriptionsParser(inputPath: descriptionsPath, logger: Logger(level: .none))
            descriptions[appVersion] = try descriptionsParser.parse()
        }
        
        descriptions[configuration.currentVersion] = currentDescriptions
        
        let _shouldGenerateDataModel: Bool
        if configuration.forceBuildNewDBModel || forceBuildNewDBModelForVersions.contains(currentVersion) {
            _shouldGenerateDataModel = true
        } else if let latestReleaseTag = try? descriptionsVersionManager.resolveLatestReleaseTag(excluding: true,
                                                                                                 appVersion: configuration.currentVersion) {
            
            let latestDescriptionsPath = try descriptionsVersionManager.fetchDescriptionsVersion(releaseTag: latestReleaseTag)
            let latestDescriptionsParser = DescriptionsParser(inputPath: latestDescriptionsPath,
                                                              targets: configuration.targets,
                                                              logger: Logger(level: .none))
            let latestDescriptions = try latestDescriptionsParser.parse()

            _shouldGenerateDataModel = try shouldGenerateDataModel(byComparing: latestDescriptions,
                                                                   to: currentDescriptions,
                                                                   appVersion: configuration.currentVersion,
                                                                   logger: logger)
            
            try validateDescriptions(byComparing: latestDescriptions,
                                     to: currentDescriptions,
                                     appVersion: configuration.currentVersion,
                                     logger: logger)
        } else {
            _shouldGenerateDataModel = false
        }
        logger.moveToParent()
        
        logger.moveToChild("Starting code generation...")
        for target in configuration.targets.all where target.isSelected {
            let descriptionsHash = try descriptionsVersionManager.descriptionsHash(absoluteInputPath: configuration.inputPath)
            let generator = SwiftCodeGenerator(to: target,
                                               descriptions: descriptions,
                                               appVersion: configuration.currentVersion,
                                               shouldGenerateDataModel: _shouldGenerateDataModel,
                                               descriptionsHash: descriptionsHash,
                                               responseHandlerFunction: configuration.responseHandlerFunction,
                                               coreDataMigrationsFunction: configuration.coreDataMigrationsFunction,
                                               reactiveKit: configuration.reactiveKit,
                                               useCoreDataLegacyNaming: configuration.useCoreDataLegacyNaming,
                                               lexicon: configuration.lexicon,
                                               entitySuffix: configuration.entitySuffix,
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
        let descriptions = try parser.parse()
        
        let authToken = authToken.isEmpty ? nil : authToken
        let generator = JSONPayloadsGenerator(to: Path(outputPath),
                                              descriptions: descriptions,
                                              authToken: authToken,
                                              endpointFilter: endpoints.isEmpty ? nil : endpoints,
                                              logger: logger)
        try generator.generate()
    }

}

main.run()