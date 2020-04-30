//
//  MetaEntityIndexName.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/27/19.
//

import Meta

struct MetaEntityIndexName {
    
    let entityName: String
    
    let descriptions: Descriptions
    
    func meta() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)

        return try [
            indexName(entity),
            extraIndexName(entity)
        ].flatMap { $0 }
    }

    private func indexName(_ entity: Entity) throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        return [
            Comment.mark("IndexName"),
            EmptyLine(),
            Type(identifier: entity.indexNameTypeID)
                .with(kind: .enum(indirect: false))
                .with(accessLevel: .public)
                .with(body: try entity.indexes(descriptions).map { Case(name: $0.name) })
                .adding(member: entity.lastRemoteRead ? Case(name: "lastRemoteRead") : nil)
        ]
    }

    private func extraIndexName(_ entity: Entity) throws -> [FileBodyMember] {
        guard try entity.hasExtras(descriptions) else { return [] }

        let extrasName = try entity.extrasIndexNameTypeID(descriptions)
        let parsedEntities: [String: Bool] = [entity.name: entity.hasPropertyExtras]
        let hasRelationshipExtras = try entity.properties.contains { try $0.hasRelationshipExtras(descriptions, parsedEntities) && $0.extra }

        return [
            EmptyLine(),
            Comment.mark("ExtrasIndexName"),
            EmptyLine(),
            Type(identifier: extrasName)
                .with(kind: .enum(indirect: true))
                .with(accessLevel: .public)
                .adding(inheritedType: .hashable)
                .with(body: try entity.extraIndexes(descriptions).compactMap { property in
                    if let relationship = property.relationship, try property.hasRelationshipExtras(descriptions, parsedEntities) {
                        let relationshipEntity = try descriptions.entity(for: relationship.entityName)
                        let indexTypeID = try relationshipEntity.extrasIndexNameTypeID(descriptions)

                        return Case(name: property.name).adding(parameter:
                            CaseParameter(type: (property.extra ? .optional(wrapped: indexTypeID) : indexTypeID))
                        )
                    } else {
                        return Case(name: property.name)
                    }
                })
                .adding(member: hasRelationshipExtras ? EmptyLine() : nil)
                .adding(members: try entity.extraIndexes(descriptions).compactMap { property in
                    guard property.relationship != nil,
                        try property.hasRelationshipExtras(descriptions, parsedEntities),
                        property.extra else {
                            return nil
                    }
                    return ComputedProperty(variable:
                        Variable(name: "\(property.name)Relationship")
                            .with(type: extrasName)
                            .with(static: true)
                        )
                        .with(accessLevel: .public)
                        .adding(member: Return(value: .none + .named(property.name) | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Value.nil))
                        )))
                }),
            EmptyLine(),
            Extension(type: extrasName)
                .adding(inheritedType: .remoteEntityExtrasIndexName)
                .adding(member:
                    ComputedProperty(variable: Variable(name: "requestValue").with(type: .string))
                        .with(accessLevel: .public)
                        .adding(member: Switch(reference: Reference.named(.`self`))
                        .with(cases: try entity.extraIndexes(descriptions).flatMap { property -> [SwitchCase] in
                            if property.relationship != nil, try property.hasRelationshipExtras(descriptions, parsedEntities) {
                                if property.extra {
                                    return [
                                        SwitchCase(name: property.name)
                                            .adding(value: SwitchCaseVariable(optionality: .some, name: "property"))
                                            .adding(member: Return(value: Reference.named("\"\(property.name.snakeCased).\" + property.requestValue"))),
                                        SwitchCase(name: property.name)
                                            .adding(value: SwitchCaseVariable(optionality: .none, name: String()))
                                            .adding(member: Return(value: Value.string(property.name.snakeCased)))
                                    ]
                                } else {
                                    return [
                                        SwitchCase(name: property.name)
                                            .adding(value: SwitchCaseVariable(name: "property"))
                                            .adding(member: Return(value: Reference.named("\"\(property.name.snakeCased).\" + property.requestValue")))
                                    ]
                                }
                            } else {
                                return [
                                    SwitchCase(name: property.name)
                                        .adding(member: Return(value: Value.string(property.name.snakeCased)))
                                ]
                            }
                        })
                ))
        ]
    }
}
