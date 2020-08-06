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
    
    private let descriptions: Descriptions

    private let reactiveKit: Bool
    
    public init(descriptions: Descriptions, reactiveKit: Bool) {
        self.descriptions = descriptions
        self.reactiveKit = reactiveKit
    }
    
    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard let entityName = element.entityName else { return nil }
        
        let entity = try descriptions.entity(for: entityName)
        guard entity.persist else { return nil }
        
        let filename = "\(entityName.camelCased().suffixedName())CoreDataTests.swift"
        
        let header = MetaHeader(filename: filename, organizationName: organizationName)
        let entityCoreDataTests = MetaEntityCoreDataTests(entityName: entityName,
                                                          descriptions: descriptions,
                                                          reactiveKit: reactiveKit)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: entityCoreDataTests.imports())
            .adding(member: try entityCoreDataTests.meta())
            .swiftFile(in: directory)
    }
}
