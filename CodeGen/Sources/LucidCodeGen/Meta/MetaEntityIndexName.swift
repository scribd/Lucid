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
        return try indexName() + relationshipIndexName()
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
                .with(body: try entity
                    .indexes(descriptions)
                    .map { Case(name: $0.transformedName(ignoreLexicon: false)) }
                )
                .adding(member: entity.lastRemoteRead ? Case(name: "lastRemoteRead") : nil),
            EmptyLine(),
            Extension(type: try entity.indexNameTypeID(descriptions))
                .adding(inheritedType: .queryResultConvertible)
                .adding(member:
                    ComputedProperty(variable: Variable(name: "requestValue")
                        .with(type: .string))
                        .with(accessLevel: .public)
                        .adding(member: Switch(reference: .named(.`self`))
                            .adding(cases: try entity.indexes(descriptions).map {
                                SwitchCase(name: $0.transformedName(ignoreLexicon: false))
                                    .adding(member: Return(value: Value.string($0.transformedName().snakeCased)))
                            })
                            .adding(case: entity.lastRemoteRead ?
                                SwitchCase(name: "lastRemoteRead").adding(member: Return(value: Value.string("last_remote_read"))) : nil
                            )
                        )
                )
        ]
    }

    private func relationshipIndexName() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard try entity.hasRelationshipIndexes(descriptions) else { return [] }

        return [
            EmptyLine(),
            Comment.mark("RelationshipIndexName"),
            EmptyLine(),
            Type(identifier: try entity.relationshipIndexNameTypeID(descriptions))
                .with(kind: .enum(indirect: try entity.hasRelationshipLoop(descriptions)))
                .with(accessLevel: .public)
                .adding(inheritedType: .relationshipPathConvertible)
                .adding(member: EmptyLine())
                .adding(member: TypeAlias(identifier: TypeAliasIdentifier(name: "AnyEntity"), value: .appAnyEntity).with(accessLevel: .public))
                .adding(member: EmptyLine())
                .adding(members: try entity
                    .indexes(descriptions)
                    .compactMap { entity in
                        guard let relationship = entity.relationship else { return nil }
                        let relationshipEntity = try descriptions.entity(for: relationship.entityName)
                        if try relationshipEntity.hasRelationshipIndexes(descriptions) {
                            return Case(name: "_\(entity.transformedName(ignoreLexicon: false))")
                                .adding(parameter: CaseParameter(
                                    type: .optional(wrapped: .array(element: try relationshipEntity.relationshipIndexNameTypeID(descriptions)))
                                ))
                        } else {
                            return Case(name: entity.transformedName(ignoreLexicon: false))
                        }
                    }
                )
                .adding(member: EmptyLine())
                .adding(members: try entity
                    .indexes(descriptions)
                    .compactMap { property in
                        guard let relationship = property.relationship else { return nil }
                        let relationshipEntity = try descriptions.entity(for: relationship.entityName)
                        guard try relationshipEntity.hasRelationshipIndexes(descriptions) else { return nil }
                        return Function(kind: .named(property.transformedName(ignoreLexicon: false)))
                            .with(static: true)
                            .with(accessLevel: .public)
                            .with(resultType: try entity.relationshipIndexNameTypeID(descriptions))
                            .adding(parameter: FunctionParameter(
                                alias: "_",
                                name: "children",
                                type: .optional(wrapped: .array(element: try relationshipEntity.relationshipIndexNameTypeID(descriptions)))
                            ).with(defaultValue: Value.nil))
                            .adding(member: Return(value: +.named("_\(property.transformedName(ignoreLexicon: false))") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Reference.named("children")))
                            )))
                    }
                )
                .adding(member: EmptyLine())
                .adding(member: ComputedProperty(variable: Variable(name: "paths")
                    .with(type: .array(element: .array(element: .appAnyEntityIndexName))))
                    .with(accessLevel: .public)
                    .adding(member: PlainCode(code: """
                    switch self {
                    \(try entity.indexes(descriptions).compactMap { property in
                        guard let relationship = property.relationship else { return nil }
                        let relationshipEntity = try descriptions.entity(for: relationship.entityName)
                        if try relationshipEntity.hasRelationshipIndexes(descriptions) {
                            return """
                            case ._\(property.transformedName(ignoreLexicon: false))(let children):
                                return [[.\(entity.name.camelCased().variableCased())(.\(property.transformedName(ignoreLexicon: false)))]] + (children ?? []).flatMap { child -> [[\(TypeIdentifier.appAnyEntityIndexName.swiftString)]] in
                                    child.paths.map { path -> [\(TypeIdentifier.appAnyEntityIndexName.swiftString)] in
                                        [.\(entity.name.camelCased().variableCased())(.\(property.transformedName(ignoreLexicon: false)))] + path
                                    }
                                }
                            """
                        } else {
                            return """
                            case .\(property.transformedName(ignoreLexicon: false)):
                                return [[.\(entity.name.camelCased().variableCased())(.\(property.transformedName(ignoreLexicon: false)))]]
                            """
                        }
                    }.joined(separator: "\n"))
                    }
                    """))
                )
        ]
    }
}
