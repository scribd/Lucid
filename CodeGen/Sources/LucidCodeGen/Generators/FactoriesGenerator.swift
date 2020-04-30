//
//  FactoriesGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/16/19.
//

import Meta
import PathKit

public final class FactoriesGenerator: Generator {
    
    public let name = "factories"
    
    private let descriptions: Descriptions
    
    public init(descriptions: Descriptions) {
        self.descriptions = descriptions
    }
    
    public func generate(for element: Description, in directory: Path) throws -> File? {
        switch element {
        case .all:
            let filename = "EntityFactory.swift"
            
            let header = MetaHeader(filename: filename)
            let entityFactories = MetaEntityFactories(descriptions: descriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(members: entityFactories.meta())
                .swiftFile(in: directory)
            
        case .entity(let entityName):
            let filename = "\(entityName)Factory.swift"
            
            let header = MetaHeader(filename: filename)
            let entityFactory = MetaEntityFactory(entityName: entityName, descriptions: descriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .with(imports: entityFactory.imports())
                .adding(member: try entityFactory.meta())
                .swiftFile(in: directory)
            
        case .subtype(let subtypeName):
            let filename = "\(subtypeName)Factory.swift"
            
            let header = MetaHeader(filename: filename)
            let subtypeFactory = MetaSubtypeFactory(subtypeName: subtypeName, descriptions: descriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .with(imports: subtypeFactory.imports())
                .with(body: try subtypeFactory.meta())
                .swiftFile(in: directory)

        case .endpoint:
            return nil
        }
    }
}
