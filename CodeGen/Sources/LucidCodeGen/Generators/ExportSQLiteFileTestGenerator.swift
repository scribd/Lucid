//
//  ExportSQLiteFileTestGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/18/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class ExportSQLiteFileTestGenerator: Generator {

    public let name = "SQLite file export"

    private let filename = "ExportSQLiteFile.swift"

    public let outputDirectory = OutputDirectory.coreDataMigrationTests

    public let targetName = TargetName.appTests

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }

    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard parameters.shouldGenerateDataModel else { return nil }
        guard element == .all else { return nil }
        
        let header = MetaHeader(filename: filename, organizationName: organizationName)
        let exportSQLiteFileTest = MetaExportSQLiteFileTest(descriptions: parameters.currentDescriptions,
                                                            descriptionsHash: parameters.currentDescriptionsHash,
                                                            sqliteFileName: parameters.sqliteFile.lastComponentWithoutExtension,
                                                            platform: parameters.platform)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: exportSQLiteFileTest.imports())
            .adding(member: try exportSQLiteFileTest.meta())
            .swiftFile(in: directory)
    }
}
