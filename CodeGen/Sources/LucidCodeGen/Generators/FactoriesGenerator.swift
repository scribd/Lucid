//
//  FactoriesGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/16/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class FactoriesGenerator: Generator {
    
    public let name = "factories"
    
    private let descriptions: Descriptions

    private let reactiveKit: Bool
    
    public init(descriptions: Descriptions, reactiveKit: Bool) {
        self.descriptions = descriptions
        self.reactiveKit = reactiveKit
    }
    
    public func generate(for element: Description, in directory: Path, companyName: String) throws -> SwiftFile? {
        switch element {
        case .all:
            let filename = "EntityFactory.swift"
            
            let header = MetaHeader(filename: filename, companyName: companyName)
            let entityFactories = MetaEntityFactories(descriptions: descriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(members: entityFactories.meta())
                .swiftFile(in: directory)
            
        case .entity(let entityName):
            let filename = "\(entityName.camelCased().suffixedName())Factory.swift"
            
            let header = MetaHeader(filename: filename, companyName: companyName)
            let entityFactory = MetaEntityFactory(entityName: entityName,
                                                  descriptions: descriptions,
                                                  reactiveKit: reactiveKit)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .with(imports: entityFactory.imports())
                .adding(member: try entityFactory.meta())
                .swiftFile(in: directory)
            
        case .subtype(let subtypeName):
            let filename = "\(subtypeName.camelCased().suffixedName())Factory.swift"
            
            let header = MetaHeader(filename: filename, companyName: companyName)
            let subtypeFactory = MetaSubtypeFactory(subtypeName: subtypeName,
                                                    descriptions: descriptions,
                                                    reactiveKit: reactiveKit)
            
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
