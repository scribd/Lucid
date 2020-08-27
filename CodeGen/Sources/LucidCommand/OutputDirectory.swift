//
//  Constants.swift
//  LucidCommand
//
//  Created by Théophane Rupin on 1/31/19.
//

import Foundation
import LucidCodeGenCore
import PathKit

enum OutputDirectory {
    case entities
    case payloads
    case endpointPayloads
    case subtypes
    case support
    case factories
    case doubles
    case coreDataModel(version: Version)
    case coreDataModelVersion
    case jsonPayloads(String)
    case payloadTests
    case coreDataTests
    case coreDataMigrationTests
    case sqliteFiles
    case extensions
    
    func path(appModuleName: String) -> Path {
        switch self {
        case .entities:
            return Path("Entities")
        case .payloads:
            return Path("Payloads")
        case .endpointPayloads:
            return Path("EndpointPayloads")
        case .subtypes:
            return Path("Subtypes")
        case .support:
            return Path("Support")
        case .factories:
            return Path("Factories")
        case .doubles:
            return Path("Doubles")
        case .coreDataModel(let version):
            return OutputDirectory.support.path(appModuleName: appModuleName) + "\(appModuleName).xcdatamodeld" + "\(appModuleName)_\(version.dotDescription).xcdatamodel"
        case .coreDataModelVersion:
            return OutputDirectory.support.path(appModuleName: appModuleName) + "\(appModuleName).xcdatamodeld"
        case .jsonPayloads(let endpointName):
            return Path("JSONPayloads") + endpointName
        case .payloadTests:
            return Path("Payloads")
        case .coreDataTests:
            return Path("CoreData")
        case .coreDataMigrationTests:
            return Path("CoreDataMigrations")
        case .sqliteFiles:
            return Path("SQLite")
        case .extensions:
            return Path("Extensions")
        }
    }
}

// MARK: - Extensions

enum Extensions {

    enum DirectoryName {
        static let metaCode = Path("MetaCode")
        static let sources = Path("Sources")
        static let lucidCodeGenCore = Path("LucidCodeGenCore")
        static let lucidCodeGenExtensions = Path("LucidCodeGenExtensions")
        static let lucidCommandExtensions = Path("LucidCommandExtensions")

        static let generators = Path("Generators")
        static let meta = Path("Meta")
    }

    enum FileName {
        static let makefile = Path("Makefile")
        static let package = Path("Package.swift")
        static let gitignore = Path(".gitignore")
        static let version = Path(".version")
        static let swiftversion = Path(".swift-version")

        static let extensionsFileGenerator = Path("ExtensionsFileGenerator.swift")

        static let metaAllExtensions = Path("MetaAllExtensions.swift")
        static let metaEntityExtensions = Path("MetaEntityExtensions.swift")
        static let metaSubtypeExtensions = Path("MetaSubtypeExtensions.swift")
    }

    enum SourcePath {

        enum Directory {
            static let extensions = Path(".Extensions")
            static let sources = extensions + DirectoryName.sources
            static let lucidCodeGenCore = DirectoryName.sources + DirectoryName.lucidCodeGenCore
            static let lucidCodeGenExtensions = sources + DirectoryName.lucidCodeGenExtensions
            static let lucidCommandExtensions = sources + DirectoryName.lucidCommandExtensions

            static let generators = lucidCodeGenExtensions + DirectoryName.generators
        }

        enum File {
            static let makefile = Directory.extensions + FileName.makefile
            static let package = Directory.extensions + FileName.package
            static let gitignore = Directory.extensions + FileName.gitignore
            static let version = Directory.extensions + FileName.version
            static let swiftversion = Directory.extensions + FileName.swiftversion

            static let extensionsFileGenerator = Directory.generators + FileName.extensionsFileGenerator

            static let metaAllExtensions = Directory.lucidCodeGenExtensions + Path(".MetaAllExtensions.swift")
            static let metaEntityExtensions = Directory.lucidCodeGenExtensions + Path(".MetaEntityExtensions.swift")
            static let metaSubtypeExtensions = Directory.lucidCodeGenExtensions + Path(".MetaSubtypeExtensions.swift")
        }
    }
}

extension Path {

    func relativeSymlink(_ path: Path) throws {
        let relativeSymlinkPath = relativePath(to: path)
        try symlink(relativeSymlinkPath)
    }

    private func relativePath(to targetFile: Path) -> Path {

        let sourceComponents = absolute().components
        let targetComponents = targetFile.absolute().components

        guard sourceComponents != targetComponents else {
            fatalError("Can't create a symlink to itself.")
        }

        let common = sourceComponents.sharedPrefix(with: targetComponents)

        let parentCount = sourceComponents.count - common.count - 1
        var relative = Path()
        for _ in 0..<parentCount {
            relative = relative + Path("..")
        }

        for i in common.count..<targetComponents.count {
            relative = relative + Path(targetComponents[i])
        }

        return relative
    }
}

private extension Array where Element == String {

    func sharedPrefix(with other: [String]) -> [String] {
        var sourceIterator = makeIterator()
        var targetIterator = other.makeIterator()

        var common = [String]()

        while let nextSource = sourceIterator.next(),
            let nextTarget = targetIterator.next(),
            nextSource == nextTarget {
                common.append(nextSource)
        }

        return common
    }
}
