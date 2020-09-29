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
        Option<String>("no-repo-update", default: String(), description: "Skips repository update for version checking."),
        Option<String>("force-build-new-db-model", default: String(), description: "Force to build a new Database Model regardless of changes."),
        VariadicOption<String>("force-build-new-db-model-for-versions", default: [], description: "Force to build a new Database Model regardless of changes for versions."),
        Option<String>("reactive-kit", default: String(), description: "Weither to use ReactiveKit's API."),
        VariadicOption<String>("selected-targets", default: [], description: "List of targets to generate.")
    ) { configPath, currentVersion, cachePath, noRepoUpdate, forceBuildNewDBModel, forceBuildNewDBModelForVersions, reactiveKit, selectedTargets in
        
        let logger = Logger()

        logger.moveToChild("Reading configuration file.")
        let configuration = try CommandConfiguration.make(
            with: configPath.isEmpty ? nil : configPath,
            currentVersion: currentVersion.isEmpty ? nil : currentVersion,
            cachePath: cachePath.isEmpty ? nil : cachePath,
            noRepoUpdate: noRepoUpdate == "true" ? true : noRepoUpdate == "false" ? false : nil,
            forceBuildNewDBModel: forceBuildNewDBModel == "true" ? true : forceBuildNewDBModel == "false" ? false : nil,
            forceBuildNewDBModelForVersions: forceBuildNewDBModelForVersions.isEmpty ? nil : Set(forceBuildNewDBModelForVersions),
            selectedTargets: Set(selectedTargets),
            reactiveKit: reactiveKit == "true" ? true : reactiveKit == "false" ? false : nil,
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
        Option<String>("config-path", default: ".lucid.yaml", description: "Configuration file location."),
        Option<String>("source-code-path", default: String(), description: "Source code directory location.")
    ) { configPath, sourceCodePath in

        let logger = Logger()
        let configPath = Path(configPath)
        let bootstrapCommand = BootstrapCommand(logger: logger, sourceCodePath: sourceCodePath)

        if configPath.exists == false {
            try bootstrapCommand.saveDefaultConfiguration(with: configPath)
        }

        logger.moveToChild("Reading configuration file.")
        let configuration = try CommandConfiguration.make(with: configPath)

        try bootstrapCommand.createFileStructure(configuration)
    }
}

main.run()
