//
//  MetaEntityIndexName.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/27/19.
//

import Meta
import LucidCodeGenCore

struct MetaEntityIndexName {
    
    let entityName: String
    
    let descriptions: Descriptions
    
    func meta() throws -> [FileBodyMember] {
        return try indexName()
    }

    private func indexName() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard try entity.hasIndexes(descriptions) else { return [] }
        
        return [
            Comment.mark("IndexName"),
            EmptyLine(),
            Type(identifier: try entity.indexNameTypeID(descriptions))
                .with(kind: .enum(indirect: false))
                .with(accessLevel: .public)
                .with(body: try entity.indexes(descriptions).map { Case(name: $0.transformedName(ignoreLexicon: false)) })
                .adding(member: entity.lastRemoteRead ? Case(name: "lastRemoteRead") : nil),
        ]
    }
}
