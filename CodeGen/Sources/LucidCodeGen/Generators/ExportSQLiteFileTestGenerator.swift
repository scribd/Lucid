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

    private let reactiveKit: Bool
        
    public init(descriptions: Descriptions,
                descriptionsHash: String,
                sqliteFile: Path,
                platform: Platform?,
                reactiveKit: Bool) {

        self.descriptions = descriptions
        self.descriptionsHash = descriptionsHash
        self.sqliteFile = sqliteFile
        self.platform = platform
        self.reactiveKit = reactiveKit
    }
    
    public func generate(for element: Description, in directory: Path) throws -> SwiftFile? {
        guard element == .all else { return nil }
        
        let header = MetaHeader(filename: filename)
        let exportSQLiteFileTest = MetaExportSQLiteFileTest(descriptions: descriptions,
                                                            descriptionsHash: descriptionsHash,
                                                            sqliteFileName: sqliteFile.lastComponentWithoutExtension,
                                                            platform: platform,
                                                            reactiveKit: reactiveKit)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: exportSQLiteFileTest.imports())
            .adding(member: try exportSQLiteFileTest.meta())
            .swiftFile(in: directory)
    }
}
