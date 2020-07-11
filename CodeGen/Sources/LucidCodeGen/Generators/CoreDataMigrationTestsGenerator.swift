//
//  CoreDataMigrationTestsGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/17/19.
//


import Meta
import PathKit

public final class CoreDataMigrationTestsGenerator: Generator {
    
    public let name = "Core Data migration tests"
    
    private let filename = "CoreDataMigrationTests.swift"

    private let descriptions: Descriptions
    
    private let sqliteFiles: [String]
    
    private let appVersion: String
    
    private let platform: Platform?

    private let reactiveKit: Bool

    public init(descriptions: Descriptions,
                sqliteFiles: [String],
                appVersion: String,
                platform: Platform?,
                reactiveKit: Bool) {
        
        self.descriptions = descriptions
        self.sqliteFiles = sqliteFiles
        self.appVersion = appVersion
        self.platform = platform
        self.reactiveKit = reactiveKit
    }
    
    public func generate(for element: Description, in directory: Path) throws -> File? {
        guard element == .all else { return nil }

        let header = MetaHeader(filename: filename)

        let sqliteVersions = sqliteFiles
            .compactMap { try? Version($0, source: .coreDataModel) }
            .sorted()

        let coreDataMigrationTests = MetaCoreDataMigrationTests(descriptions: descriptions,
                                                                sqliteVersions: sqliteVersions,
                                                                appVersion: appVersion,
                                                                platform: platform,
                                                                reactiveKit: reactiveKit)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: coreDataMigrationTests.imports())
            .adding(members: try coreDataMigrationTests.meta())
            .swiftFile(in: directory)
    }
}