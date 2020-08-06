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
        if let extensionsPath = configuration.extensionsPath {

            // Directories

            if extensionsPath.exists == false {
                logger.info("Adding \(extensionsPath).")
                try extensionsPath.mkdir()
            } else {
                logger.info("Folder \(extensionsPath) already exists.")
            }

            let targetMetaCodeDirectory = extensionsPath + Extensions.DirectoryName.metaCode
            if targetMetaCodeDirectory.exists == false {
                logger.info("Adding \(targetMetaCodeDirectory).")
                try targetMetaCodeDirectory.mkdir()
            } else {
                logger.info("Folder \(targetMetaCodeDirectory) already exists.")
            }

            let targetSourcesDirectory = extensionsPath + "Sources"
            if targetSourcesDirectory.exists == false {
                logger.info("Adding \(targetSourcesDirectory).")
                try targetSourcesDirectory.mkdir()
            } else {
                logger.info("Folder \(targetSourcesDirectory) already exists.")
            }

            let targetCodeGenDirectory = extensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenExtensions
            if targetCodeGenDirectory.exists == false {
                logger.info("Adding \(targetCodeGenDirectory).")
                try targetCodeGenDirectory.mkdir()
            } else {
                logger.info("Folder \(targetCodeGenDirectory) already exists.")
            }

            let targetGeneratorsDirectory = extensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenExtensions + Extensions.DirectoryName.generators
            if targetGeneratorsDirectory.exists == false {
                logger.info("Adding \(targetGeneratorsDirectory).")
                try targetGeneratorsDirectory.mkdir()
            } else {
                logger.info("Folder \(targetGeneratorsDirectory) already exists.")
            }

            let targetMetaDirectory = extensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenExtensions + Extensions.DirectoryName.meta
            if targetMetaDirectory.exists == false {
                logger.info("Adding \(targetMetaDirectory).")
                try targetMetaDirectory.mkdir()
            } else {
                logger.info("Folder \(targetMetaDirectory) already exists.")
            }

            // Symlink Directories

            let targetCodeGenCoreLink = extensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenCore
            if targetCodeGenCoreLink.exists == false {
                logger.info("Adding symlink \(targetCodeGenCoreLink).")
                let sourceCodeGenCoreLink = lucidSourcePath + Extensions.SourcePath.Directory.lucidCodeGenCore
                try targetCodeGenCoreLink.relativeSymlink(sourceCodeGenCoreLink)
            } else {
                logger.info("Folder symlink \(targetCodeGenCoreLink) already exists.")
            }

            let targetCommandLink = extensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCommandExtensions
            if targetCommandLink.exists == false {
                logger.info("Adding symlink \(targetCommandLink).")
                let sourceCommandLink = lucidSourcePath + Extensions.SourcePath.Directory.lucidCommandExtensions
                try targetCommandLink.relativeSymlink(sourceCommandLink)
            } else {
                logger.info("Folder symlink  \(targetCommandLink) already exists.")
            }

            // Files

            let targetMakefilePath = extensionsPath + Extensions.FileName.makefile
            if targetMakefilePath.exists == false {
                logger.info("Adding \(targetMakefilePath).")
                let sourceMakefilePath = lucidSourcePath + Extensions.SourcePath.File.makefile
                try sourceMakefilePath.copy(targetMakefilePath)
            } else {
                logger.info("File \(targetMakefilePath) already exists.")
            }

            let targetPackagePath = extensionsPath + Extensions.FileName.package
            if targetPackagePath.exists == false {
                logger.info("Adding \(targetPackagePath).")
                let sourcePackagePath = lucidSourcePath + Extensions.SourcePath.File.package
                try sourcePackagePath.copy(targetPackagePath)
            } else {
                logger.info("File \(targetPackagePath) already exists.")
            }

            let targetGitignorePath = extensionsPath + Extensions.FileName.gitignore
            if targetGitignorePath.exists == false {
                logger.info("Adding \(targetGitignorePath).")
                let sourceGitignorePath = lucidSourcePath + Extensions.SourcePath.File.gitignore
                try sourceGitignorePath.copy(targetGitignorePath)
            } else {
                logger.info("File \(targetGitignorePath) already exists.")
            }

            let targetVersionPath = extensionsPath + Extensions.FileName.version
            if targetVersionPath.exists == false {
                logger.info("Adding \(targetVersionPath).")
                let sourceVersionPath = lucidSourcePath + Extensions.SourcePath.File.version
                try sourceVersionPath.copy(targetVersionPath)
            } else {
                logger.info("File \(targetVersionPath) already exists.")
            }

            let targetSwiftVersionPath = extensionsPath + Extensions.FileName.swiftversion
            if targetSwiftVersionPath.exists == false {
                logger.info("Adding \(targetSwiftVersionPath).")
                let sourceSwiftVersionPath = lucidSourcePath + Extensions.SourcePath.File.swiftversion
                try sourceSwiftVersionPath.copy(targetSwiftVersionPath)
            } else {
                logger.info("File \(targetSwiftVersionPath) already exists.")
            }

            let targetMetaEntityFile = targetMetaCodeDirectory + Extensions.FileName.metaEntityExtensions
            if targetMetaEntityFile.exists == false {
                logger.info("Adding \(targetMetaEntityFile).")
                let sourceMetaEntityFile = lucidSourcePath + Extensions.SourcePath.File.metaEntityExtensions
                try sourceMetaEntityFile.copy(targetMetaEntityFile)
            } else {
                logger.info("File \(targetMetaEntityFile) already exists.")
            }

            let targetMetaSubtypeFile = targetMetaCodeDirectory + Extensions.FileName.metaSubtypeExtensions
            if targetMetaSubtypeFile.exists == false {
                logger.info("Adding \(targetMetaSubtypeFile).")
                let sourceMetaSubtypeFile = lucidSourcePath + Extensions.SourcePath.File.metaSubtypeExtensions
                try sourceMetaSubtypeFile.copy(targetMetaSubtypeFile)
            } else {
                logger.info("File \(targetMetaSubtypeFile) already exists.")
            }

            // Symlink Files

            let targetGeneratorLink = extensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenExtensions + Extensions.DirectoryName.generators + Extensions.FileName.extensionsFileGenerator
            if targetGeneratorLink.exists == false {
                logger.info("Adding symlink \(targetGeneratorLink).")
                let sourceGeneratorLink = lucidSourcePath + Extensions.SourcePath.File.extensionsFileGenerator
                try targetGeneratorLink.relativeSymlink(sourceGeneratorLink)
            } else {
                logger.info("File symlink \(targetGeneratorLink) already exists.")
            }

            let targetMetaEntityLink = extensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenExtensions + Extensions.DirectoryName.meta + Extensions.FileName.metaEntityExtensions
            if targetMetaEntityLink.exists == false {
                let sourceMetaEntityLink = extensionsPath + Extensions.DirectoryName.metaCode + Extensions.FileName.metaEntityExtensions
                logger.info("Adding symlink \(targetMetaEntityLink) from \(sourceMetaEntityLink).")
                try targetMetaEntityLink.relativeSymlink(sourceMetaEntityLink)
            } else {
                logger.info("File symlink \(targetMetaEntityLink) already exists.")
            }

            let targetMetaSubtypeLink = extensionsPath + Extensions.DirectoryName.sources + Extensions.DirectoryName.lucidCodeGenExtensions + Extensions.DirectoryName.meta + Extensions.FileName.metaSubtypeExtensions
            if targetMetaSubtypeLink.exists == false {
                logger.info("Adding symlink \(targetMetaSubtypeLink).")
                let sourceMetaSubtypeLink = extensionsPath + Extensions.DirectoryName.metaCode + Extensions.FileName.metaSubtypeExtensions
                try targetMetaSubtypeLink.relativeSymlink(sourceMetaSubtypeLink)
            } else {
                logger.info("File symlink \(targetMetaSubtypeLink) already exists.")
            }
        }

        logger.moveToParent()
    }
}
