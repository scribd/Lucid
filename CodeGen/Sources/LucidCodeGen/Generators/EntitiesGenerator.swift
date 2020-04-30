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
    
    private let appVersion: String
    
    public init(descriptions: Descriptions, appVersion: String) {
        self.descriptions = descriptions
        self.appVersion = appVersion
    }
    
    public func generate(for element: Description, in directory: Path) throws -> File? {
        switch element {
        case .all:
            let filename = "EntityIndexValueTypes.swift"
            
            let header = MetaHeader(filename: filename)
            let subtype = MetaSubtypes(descriptions: descriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid())
                .with(body: try subtype.meta())
                .swiftFile(in: directory)

        case .entity(let entityName):
            let filename = "\(entityName).swift"
            
            let header = MetaHeader(filename: filename)
            let entityIdentifier = MetaEntityIdentifier(entityName: entityName, descriptions: descriptions)
            let entityIndexName = MetaEntityIndexName(entityName: entityName, descriptions: descriptions)
            let entity = MetaEntity(entityName: entityName, descriptions: descriptions, appVersion: appVersion)
            let entityObjc = MetaEntityObjc(entityName: entityName, descriptions: descriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid())
                .adding(imports: try entity.imports())
                .adding(members: try entityIdentifier.meta())
                .adding(member: EmptyLine())
                .adding(members: try entityIndexName.meta())
                .adding(member: EmptyLine())
                .adding(members: try entity.meta())
                .adding(members: try entityObjc.meta())
                .swiftFile(in: directory)
            
        case .endpoint,
             .subtype:
            return nil
        }
    }
}
