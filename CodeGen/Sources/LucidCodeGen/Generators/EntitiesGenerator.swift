//
//  EntitiesGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/20/19.
//

import Meta
import PathKit

public final class EntitiesGenerator: Generator {
    
    public let name = "entities"
    
    private let descriptions: Descriptions
    
    private let reactiveKit: Bool

    private let useCoreDataLegacyNaming: Bool
    
    public init(descriptions: Descriptions, reactiveKit: Bool, useCoreDataLegacyNaming: Bool) {
        self.descriptions = descriptions
        self.reactiveKit = reactiveKit
        self.useCoreDataLegacyNaming = useCoreDataLegacyNaming
    }
    
    public func generate(for element: Description, in directory: Path) throws -> File? {
        switch element {
        case .all:
            let filename = "EntityIndexValueTypes.swift"
            
            let header = MetaHeader(filename: filename)
            let subtype = MetaSubtypes(descriptions: descriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid(reactiveKit: reactiveKit))
                .with(body: try subtype.meta())
                .swiftFile(in: directory)

        case .entity(let entityName):
            let filename = "\(entityName.camelCased().suffixedName()).swift"
            
            let header = MetaHeader(filename: filename)
            let entityIdentifier = MetaEntityIdentifier(entityName: entityName, descriptions: descriptions)
            let entityIndexName = MetaEntityIndexName(entityName: entityName, descriptions: descriptions)
            let entity = MetaEntity(entityName: entityName, useCoreDataLegacyNaming: useCoreDataLegacyNaming, descriptions: descriptions)
            let entityObjc = MetaEntityObjc(entityName: entityName, descriptions: descriptions)
            
            var result: Meta.File = Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid(reactiveKit: reactiveKit))
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
                    .adding(members: try entityIndexName.meta())
            }

            return result.swiftFile(in: directory)
            
        case .endpoint,
             .subtype:
            return nil
        }
    }
}
