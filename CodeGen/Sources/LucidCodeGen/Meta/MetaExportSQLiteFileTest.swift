//
//  MetaExportSQLiteFileTest.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/18/19.
//

import Meta
import LucidCodeGenCore

struct MetaExportSQLiteFileTest {
        
    let descriptions: Descriptions
    
    let descriptionsHash: String
    
    let sqliteFileName: String
    
    let platform: Platform?

    func imports() -> [Import] {
        return [
            .xcTest,
            .app(descriptions, testable: true),
            .lucid,
            .appTestKit(descriptions),
            .lucidTestKit
        ]
    }
    
    func meta() throws -> Type {
        var appTestsOutputPath = descriptions.targets.appTests.outputPath.string
        if let platform = platform {
            appTestsOutputPath = "\(appTestsOutputPath)/\(platform)"
        }
        if descriptions.targets.appTests.outputPath.isAbsolute == false {
            appTestsOutputPath = "\\(projectDirectoryPath)/\(appTestsOutputPath)"
        }
        
        return Type(identifier: TypeIdentifier(name: "ExportSQLiteFile"))
            .adding(inheritedType: .xcTestCase)
            .adding(member: PlainCode(code: """
            
            private let coreDataManager = CoreDataManager(modelName: "\(descriptions.targets.app.moduleName)",
                                                          in: Bundle(for: CoreManagerContainer.self),
                                                          migrations: CoreDataManager.migrations())

            private let projectDirectoryPath: String = {
                guard let projectDirectoryPath = ProcessInfo.processInfo.environment["LUCID_PROJECT_DIR"] else {
                    fatalError("Environment variable 'LUCID_PROJECT_DIR' is not defined. Please define it to `$PROJECT_DIR` in the Scheme configuration.")
                }
                return projectDirectoryPath
            }()

            override func setUp() {
                super.setUp()
                
                LucidConfiguration.logger = LoggerMock()
            }
                
            override func tearDown() {
                defer { super.tearDown() }
                
                LucidConfiguration.logger = nil
            }
                
            func test_populate_database_and_export_sqlite_file() throws {
                
                let destinationDirectory = "\(appTestsOutputPath)/SQLite/"
                let sqliteFileURL = URL(fileURLWithPath: "\\(destinationDirectory)/\(sqliteFileName).sqlite")
                let descriptionsHashFileURL = URL(fileURLWithPath: "\\(destinationDirectory)/\(sqliteFileName).sha256")

                guard let descriptionsHash = "\(descriptionsHash)".data(using: .utf8) else {
                    XCTFail("Descriptions hash is not UTF-8")
                    return
                }
                
                if FileManager.default.fileExists(atPath: descriptionsHashFileURL.path) {
                    let currentDescriptionsHash = FileManager.default.contents(atPath: descriptionsHashFileURL.path)
                    if currentDescriptionsHash == descriptionsHash {
                        Logger.log(.info, "No change detected since sqlite file was last generated.", domain: "test")
                        return
                    }
                    try FileManager.default.removeItem(at: descriptionsHashFileURL)
                }
                
                let expectation = self.expectation(description: "expectation")
                coreDataManager.clearDatabase { success in
                    if success == false {
                        XCTFail("Could not clear database.")
                        expectation.fulfill()
                        return
                    }
                
                    var didErrorOccur = false
                    let dispatchGroup = DispatchGroup()
            \(MetaCode(indentation: 2, meta: descriptions.entities.filter { $0.persist }.flatMap { entity -> [FunctionBodyMember] in
                [
                    EmptyLine(),
                    Comment.comment(entity.transformedName),
                    Assignment(
                        variable: entity.coreDataStoreVariable,
                        value: TypeIdentifier.coreDataStore(of: entity.typeID()).reference | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "coreDataManager", value: .named(.`self`) + .named("coreDataManager")))
                        )
                    ),
                    Reference.named("dispatchGroup") + .named("enter") | .call(),
                    entity.coreDataStoreVariable.reference + .named("set") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Reference.array(with: [
                            entity.factoryTypeID.reference | .call(Tuple()
                                .adding(parameter: entity.hasVoidIdentifier ? nil : TupleParameter(value: Value.int(42)))
                            ) + .named("entity")
                        ]) + .named("any")))
                        .adding(parameter: TupleParameter(name: "in", value: .named("WriteContext") | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "dataTarget", value: +.named("local")))
                        )))
                    ) | .block(FunctionBody()
                            .adding(parameter: FunctionBodyParameter(name: "result"))
                            .adding(member: PlainCode(code: """
                            defer { dispatchGroup.leave() }
                            if result == nil {
                                didErrorOccur = true
                                XCTFail("Unexpectedly received nil.")
                                return
                            } else if let error = result?.error {
                                didErrorOccur = true
                                XCTFail("Unexpected error: \\(error)")
                                return
                            }
                            """))
                    )
                ]
            }))
                
                    dispatchGroup.notify(queue: .main) {
                        let errorMessage = "Something wrong happened. SQLite file wasn't exported successfully."
                
                        guard didErrorOccur == false else {
                            expectation.fulfill()
                            XCTFail(errorMessage)
                            return
                        }
                
                        self.coreDataManager.backupPersistentStore(to: sqliteFileURL) { success in
                            if success == false {
                                XCTFail(errorMessage)
                            }
                
                            if FileManager.default.createFile(atPath: descriptionsHashFileURL.path, contents: descriptionsHash, attributes: nil) == false {
                                XCTFail("Could not store descriptions hash file at \\(descriptionsHashFileURL.path).")
                            }
                
                            expectation.fulfill()
                        }
                    }
                }
                
                waitForExpectations(timeout: 10)
            }
            """))
    }
}
