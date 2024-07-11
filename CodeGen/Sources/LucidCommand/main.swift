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
        Option<String>("config-path", default: String(), description: "Configuration file location."),
        Option<String>("current-version", default: String(), description: "Current app version."),
        Option<String>("cache-path", default: String(), description: "Cache files location."),
        Option<String>("force-build-new-db-model", default: String(), description: "Force to build a new Database Model regardless of changes."),
        VariadicOption<String>("force-build-new-db-model-for-versions", default: [], description: "Force to build a new Database Model regardless of changes for versions."),
        VariadicOption<String>("selected-targets", default: [], description: "List of targets to generate.")
    ) { configPath, currentVersion, cachePath, forceBuildNewDBModel, forceBuildNewDBModelForVersions, selectedTargets in
        
        let logger = Logger()

        logger.moveToChild("Reading configuration file for \(currentVersion).")

        let configuration = try CommandConfiguration.make(
            with: configPath.isEmpty ? nil : configPath,
            currentVersion: currentVersion.isEmpty ? nil : currentVersion,
            cachePath: cachePath.isEmpty ? nil : cachePath,
            forceBuildNewDBModel: forceBuildNewDBModel == "true" ? true : forceBuildNewDBModel == "false" ? false : nil,
            forceBuildNewDBModelForVersions: forceBuildNewDBModelForVersions.isEmpty ? nil : Set(forceBuildNewDBModelForVersions),
            selectedTargets: Set(selectedTargets),
            logger: logger
        )

        let swiftCommand = SwiftCommand(logger: logger, configuration: configuration)

        try swiftCommand.run()
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
        Option<String>("config-path", default: ".lucid.yaml", description: "Configuration file location.")
    ) { configPath in

        let logger = Logger()
        let configPath = Path(configPath)
        let bootstrapCommand = BootstrapCommand(logger: logger)

        if configPath.exists == false {
            try bootstrapCommand.saveDefaultConfiguration(with: configPath)
        }

        logger.moveToChild("Reading configuration file.")

        do {
            let configuration = try CommandConfiguration.make(with: configPath)
            try bootstrapCommand.createFileStructure(configuration)
        } catch {
            logger.info("fuck")
        }

    }
}

main.run()
