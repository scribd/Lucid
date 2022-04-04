//
//  CoreDataMigrationTestsGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/17/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class CoreDataMigrationTestsGenerator: Generator {
    
    public let name = "Core Data migration tests"
    
    private let filename = "CoreDataMigrationTests.swift"

    public let outputDirectory = OutputDirectory.coreDataMigrationTests

    public var targetName = TargetName.appTests

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }

    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        // If shouldGenerateDataModel == false, then we will rebuild the migration tests using the previous version number.
        // This allows the migration tests to be regenerated when old data models have been trimmed.
        let appVersion: Version
        if parameters.shouldGenerateDataModel {
            appVersion = parameters.appVersion
        } else {
            appVersion = parameters.newestModelVersion
        }
        guard element == .all else { return nil }

        let header = MetaHeader(filename: filename, organizationName: organizationName)

        let sqliteVersions = parameters
            .sqliteFiles
            .compactMap { try? Version($0, source: .coreDataModel) }
            .filter { $0 > parameters.oldestModelVersion || Version.isMatchingRelease($0, parameters.oldestModelVersion) }
            .sorted()

        let coreDataMigrationTests = MetaCoreDataMigrationTests(descriptions: parameters.currentDescriptions,
                                                                sqliteVersions: sqliteVersions,
                                                                appVersion: appVersion,
                                                                oldestModelVersion: parameters.oldestModelVersion,
                                                                newestModelVersion: parameters.newestModelVersion,
                                                                platform: parameters.platform)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: coreDataMigrationTests.imports())
            .adding(members: try coreDataMigrationTests.meta())
            .swiftFile(in: directory)
    }
}
