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
        let entity = try descriptions.entity(for: entityName)

        return try [
            indexName(entity),
            extraIndexName(entity),
            extrasValidation(entity)
        ].flatMap { $0 }
    }

    private func indexName(_ entity: Entity) throws -> [FileBodyMember] {
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

                        return Case(name: property.transformedName(ignoreLexicon: false)).adding(parameter:
                            CaseParameter(type: (property.extra ? .optional(wrapped: indexTypeID) : indexTypeID))
                        )
                    } else {
                        return Case(name: property.transformedName(ignoreLexicon: false))
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
                        Variable(name: "\(property.transformedName())Relationship")
                            .with(type: extrasName)
                            .with(static: true)
                        )
                        .with(accessLevel: .public)
                        .adding(member: Return(value: .none + .named(property.transformedName()) | .call(Tuple()
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
                                        SwitchCase(name: property.transformedName(ignoreLexicon: false))
                                            .adding(value: SwitchCaseVariable(optionality: .some, name: "property"))
                                            .adding(member: Return(value: Reference.named("\"\(property.transformedName().snakeCased).\" + property.requestValue"))),
                                        SwitchCase(name: property.transformedName(ignoreLexicon: false))
                                            .adding(value: SwitchCaseVariable(optionality: .none, name: String()))
                                            .adding(member: Return(value: Value.string(property.transformedName().snakeCased)))
                                    ]
                                } else {
                                    return [
                                        SwitchCase(name: property.transformedName(ignoreLexicon: false))
                                            .adding(value: SwitchCaseVariable(name: "property"))
                                            .adding(member: Return(value: Reference.named("\"\(property.transformedName().snakeCased).\" + property.requestValue")))
                                    ]
                                }
                            } else {
                                return [
                                    SwitchCase(name: property.transformedName(ignoreLexicon: false))
                                        .adding(member: Return(value: Value.string(property.transformedName().snakeCased)))
                                ]
                            }
                        })
                ))
        ]
    }

    private func extrasValidation(_ entity: Entity) throws -> [FileBodyMember] {
        guard try entity.hasExtras(descriptions), entity.remote == true else { return [] }

        let parsedEntities: [String: Bool] = [entity.name: entity.hasPropertyExtras]
        let hasTestableCases: Bool = try {
            for property in try entity.extraIndexes(descriptions) {
                if property.relationship != nil, try property.hasRelationshipExtras(descriptions, parsedEntities) {
                    if property.extra { return true }
                } else {
                    return true
                }
            }
            return false
        }()

        guard hasTestableCases else { return [] }

        return [
            EmptyLine(),
            Extension(type: entity.typeID())
                .adding(member: EmptyLine())
                .adding(member:
                    ComputedProperty(variable: Variable(name: "shouldValidate").with(type: .bool))
                        .with(static: true)
                        .with(accessLevel: .public)
                        .adding(member: Return(value: Value.bool(true)))
                )
                .adding(member: EmptyLine())
                .adding(member:
                    Function(kind: .named("isEntityValid"))
                        .with(accessLevel: .public)
                        .with(resultType: .bool)
                        .adding(parameter: FunctionParameter(
                            alias: "for", name: "query", type: TypeIdentifier(name: .custom("Query")).adding(genericParameter: entity.typeID())
                        ))
                        .with(body: [
                            PlainCode(code: """
                            guard let requestedExtras = query.extras else { return true }

                            for requestedExtra in requestedExtras {
                            \(MetaCode(indentation: 1, meta:
                                Switch(reference: Reference.named("requestedExtra"))
                                    .with(cases: try entity.extraIndexes(descriptions).flatMap { property -> [SwitchCase] in
                                        if property.relationship != nil, try property.hasRelationshipExtras(descriptions, parsedEntities) {
                                            if property.extra {
                                                return [
                                                    SwitchCase(name: property.transformedName(ignoreLexicon: false))
                                                        .adding(value: Reference.named(".some"))
                                                        .adding(member: Reference.named("break")),
                                                    SwitchCase(name: property.transformedName(ignoreLexicon: false))
                                                        .adding(value: SwitchCaseVariable(optionality: .none, name: String()))
                                                        .adding(member: PlainCode(code: "if \(property.transformedName()).wasRequested == false { return false }"))
                                                ]
                                            } else {
                                                return [
                                                    SwitchCase(name: property.transformedName(ignoreLexicon: false))
                                                        .adding(member: Reference.named("break")),
                                                ]
                                            }
                                        } else {
                                            return [
                                                SwitchCase(name: property.transformedName(ignoreLexicon: false))
                                                    .adding(member: PlainCode(code: "if \(property.transformedName()).wasRequested == false { return false }"))
                                            ]
                                        }
                                    })
                            ))
                            }

                            return true
                            """)
                            ]
                        )
                    )
        ]
    }
}
