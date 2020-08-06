//
//  Bootstrap.swift
//  LucidCommand
//
//  Created by Stephane Magne on 8/6/20.
//

import Foundation
import LucidCodeGen
import LucidCodeGenCore
import PathKit

final class Bootstrap {

    private let logger: Logger

    private let configuration: SwiftCommandConfiguration

    private let sourceCodePath: String

    init(logger: Logger,
         configuration: SwiftCommandConfiguration,
         sourceCodePath: String) {
        self.logger = logger
        self.configuration = configuration
        self.sourceCodePath = sourceCodePath
    }

    func run() throws {
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

        let lucidSourcePath = Path(sourceCodePath)
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
