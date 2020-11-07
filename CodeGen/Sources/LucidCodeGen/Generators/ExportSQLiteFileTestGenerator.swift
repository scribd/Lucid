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
    
    private let descriptionsHash: String
    
    private let sqliteFile: Path

    private let platform: Platform?

    private let descriptions: Descriptions

    public init(descriptions: Descriptions,
                descriptionsHash: String,
                sqliteFile: Path,
                platform: Platform?) {

        self.descriptions = descriptions
        self.descriptionsHash = descriptionsHash
        self.sqliteFile = sqliteFile
        self.platform = platform
    }
    
    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard element == .all else { return nil }
        
        let header = MetaHeader(filename: filename, organizationName: organizationName)
        let exportSQLiteFileTest = MetaExportSQLiteFileTest(descriptions: descriptions,
                                                            descriptionsHash: descriptionsHash,
                                                            sqliteFileName: sqliteFile.lastComponentWithoutExtension,
                                                            platform: platform)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: exportSQLiteFileTest.imports())
            .adding(member: try exportSQLiteFileTest.meta())
            .swiftFile(in: directory)
    }
}
