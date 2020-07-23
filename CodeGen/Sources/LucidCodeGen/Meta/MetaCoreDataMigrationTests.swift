//
//  MetaCoreDataMigrationTests.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/17/19.
//

import Meta
import PathKit

struct MetaCoreDataMigrationTests {
    
    let descriptions: Descriptions
    
    let sqliteVersions: [Version]
    
    let appVersion: Version
    
    let platform: Platform?

    let reactiveKit: Bool

    func imports() -> [Import] {
        return [
            .xcTest,
            .app(descriptions, testable: true),
            .lucid(reactiveKit: reactiveKit),
            .appTestKit(descriptions),
            .lucidTestKit(reactiveKit: reactiveKit)
        ]
    }
    
    func meta() throws -> [FileBodyMember] {
        return [
            try testClass(),
            EmptyLine(),
            try appVersions(),
        ]
    }
    
    private func variableFormatForVersion(_ version: Version) -> String {
        return version.sqlDescription
    }
    
    private func variableFormatForFileVersion(_ fileVersion: String) throws -> String {
        return fileVersion
            .replacingOccurrences(of: ".sqlite", with: String())
            .replacingOccurrences(of: "\(descriptions.targets.app.moduleName)_", with: String())
    }
    
    private func valueFormatForVersion(_ version: String) -> String {
        return version.replacingOccurrences(of: "_", with: ".")
    }
    
    private func testClass() throws -> Type {
        
        var appTestsOutputPath = descriptions.targets.appTests.outputPath.string
        if let platform = platform {
            appTestsOutputPath = "\(appTestsOutputPath)/\(platform)"
        }
        if descriptions.targets.appTests.outputPath.isAbsolute == false {
            appTestsOutputPath = "\\(projectDirectoryPath)/\(appTestsOutputPath)"
        }

        return Type(identifier: TypeIdentifier(name: "CoreDataMigrationTests"))
            .adding(inheritedType: .xcTestCase)
            .adding(member: PlainCode(code: """
            
            private let fileManager: FileManager = .default
            
            private let projectDirectoryPath: String = {
                guard let projectDirectoryPath = ProcessInfo.processInfo.environment["LUCID_PROJECT_DIR"] else {
                    fatalError("Environment variable 'LUCID_PROJECT_DIR' is not defined. Please define it to `$PROJECT_DIR` in the Scheme configuration.")
                }
                return projectDirectoryPath
            }()

            override func setUp() {
                super.setUp()
                Logger.shared = LoggerMock()
            }
            
            override func tearDown() {
                defer { super.tearDown() }
                Logger.shared = nil
            }

            private func runTest(for sqliteFile: String, version: Version) throws {
                guard let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first else {
                    XCTFail("Could not find app support directory")
                    return
                }

                var hasExpectations = false

                let sourceURL = URL(fileURLWithPath: "\(appTestsOutputPath)/SQLite/\\(sqliteFile)")
                let destinationURL = URL(fileURLWithPath: "\\(appSupportDirectory)/\\(sqliteFile)")

                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                } else if fileManager.fileExists(atPath: appSupportDirectory) == false {
                    try fileManager.createDirectory(atPath: appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
                }

                try fileManager.copyItem(at: sourceURL, to: destinationURL)

                let bundle = Bundle(for: CoreManagerContainer.self)
                guard let modelURL = bundle.url(forResource: "\(descriptions.targets.app.moduleName)", withExtension: "momd") else {
                    XCTFail("Could not build model URL.")
                    return
                }

                let coreDataManager = CoreDataManager(modelURL: modelURL,
                                                      persistentStoreURL: destinationURL,
                                                      migrations: CoreDataManager.migrations(),
                                                      forceMigration: true)
            \(MetaCode(indentation: 1, meta: try descriptions.entities.filter { $0.persist }.map { entity in

                let rangesToIgnoreByPropertyName = try entity.ignoredVersionRangesByPropertyName()
                let testCode = PlainCode(code: """
                
                let \(entity.transformedName.variableCased())Expectation = self.expectation(description: "\(entity.transformedName)")
                hasExpectations = true
                let \(entity.transformedName.variableCased())CoreDataStore = \(MetaCode(meta: TypeIdentifier.coreDataStore(of: entity.typeID())))(coreDataManager: coreDataManager)
                \(entity.transformedName.variableCased())CoreDataStore.search(withQuery: .all, in: _ReadContext<EndpointResultPayload>()) { result in
                    defer { \(entity.transformedName.variableCased())Expectation.fulfill() }
                    switch result {
                    case .success(let result):
                        XCTAssertNotNil(result.entity)
                \(MetaCode(indentation: 2, meta: entity.valuesThenRelationships.compactMap { property in
                    var assert: FunctionBodyMember
                
                    if property.isArray {
                        assert = .named("XCTAssertFalse") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: .value(Reference.named("result.entity") |
                                            .unwrap +
                                            property.reference |
                                            (property.extra ? .none + .named("extraValue") | .call() : .none) |
                                            (property.optional ? .unwrap : .none) +
                                            .named("isEmpty")) ?? .value(Value.bool(false))))
                        )
                    } else {
                        assert = .named("XCTAssertNotNil") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Reference.named("result.entity") | .unwrap + property.reference))
                        )
                    }
                
                    if let rangesToIgnore = rangesToIgnoreByPropertyName[property.name], rangesToIgnore.isEmpty == false {
                        for (fromVersion, toVersion) in rangesToIgnore {
                            assert = If(condition:
                                .value(Reference.named("version")) < .value(Reference.named("AppVersions.version\(variableFormatForVersion(fromVersion))")) ||
                                .value(Reference.named("version")) >= .value(Reference.named("AppVersions.version\(variableFormatForVersion(toVersion))"))
                            ).adding(member: assert)
                        }
                    }
                
                    if let addedAtVersion = property.addedAtVersion {
                        assert = If(condition:
                            .value(Reference.named("version")) >= .value(Reference.named("AppVersions.version\(variableFormatForVersion(addedAtVersion))"))
                        ).adding(member: assert)
                    }
                
                    return assert
                }))
                    case .failure(let error):
                        XCTFail("Unexpected error: \\(error)")
                    }
                }
                """)

                let checkpoints = entity.migrationCheckpoints
                guard let mostRecentCheckpointVersion = checkpoints.last else {
                    fatalError("attempting to build core data migration tests for entity \(entity.name) with missing version history")
                }

                if (checkpoints.count == 1 && entity.previousName == nil) || checkpoints.count > 1 {
                    return If(condition:
                        .value(Reference.named("version")) >= .value(Reference.named("AppVersions.version\(variableFormatForVersion(mostRecentCheckpointVersion))"))
                    ).adding(member: testCode)
                } else {
                    return testCode
                }
            }))

                guard hasExpectations else { return }

                waitForExpectations(timeout: 10) { (_: Error?) in
                    if self.fileManager.fileExists(atPath: destinationURL.path) {
                        try! self.fileManager.removeItem(at: destinationURL)
                    }
                    let expectation = self.expectation(description: "database_cleanup")
                    coreDataManager.clearDatabase { (_) in
                        expectation.fulfill()
                    }
                    self.waitForExpectations(timeout: 1, handler: nil)
                }
            }

            private func test_app_versions() {\((try sqliteVersions.map { sqliteVersion -> String in
                    try variableFormatForFileVersion(sqliteVersion.versionString)
                } + [variableFormatForVersion(appVersion)]).map { version in
                    "\n    XCTAssertNotNil(AppVersions.version\(version))"
                }.reduce(String()) { $0 + $1 })
            }

            """))
            .adding(members: try sqliteVersions.map { sqliteVersion in
                let fileVersion = try variableFormatForFileVersion(sqliteVersion.versionString)
                return Function(kind: .named("test_migration_from_\(fileVersion)_to_\(appVersion.sqlDescription)_should_succeed"))
                    .with(throws: true)
                    .adding(member: Reference.try | .named("runTest") | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "for", value: Value.string(sqliteVersion.versionString)))
                        .adding(parameter: TupleParameter(name: "version", value: Reference.named("AppVersions.version\(variableFormatForVersion(sqliteVersion))")))
                ))
            })
    }

    private func appVersions() throws -> Type {

        return Type(identifier: TypeIdentifier(name: "AppVersions"))
            .adding(member: PlainCode(code: """
            \((try sqliteVersions.map { sqliteVersion -> String in
                try variableFormatForFileVersion(sqliteVersion.versionString)
            } + [variableFormatForVersion(appVersion)]).map { version in
                "static let version\(version): Version! = try? Version(\"\(valueFormatForVersion(version))\")\n"
            }.reduce(String()) { $0 + $1 })
            static var currentVersion: Version {
                return version\(variableFormatForVersion(appVersion))
            }
            """)
        )
    }
}
