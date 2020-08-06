//
//  SwiftExtensionGenerator.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 12/4/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import LucidCodeGenCustomExtensions
import LucidCodeGenCore
import PathKit
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

final class SwiftExtensionGenerator {
 
    private let generators: [InternalSwiftExtensionGenerator]
    
    init(to target: Target,
         descriptions: Descriptions,
         appVersion: Version,
         organizationName: String,
         logger: Logger) {

        let platforms = Set(descriptions.platforms.sorted())
        let descriptionVariants: [(Platform?, Descriptions)]

        if platforms.isEmpty {
            descriptionVariants = [(nil, descriptions)]
        } else {
            descriptionVariants = platforms.map { platform in
                (platform, descriptions.variant(for: platform))
            }
        }

        generators = descriptionVariants.map {
            return InternalSwiftExtensionGenerator(to: target,
                                                   descriptions: $1,
                                                   appVersion: appVersion,
                                                   platform: $0,
                                                   organizationName: organizationName,
                                                   logger: logger)
        }
    }
    
    func generate() throws {
        for generator in generators {
            try generator.generate()
        }
    }
}

private final class InternalSwiftExtensionGenerator {
    
    private let target: Target
    private let descriptions: Descriptions
    private let appVersion: Version
    private let platform: Platform?
    private let organizationName: String
    private let logger: Logger
    
    init(to target: Target,
         descriptions: Descriptions,
         appVersion: Version,
         platform: Platform?,
         organizationName: String,
         logger: Logger) {
        
        self.target = target
        self.descriptions = descriptions
        self.appVersion = appVersion
        self.platform = platform
        self.organizationName = organizationName
        self.logger = logger
    }
    
    func generate() throws {
        
        logger.moveToChild("Generating Code \(platform.flatMap { "for platform: \($0), " } ?? "")for target: '\(target.name.rawValue)'...")
        
        try generate(with: CustomExtensionsGenerator(descriptions: descriptions),
                     in: .custom,
                     for: .app,
                     deleteExtraFiles: true)

        logger.moveToParent()
    }
    
    private func generate<G: ExtensionsGenerator>(with generator: G,
                                                  in directory: OutputDirectory,
                                                  for targetName: TargetName,
                                                  deleteExtraFiles: Bool = false) throws {

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
                let files = try generator.generate(for: element, in: directory, organizationName: organizationName)
                for file in files {
                    try file.path.parent().mkpath()
                    try file.path.write(file.content)
                    generatedFiles.insert(file.path.string)
                    logger.done("Generated \(file.path).")
                }
            } catch {
                logger.error("Failed to generate extensions for '\(element)'.")
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
