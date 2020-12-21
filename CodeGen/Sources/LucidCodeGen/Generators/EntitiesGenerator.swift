//
//  EntitiesGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/20/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class EntitiesGenerator: Generator {
    
    public let name = "entities"

    public let outputDirectory = OutputDirectory.entities

    public var targetName = TargetName.app

    public let deleteExtraFiles = true

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }

    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        switch element {
        case .all:
            let filename = "EntityIndexValueTypes.swift"
            
            let header = MetaHeader(filename: filename, organizationName: organizationName)
            let subtype = MetaSubtypes(descriptions: parameters.currentDescriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid)
                .with(body: try subtype.meta())
                .swiftFile(in: directory)

        case .entity(let entityName):
            let filename = "\(entityName.camelCased().suffixedName()).swift"
            
            let header = MetaHeader(filename: filename, organizationName: organizationName)
            let entityIdentifier = MetaEntityIdentifier(entityName: entityName, descriptions: parameters.currentDescriptions)
            let entityIndexName = MetaEntityIndexName(entityName: entityName, descriptions: parameters.currentDescriptions)
            let entity = MetaEntity(entityName: entityName,
                                    useCoreDataLegacyNaming: parameters.useCoreDataLegacyNaming,
                                    descriptions: parameters.currentDescriptions)
            let entityObjc = MetaEntityObjc(entityName: entityName, descriptions: parameters.currentDescriptions)
            
            var result: Meta.File = Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid)
                .adding(imports: try entity.imports())

            let identifierMeta = try entityIdentifier.meta()
            if identifierMeta.isEmpty == false {
                result = result
                    .adding(members: identifierMeta)
                    .adding(member: EmptyLine())
            }

            result = result
                .adding(members: try entity.meta())
                .adding(members: try entityObjc.meta())

            let indexMeta = try entityIndexName.meta()
            if indexMeta.isEmpty == false {
                result = result
                    .adding(member: EmptyLine())
                    .adding(members: indexMeta)
            }

            return result.swiftFile(in: directory)
            
        case .endpoint,
             .subtype:
            return nil
        }
    }
}
