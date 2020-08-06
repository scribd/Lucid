//
//  main.swift
//  Extensions
//
//  Created by Stephane Magne on 12/4/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import LucidCodeGenExtensions
import LucidCodeGenCore
import Commander
import PathKit

 let main = Group {

    $0.command(
        "swift",
        Option<String>("config-path", default: ".lucid.yaml", description: "Configuration file location."),
        Option<String>("current-version", default: String(), description: "Current app version."),
        VariadicOption<String>("selected-targets", default: [], description: "List of targets to generate.")
    ) { configPath, currentVersion, selectedTargets in
        
        let logger = Logger()

        logger.moveToChild("Reading configuration file.")
        let configuration = try SwiftCommandConfiguration.make(with: configPath,
                                                               currentVersion: currentVersion,
                                                               cachePath: nil,
                                                               noRepoUpdate: nil,
                                                               forceBuildNewDBModel: nil,
                                                               forceBuildNewDBModelForVersions: nil,
                                                               selectedTargets: Set(selectedTargets),
                                                               reactiveKit: nil,
                                                               logger: logger)

        let currentAppVersion = try Version(configuration.currentVersion, source: .description)
        let currentDescriptionsParser = DescriptionsParser(inputPath: configuration.inputPath,
                                                           targets: configuration.targets,
                                                           logger: logger)
        let currentDescriptions = try currentDescriptionsParser.parse(version: currentAppVersion)
        logger.moveToParent()

        logger.moveToChild("Starting code generation...")
        let generator = SwiftExtensionGenerator(to: configuration.targets.app,
                                                descriptions: currentDescriptions,
                                                appVersion: currentAppVersion,
                                                organizationName: configuration.organizationName,
                                                logger: logger)
        try generator.generate()
        logger.moveToParent()

        logger.br()
        logger.done("Finished successfully.")
    }
}

main.run()
