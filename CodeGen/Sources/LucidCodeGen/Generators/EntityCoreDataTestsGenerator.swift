//
//  EntityCoreDataTestsGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/16/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class CoreDataTestsGenerator: Generator {

    public let name = "core data tests"

    public let outputDirectory = OutputDirectory.coreDataTests

    public var targetName = TargetName.appTests

    public let deleteExtraFiles = true

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }
    
    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard let entityName = element.entityName else { return nil }
        
        let entity = try parameters.currentDescriptions.entity(for: entityName)
        guard entity.persist else { return nil }
        
        let filename = "\(entityName.camelCased().suffixedName())CoreDataTests.swift"
        
        let header = MetaHeader(filename: filename, organizationName: organizationName)
        let entityCoreDataTests = MetaEntityCoreDataTests(entityName: entityName,
                                                          descriptions: parameters.currentDescriptions)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: entityCoreDataTests.imports())
            .adding(member: try entityCoreDataTests.meta())
            .swiftFile(in: directory)
    }
}
