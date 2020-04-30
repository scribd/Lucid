//
//  EntityCoreDataTestsGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/16/19.
//

import Meta
import PathKit

public final class CoreDataTestsGenerator: Generator {
    
    public let name = "core data tests"
    
    private let descriptions: Descriptions
    
    public init(descriptions: Descriptions) {
        self.descriptions = descriptions
    }
    
    public func generate(for element: Description, in directory: Path) throws -> File? {
        guard let entityName = element.entityName else { return nil }
        
        let entity = try descriptions.entity(for: entityName)
        guard entity.persist else { return nil }
        
        let filename = "\(entityName)CoreDataTests.swift"
        
        let header = MetaHeader(filename: filename)
        let entityCoreDataTests = MetaEntityCoreDataTests(entityName: entityName, descriptions: descriptions)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: entityCoreDataTests.imports())
            .adding(member: try entityCoreDataTests.meta())
            .swiftFile(in: directory)
    }
}
