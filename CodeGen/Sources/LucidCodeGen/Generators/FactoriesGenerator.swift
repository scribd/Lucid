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

    public let outputDirectory = OutputDirectory.factories

    public let targetName = TargetName.appTestSupport

    public let deleteExtraFiles = true

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }
    
    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        switch element {
        case .all:
            let filename = "EntityFactory.swift"
            
            let header = MetaHeader(filename: filename, organizationName: organizationName)
            let entityFactories = MetaEntityFactories(descriptions: parameters.currentDescriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .with(imports: entityFactories.imports())
                .adding(members: entityFactories.meta())
                .swiftFile(in: directory)
            
        case .entity(let entityName):
            let filename = "\(entityName.camelCased().suffixedName())Factory.swift"
            
            let header = MetaHeader(filename: filename, organizationName: organizationName)
            let entityFactory = MetaEntityFactory(entityName: entityName,
                                                  descriptions: parameters.currentDescriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .with(imports: entityFactory.imports())
                .adding(member: try entityFactory.meta())
                .swiftFile(in: directory)
            
        case .subtype(let subtypeName):
            let filename = "\(subtypeName.camelCased().suffixedName())Factory.swift"
            
            let header = MetaHeader(filename: filename, organizationName: organizationName)
            let subtypeFactory = MetaSubtypeFactory(subtypeName: subtypeName,
                                                    descriptions: parameters.currentDescriptions)
            
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
