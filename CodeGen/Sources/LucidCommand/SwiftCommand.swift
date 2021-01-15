//
//  Swift.swift
//  LucidCommand
//
//  Created by Théophane Rupin on 9/25/20.
//

import Foundation
import LucidCodeGen
import LucidCodeGenCore
import PathKit

final class SwiftCommand {

    private let logger: Logger

    private let configuration: CommandConfiguration

    init(logger: Logger, configuration: CommandConfiguration) {
        self.logger = logger
        self.configuration = configuration
    }

    func run() throws {

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
                                                                        currentVersion: currentAppVersion,
                                                                        logger: logger)

        var modelMappingHistoryVersions = try currentDescriptions.modelMappingHistory(derivedFrom: descriptionsVersionManager?.versions() ?? [])
        modelMappingHistoryVersions.removeAll { $0 == currentAppVersion }

        var descriptions = try modelMappingHistoryVersions.reduce(into: [Version: Descriptions]()) { descriptions, appVersion in
            guard appVersion < currentAppVersion else { return }
            guard let descriptionsVersionManager = descriptionsVersionManager else { return }
            let releaseTag = try descriptionsVersionManager.resolveLatestReleaseTag(excluding: false, appVersion: appVersion)
            let descriptionsPath = try descriptionsVersionManager.fetchDescriptionsVersion(releaseTag: releaseTag)
            let descriptionsParser = DescriptionsParser(inputPath: descriptionsPath, logger: Logger(level: .none))
            descriptions[appVersion] = try descriptionsParser.parse(version: appVersion, includeEndpoints: false)
        }

        descriptions[currentAppVersion] = currentDescriptions

        let _shouldGenerateDataModel: Bool
        if configuration.forceBuildNewDBModel || configuration.forceBuildNewDBModelForVersions.contains(currentAppVersion.dotDescription) {
            _shouldGenerateDataModel = true
        } else if
            let descriptionsVersionManager = descriptionsVersionManager,
            let latestReleaseTag = try? descriptionsVersionManager.resolveLatestReleaseTag(excluding: true, appVersion: currentAppVersion) {

                let latestDescriptionsPath = try descriptionsVersionManager.fetchDescriptionsVersion(releaseTag: latestReleaseTag)
                let latestDescriptionsParser = DescriptionsParser(inputPath: latestDescriptionsPath,
                                                                  targets: configuration.targets,
                                                                  logger: Logger(level: .none))
                let appVersion = try Version(latestReleaseTag, source: .description)
                let latestDescriptions = try latestDescriptionsParser.parse(version: appVersion, includeEndpoints: false)

                _shouldGenerateDataModel = try shouldGenerateDataModel(byComparing: latestDescriptions,
                                                                       to: currentDescriptions,
                                                                       appVersion: currentAppVersion,
                                                                       logger: logger)

                try validateDescriptions(byComparing: latestDescriptions,
                                         to: currentDescriptions,
                                         logger: logger)
        } else {
            _shouldGenerateDataModel = true
        }
        logger.moveToParent()

        logger.moveToChild("Starting code generation...")
        for target in configuration.targets.value.all where target.isSelected {
            let descriptionsHash = try DescriptionsVersionManager.descriptionsHash(absoluteInputPath: configuration.inputPath)
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
                                                   extensionsPath: configuration.extensionsPath,
                                                   logger: logger)
            try generator.generate()
        }
        logger.moveToParent()

        logger.br()
        logger.done("Finished successfully.")
    }
}
