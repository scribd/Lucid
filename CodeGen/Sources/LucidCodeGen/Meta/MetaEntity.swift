//
//  MetaEntity.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/20/19.
//

import Meta
import LucidCodeGenCore

struct MetaEntity {
    
    let entityName: String

    let useCoreDataLegacyNaming: Bool
    
    let descriptions: Descriptions
    
    func imports() throws -> [Import] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.persist else { return [] }
        return [Import(name: "CoreData")]
    }
    
    func meta() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)

        let inheritenceTypeString: String
        switch entity.inheritenceType {
        case .localAndRemote:
            inheritenceTypeString = "LocalEntiy, RemoteEntity"
        case .local:
            inheritenceTypeString = "LocalEntiy"
        case .remote:
            inheritenceTypeString = "RemoteEntity"
        case .basic:
            inheritenceTypeString = "Entity"
        }

        return try [
            [
                Comment.mark(entity.transformedName),
                EmptyLine(),
                try entityType()
            ],
            payloadInitializer(),
            [
                EmptyLine(),
                Comment.mark(inheritenceTypeString),
                EmptyLine(),
                try remoteEntityExtension(),
            ],
            coreDataExtensions(),
            coreDataConversionUtils(),
            try mutableSupportExtension(),
            try entityMergingFunction()
        ].flatMap { $0 }
    }
    
    // MARK: - Entity
    
    private func entityType() throws -> Type {
        let entity = try descriptions.entity(for: entityName)

        guard let identifierTypeID = try entity.identifier.equivalentIdentifierTypeID(entity, descriptions) ?? entity.identifierTypeID else {
            throw CodeGenError.entityUIDNotFound(entity.name)
        }

        return Type(identifier: entity.typeID())
            .adding(inheritedType: .codable)
            .with(kind: .class(final: true))
            .with(accessLevel: .public)
            .with(body: [
                [
                    EmptyLine(),
                    TypeAlias(
                        identifier: TypeAliasIdentifier(name: "Metadata"),
                        value: try entity.metadataTypeID(descriptions)
                    ).with(accessLevel: .public),
                    TypeAlias(
                        identifier: TypeAliasIdentifier(name: TypeIdentifier.resultPayload.name),
                        value: TypeIdentifier(name: TypeIdentifier.endpointResultPayload.name)
                    ).with(accessLevel: .public),
                    TypeAlias(
                        identifier: TypeAliasIdentifier(name: "RelationshipIdentifier"),
                        value: .entityRelationshipIdentifier
                    ).with(accessLevel: .public),
                    TypeAlias(
                        identifier: TypeAliasIdentifier(name: "Subtype"),
                        value: .entitySubtype
                    ).with(accessLevel: .public),
                    TypeAlias(
                        identifier: TypeAliasIdentifier(name: "QueryContext"),
                        value: entity.queryContext ? TypeIdentifier(name: "\(entity.transformedName)QueryContext") : .never
                    ).with(accessLevel: .public),
                    TypeAlias(
                        identifier: TypeAliasIdentifier(name: "RelationshipIndexName"),
                        value: try entity.relationshipIndexNameTypeID(descriptions)
                    ).with(accessLevel: .public),
                    EmptyLine(),
                    Comment.comment("IdentifierTypeID"),
                    Property(variable: Variable(name: "identifierTypeID")
                        .with(immutable: true))
                        .with(accessLevel: .public)
                        .with(value: Value.string(identifierTypeID))
                        .with(static: true),
                    EmptyLine(),
                    Comment.comment("identifier"),
                    Property(variable: Variable(name: "identifier")
                        .with(immutable: true)
                        .with(type: entity.identifierTypeID()))
                        .with(accessLevel: .public),
                    EmptyLine(),
                ],
                try lastRemoteReadProperty(),
                entity.mutable ? [
                    Property(variable: Variable(name: "isSynced")
                        .with(immutable: true)
                        .with(type: .bool))
                            .with(accessLevel: .public),
                            EmptyLine()
                    ] : [],
                entity.values.isEmpty ? [] : [Comment.comment("properties")],
                try properties(for: entity.values),
                entity.relationships.isEmpty ? [] : [Comment.comment("relationships")],
                try properties(for: entity.relationships),
                [try initializer()]
            ].flatMap { $0 }
        )
    }
    
    // MARK: - Properties
    
    private func properties(for properties: [EntityProperty]) throws -> [TypeBodyMember] {
        return try properties.flatMap { property -> [TypeBodyMember] in
            return [
                Property(variable: property.variable
                    .with(type: try property.valueTypeID(descriptions))
                    .with(immutable: true))
                    .with(accessLevel: .public),
                EmptyLine()
            ]
        }
    }
    
    private func lastRemoteReadProperty() throws -> [TypeBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        
        guard entity.lastRemoteRead else { return [] }
        
        return [
            Comment.comment("Last Remote Read"),
            Property(variable: Variable(name: "lastRemoteRead")
                .with(type: entity.mutable ? .optional(wrapped: .date) : .date))
                .with(accessLevel: .public),
            EmptyLine()
        ]
    }
    
    // MARK: - Initializers
    
    private func initializer() throws -> Function {
        let entity = try descriptions.entity(for: entityName)
        return Function(kind: .`init`)
            .with(accessLevel: entity.mutable ? .public : .none)
            .adding(parameter: entity.hasVoidIdentifier ? nil :
                FunctionParameter(name: "identifier", type: entity.identifiableTypeID)
                    .with(defaultValue: entity.mutable && entity.identifier.isProperty == false ?
                        entity.identifierTypeID().reference | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "value", value: +.named("local") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: TypeIdentifier.uuid.reference | .call() + .named("uuidString")))
                            )))
                            .adding(parameter: TupleParameter(name: "remoteSynchronizationState", value: +.named("outOfSync")))
                        ) : nil
                    )
            )
            .adding(parameter: entity.lastRemoteRead ? FunctionParameter(name: "lastRemoteRead", type: entity.mutable ? .optional(wrapped: .date) : .date) : nil)
            .adding(parameter: entity.mutable ? FunctionParameter(name: "isSynced", type: .bool).with(defaultValue: Value.bool(false)) : nil)
            .adding(parameters: try entity.valuesThenRelationships.map { property in
                FunctionParameter(name: property.transformedName(), type: try property.valueTypeID(descriptions))
                    .with(defaultValue: property.defaultValue?.variableValue)
            })
            .adding(member: EmptyLine())
            .adding(member: Assignment(
                variable: Reference.named(.`self`) + .named("identifier"),
                value: entity.hasVoidIdentifier ?
                    entity.identifierTypeID().reference | .call() :
                    Reference.named("identifier") + entity.identifierVariable.reference
            ))
            .adding(member: entity.lastRemoteRead ? Assignment(
                variable: .named(.`self`) + .named("lastRemoteRead"),
                value: Reference.named("lastRemoteRead")
            ) : nil)
            .adding(member: entity.mutable ? Assignment(
                variable: .named(.`self`) + .named("isSynced"),
                value: Reference.named("isSynced")
            ) : nil)

            .adding(members: entity.valuesThenRelationships.map { property in
                Assignment(
                    variable: .named(.`self`) + property.entityReference,
                    value: property.variable.reference
                )
            })
    }
    
    private func payloadInitializer() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.remote else { return [] }

        let identifierFunctionParameter: [FunctionParameter]
        switch entity.identifier.identifierType {
        case .scalarType,
             .property,
             .void:
            identifierFunctionParameter = [FunctionParameter(name: "payload", type: entity.payloadTypeID)]
        case .relationships:
            identifierFunctionParameter = [
                FunctionParameter(name: "identifier", type: entity.identifiableTypeID),
                FunctionParameter(name: "payload", type: entity.payloadTypeID)
            ]
        }
        
        let identifierTupleParameter: TupleParameter?
        switch entity.identifier.identifierType {
        case .scalarType,
             .property:
            identifierTupleParameter = TupleParameter(name: "identifier", value: Reference.named("payload") + .named("identifier"))
        case .relationships:
            identifierTupleParameter = TupleParameter(name: "identifier", value: Reference.named("identifier"))
        case .void:
            identifierTupleParameter = nil
        }
        
        let lastRemoteReadTupleParameter = entity.lastRemoteRead ?
            TupleParameter(name: "lastRemoteRead", value: TypeIdentifier.date.reference | .call()): nil

        return [
            EmptyLine(),
            Comment.mark("\(entity.payloadTypeID.name.swiftString) Initializer"),
            EmptyLine(),
            Extension(type: entity.typeID())
                .adding(member: Function(kind: .`init`(convenience: true))
                    .adding(parameters: identifierFunctionParameter)
                    .adding(member: Reference.named(.`self`) + .named(.`init`) | .call(Tuple()
                        .adding(parameter: identifierTupleParameter)
                        .adding(parameter: lastRemoteReadTupleParameter)
                        .adding(parameter: entity.mutable ? TupleParameter(name: "isSynced", value: Value.bool(true)) : nil)
                        .adding(parameters: try entity.valuesThenRelationships.map { try payloadInitCallParameter(for: $0) })
                    ))
                )
        ]
    }
    
    private func payloadInitCallParameter(for property: EntityProperty) throws -> TupleParameter {
        switch property.propertyType {
        case .scalar,
             .subtype,
             .array:
            return TupleParameter(name: property.transformedName(), value: Reference.named("payload") + Reference.named(property.payloadName))
        case .relationship(let relationship):
            let relationshipEntity = try descriptions.entity(for: relationship.entityName)
            switch relationship.association {
            case .toOne where relationshipEntity.identifier.isRelationship:
                let value: Reference
                if property.lazy {
                    value = Reference.named("payload") +
                        .named(property.payloadName) +
                        .named("identifier") | .call(Tuple()
                            .adding(parameter:  TupleParameter(name: "from", value: .named("payload") + .named("identifier") + relationshipEntity.identifierVariable.reference))
                        )
                } else if property.nullable {
                    value = Reference.named("payload") +
                        .named(property.payloadName) +
                        .named(.flatMap) |
                        .block(FunctionBody()
                            .adding(parameter: FunctionBodyParameter())
                            .adding(member: .named("payload") + .named("identifier") + relationshipEntity.identifierVariable.reference)
                        )
                } else {
                    value = .named("payload") + .named("identifier") + relationshipEntity.identifierVariable.reference
                }
                return TupleParameter(name: property.transformedName(), value: value)

            case .toOne:
                let value: Reference
                if property.lazy {
                    value = Reference.named("payload") +
                        .named(property.payloadName) +
                        .named("identifier") | .call()
                } else {
                    value = Reference.named("payload") +
                        .named(property.payloadName) |
                        (property.nullable ? .unwrap : .none) +
                        .named("identifier")
                }
                return TupleParameter(name: property.transformedName(), value: value)

            case .toMany:
                let value: Reference
                if property.lazy {
                    value = Reference.named("payload") +
                        .named(property.payloadName) +
                        .named("identifiers") | .call()
                } else {
                    value = Reference.named("payload") +
                        .named(property.payloadName) |
                        (property.nullable ? .unwrap : .none) +
                        .named("lazy") +
                        .named(.map) |
                        .block(FunctionBody()
                            .adding(member: Reference.named("$0") + .named("identifier"))
                        ) + .named("any")
                }
                return TupleParameter(name: property.transformedName(), value: value)
            }
        }
    }
    
    // MARK: - Mutable Support Extension
    
    private func mutableSupportExtension() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.mutable else { return [] }
        
        return [
            EmptyLine(),
            Comment.mark("Mutable support"),
            EmptyLine(),
            Extension(type: entity.typeID())
                .adding(inheritedType: .mutableEntity)
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .named("merge"))
                    .with(accessLevel: .public)
                    .adding(parameter: FunctionParameter(name: "identifier", type: entity.identifierTypeID()))
                    .adding(member: .named(.`self`) + .named("identifier") + .named("property") + .named("value") + .named("merge") | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "with", value: .named("identifier") + .named("value")))
                    ))
                    .adding(member: Assignment(
                        variable: .named(.`self`) + .named("identifier") + .named("_remoteSynchronizationState") + .named("value"),
                        value: .named("identifier") + .named("_remoteSynchronizationState") + .named("value")
                    ))
                )
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .named("updated"))
                    .with(accessLevel: .public)
                    .adding(parameters: try entity.valuesThenRelationships
                        .filter { $0.mutable }
                        .map { property in
                            FunctionParameter(
                                name: property.transformedName(),
                                type: try property.valueTypeID(descriptions)
                            ).with(defaultValue: property.defaultValue?.variableValue)
                        }
                    )
                    .with(resultType: entity.typeID())
                    .adding(member: EmptyLine())
                    .adding(member:
                        Return(value: entity.typeID().reference | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "identifier", value: .named(.`self`) + .named("identifier")))
                            .adding(parameter: entity.lastRemoteRead ? TupleParameter(name: "lastRemoteRead", value: .named(.`self`) + .named("lastRemoteRead")) : nil)
                            .adding(parameter: entity.lastRemoteRead ? TupleParameter(name: "isSynced", value: Value.bool(false)) : nil)
                            .adding(parameters: entity.valuesThenRelationships.map { property in
                                TupleParameter(
                                    name: property.transformedName(),
                                    value: property.mutable ? .named(property.transformedName()) : .named(.`self`) + .named(property.transformedName())
                                )
                            })
                        ))
                    )
                )
        ]
    }

    // MARK: - Entity / LocalEntity / RemoteEntity Extension
    
    private func remoteEntityExtension() throws -> Extension {
        let entity = try descriptions.entity(for: entityName)
        return Extension(type: entity.typeID())
            .adding(inheritedType: entity.inheritenceType.isLocal ? .localEntity : nil)
            .adding(inheritedType: entity.inheritenceType.isRemote ? .remoteEntity : nil)
            .adding(inheritedType: entity.inheritenceType.isBasic ? .entity : nil)
            .adding(member: EmptyLine())
            .adding(member: try indexValueFunction())
            .adding(member: EmptyLine())
            .adding(member: try entityRelationshipIndicesProperty())
            .adding(member: EmptyLine())
            .adding(member: try equalityFunction())
            .adding(members: try shouldOverwriteFunction())
    }

    private func indexValueFunction() throws -> Function {
        let entity = try descriptions.entity(for: entityName)
        
        let cases: [SwitchCase] = try entity
            .indexes(descriptions)
            .compactMap { property in

                let returnReference: Reference
                switch property.propertyType {
                case .scalar(let type):
                    returnReference = +type.reference | .call(Tuple().adding(parameter: TupleParameter(value: property.reference)))

                case .subtype(let name):
                    returnReference = +.named("subtype") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: +.named(name.camelCased().suffixedName().variableCased()) | .call(Tuple()
                            .adding(parameter: TupleParameter(value: property.reference)
                        )))
                    ))

                case .relationship(let relationship) where relationship.association == .toMany:
                    returnReference = +.named("array") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: property.reference + .named("lazy") + .named("map") | .block(FunctionBody()
                            .adding(member: +.named("relationship") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: +relationship.reference | .call(Tuple()
                                    .adding(parameter: TupleParameter(value: Reference.named("$0")))
                                    )))
                                ))
                            ) + .named("any")
                        )))

                case .relationship(let relationship):
                    returnReference = +.named("relationship") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: +relationship.reference | .call(Tuple()
                            .adding(parameter: TupleParameter(value: property.reference))
                        )))
                    )

                case .array(.scalar(let type)):
                    returnReference = +.named("array") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: property.reference + .named("lazy") + .named("map") | .block(FunctionBody()
                            .adding(member: +type.reference | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Reference.named("$0")))
                            ))
                        ) + .named("any"))
                    ))

                case .array:
                    return nil
                }
                
                if try property.valueTypeID(descriptions).isOptionalOrLazy {
                    return SwitchCase(name: property.transformedName(ignoreLexicon: false))
                        .adding(member: Return(value: (property.entityReferenceValue + .named("flatMap") | .block(FunctionBody()
                            .adding(parameter: FunctionBodyParameter(name: property.transformedName()))
                            .adding(member: +.named("optional") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: returnReference))
                            ))) ?? +.named("none")
                        )))
                } else {
                    return SwitchCase(name: property.transformedName(ignoreLexicon: false))
                        .adding(member: Return(value: returnReference))
                }
            }

        let mutableSwitchCase =  SwitchCase(name: "lastRemoteRead").adding(member: Return(value: .named("lastRemoteRead") + .named(.flatMap) | .block(FunctionBody()
            .adding(member: +.named("date") | .call(Tuple()
                .adding(parameter: TupleParameter(value: Reference.named("$0")))
            ))) ?? .value(+.named("none")))
        )

        let immutableSwitchCase = SwitchCase(name: "lastRemoteRead").adding(member: Return(value: +.named("date") | .call(Tuple()
            .adding(parameter: TupleParameter(value: Reference.named("lastRemoteRead")))
        )))

        let switchCase = entity.mutable ? mutableSwitchCase : immutableSwitchCase

        return Function(kind: .named("entityIndexValue"))
            .with(accessLevel: .public)
            .adding(parameter: FunctionParameter(alias: "for", name: "indexName", type: try entity.indexNameTypeID(descriptions)))
            .with(resultType: .entityIndexValue)
            .adding(member: cases.isEmpty ?
                Return(value: +.named("none")) :
                Switch(reference: .named("indexName"))
                .with(cases: cases)
                    .adding(case: entity.lastRemoteRead ? switchCase : nil
                )
        )
    }
    
    private func entityRelationshipIndicesProperty() throws -> ComputedProperty {
        let entity = try descriptions.entity(for: entityName)
        
        return ComputedProperty(variable: Variable(name: "entityRelationshipIndices")
            .with(type: .array(element: try entity.indexNameTypeID(descriptions))))
            .with(accessLevel: .public)
            .adding(member: Return(value: Value.array(try entity.indexes(descriptions).compactMap { property in
                switch property.propertyType {
                case .relationship,
                     .array(.relationship):
                    return .reference(+.named(property.transformedName()))
                case .scalar,
                     .subtype,
                     .array:
                    return nil
                }
            })))
    }
    
    private func equalityFunction() throws -> Function {
        let entity = try descriptions.entity(for: entityName)
        
        return Function(kind: .operator(.equal))
            .with(accessLevel: .public)
            .with(static: true)
            .adding(parameter: FunctionParameter(name: "lhs", type: entity.typeID()))
            .adding(parameter: FunctionParameter(name: "rhs", type: entity.typeID()))
            .with(resultType: .bool)
            .adding(members: entity.valuesThenRelationships.filter { $0.useForEquality }.map { property in
                Guard(condition: (.named("lhs") + property.entityReference) == (.named("rhs") + property.entityReference))
                    .adding(member: Return(value: Value.bool(false)))
            })
            .adding(member: Return(value: Value.bool(true)))
    }

    private func shouldOverwriteFunction() throws -> [TypeBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.requiresCustomShouldOverwriteFunction,
            entity.extendedPropertyNamesForShouldOverwrite.count > 0 else { return [] }

        return [
            EmptyLine(),
            Function(kind: .named("shouldOverwrite"))
                .with(accessLevel: .public)
                .adding(parameter: FunctionParameter(alias: "with", name: "updated", type: entity.typeID()))
                .with(resultType: .bool)
                .adding(members: entity.extendedPropertyNamesForShouldOverwrite.map { extendedProperty in
                    If(condition: (.named("updated") + Reference.named(extendedProperty)) != Reference.named(extendedProperty))
                        .adding(member: Return(value: Value.bool(true)))
                })
                .adding(member:
                    If(condition: .named("updated") != .named("self"))
                        .adding(member: Return(value: Value.bool(true)))
                )
                .adding(member: Return(value: Value.bool(false)))
        ]
    }

    // MARK: - CoreData Extensions
    
    private func coreDataExtensions() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.persist else { return [] }

        let coreDataIndexName: [FileBodyMember] = try entity.hasIndexes(descriptions) ?
            [
                EmptyLine(),
                Comment.mark("CoreDataIndexName"),
                EmptyLine(),
                try coreDataIndexNameExtension()
            ] : []

        return coreDataIndexName + [
            EmptyLine(),
            Comment.mark("CoreDataEntity"),
            EmptyLine(),
            try coreDataEntityExtension()
        ]
    }
    
    private func coreDataIndexNameExtension() throws -> Extension {
        let entity = try descriptions.entity(for: entityName)

        return Extension(type: try entity.indexNameTypeID(descriptions))
            .adding(inheritedType: .coreDataIndexName)
            .adding(member: EmptyLine())
            .adding(member: ComputedProperty(variable: Variable(name: "predicateString")
                .with(type: .string))
                .with(accessLevel: .public)
                .adding(member: Switch(reference: .named(.`self`))
                    .with(cases: try entity.indexes(descriptions).map { property in
                        SwitchCase(name: property.transformedName(ignoreLexicon: false))
                            .adding(member: Return(value: Value.string("_\(property.coreDataName(useCoreDataLegacyNaming: useCoreDataLegacyNaming))")))
                    })
                    .adding(case: entity.lastRemoteRead ?
                        SwitchCase(name: "lastRemoteRead")
                            .adding(member: Return(value: Value.string(useCoreDataLegacyNaming ? "__lastRemoteRead" : "__last_remote_read"))) : nil
                    )
                )
            )
            .adding(member: EmptyLine())
            .adding(member: ComputedProperty(variable: Variable(name: "isOneToOneRelationship")
                .with(type: .bool))
                .with(accessLevel: .public)
                .adding(member: Switch(reference: .named(.`self`))
                    .with(cases: try entity.indexes(descriptions).map { property in
                        let isOneToOneRelationship = property.relationship?.association == .toOne
                        return SwitchCase(name: property.transformedName(ignoreLexicon: false))
                            .adding(member: Return(value: Value.bool(isOneToOneRelationship)))
                    })
                    .adding(case: entity.lastRemoteRead ?
                        SwitchCase(name: "lastRemoteRead")
                            .adding(member: Return(value: Value.bool(false))) : nil
                    )
                )
            )
            .adding(member: EmptyLine())
            .adding(member: ComputedProperty(variable: Variable(name: "identifierTypeIDRelationshipPredicateString")
                .with(type: .optional(wrapped: .string)))
                .with(accessLevel: .public)
                .adding(member: Switch(reference: .named(.`self`))
                    .with(cases: try entity.indexes(descriptions).map { property in
                        SwitchCase(name: property.transformedName(ignoreLexicon: false))
                            .adding(member: Return(value: property.relationship?.association == .toOne ?
                                Value.string("__\(property.coreDataName(useCoreDataLegacyNaming: useCoreDataLegacyNaming))\(useCoreDataLegacyNaming ? "TypeUID" : "_type_uid")") :
                                Value.nil
                            ))
                        }
                    )
                    .adding(case: entity.lastRemoteRead ?
                        SwitchCase(name: "lastRemoteRead")
                            .adding(member: Return(value: Value.nil)) : nil
                    )
                )
            )
    }
    
    private func coreDataEntityExtension() throws -> Extension {
        let entity = try descriptions.entity(for: entityName)

        return Extension(type: entity.typeID())
            .adding(inheritedType: .coreDataEntity)
            .adding(member: EmptyLine())
            .adding(member: try entityFromCoreDataEntityFunction())
            .adding(member: EmptyLine())
            .adding(member: try mergeInCoreDataEntityFunction())
            .adding(member: EmptyLine())
            .adding(member: try initFromCoreDataEntity())
    }
    
    private func entityFromCoreDataEntityFunction() throws -> Function {
        let entity = try descriptions.entity(for: entityName)

        let entityInitializer = entity.typeID().reference | .call(Tuple()
            .adding(parameter: TupleParameter(name: "coreDataEntity", value: Reference.named("coreDataEntity")))
        )
        
        let body: FunctionBodyMember
        if try initFromCoreDataEntity().throws == false {
            body = Return(value: entityInitializer)
        } else {
            body = Do(body: [
                Return(value: .try | entityInitializer)
            ], catch: Catch()
                .adding(member: Reference.named("Logger") + .named("log") | .call(Tuple()
                    .adding(parameter: TupleParameter(value: +Reference.named("error")))
                    .adding(parameter: TupleParameter(value: Value.string("\\(\(entity.transformedName).self): \\(error)")))
                    .adding(parameter: TupleParameter(name: "domain", value: Value.string("Lucid")))
                    .adding(parameter: TupleParameter(name: "assert", value: Value.bool(true)))
                ))
                .adding(member: Return(value: Value.nil))
            )
        }
        
        return Function(kind: .named("entity"))
            .with(accessLevel: .public)
            .with(static: true)
            .adding(parameter: FunctionParameter(alias: "from", name: "coreDataEntity", type: try entity.coreDataEntityTypeID()))
            .with(resultType: .optional(wrapped: entity.typeID()))
            .adding(member: body)
    }
    
    private func mergeInCoreDataEntityFunction() throws -> Function {
        let entity = try descriptions.entity(for: entityName)

        let coreDataEntity = Reference.named("coreDataEntity")
        let coreDataValue = Reference.named("coreDataValue") | .call()
        
        return Function(kind: .named("merge"))
            .with(accessLevel: .public)
            .adding(parameter: FunctionParameter(alias: "into", name: "coreDataEntity", type: try entity.coreDataEntityTypeID()))
            .adding(member: coreDataEntity + .named("setProperty") | .call(Tuple()
                .adding(parameter: TupleParameter(value: entity.identifierTypeID().reference + .named("remotePredicateString")))
                .adding(parameter: TupleParameter(name: "value", value: .named("identifier") + .named("remoteCoreDataValue") | .call()))
            ))
            .adding(member: coreDataEntity + .named("setProperty") | .call(Tuple()
                .adding(parameter: TupleParameter(value: entity.identifierTypeID().reference + .named("localPredicateString")))
                .adding(parameter: TupleParameter(name: "value", value: .named("identifier") + .named("localCoreDataValue") | .call()))
            ))
            .adding(member: Assignment(
                variable: coreDataEntity + .named(useCoreDataLegacyNaming ? "__typeUID" : "__type_uid"),
                value: .named("identifier") + .named("identifierTypeID")
            ))
            .adding(member: entity.remote ?
                Assignment(
                    variable: coreDataEntity + .named(useCoreDataLegacyNaming ? "_remoteSynchronizationState" : "_remote_synchronization_state"),
                    value: .named("identifier") + .named("_remoteSynchronizationState") + .named("value") + coreDataValue
                ) : nil
            )
            .adding(member: entity.lastRemoteRead ?
                entity.mutable ?
                    coreDataEntity + .named("setProperty") | .call(Tuple()
                        .adding(parameter: TupleParameter(
                            value: Value.string(useCoreDataLegacyNaming ? "__lastRemoteRead" : "__last_remote_read")
                        ))
                        .adding(parameter: TupleParameter(
                            name: "value",
                            value: Reference.named("lastRemoteRead")
                        ))
                    ) as FunctionBodyMember :
                    Assignment(
                        variable: coreDataEntity + .named(useCoreDataLegacyNaming ? "__lastRemoteRead" : "__last_remote_read"),
                        value: Reference.named("lastRemoteRead")
                    ) as FunctionBodyMember
                : nil
            )
            .adding(members: try entity.valuesThenRelationships.flatMap { property -> [FunctionBodyMember] in
                let coreDataPropertyName = "_\(property.coreDataName(useCoreDataLegacyNaming: useCoreDataLegacyNaming))"
                let lazyFlagBodyMember: FunctionBodyMember = {
                    guard property.lazy else { return Reference.none }
                    return coreDataEntity + .named("setProperty") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Value.string("_\(coreDataPropertyName)\(useCoreDataLegacyNaming ? "ExtraFlag" : "_lazy_flag")")))
                        .adding(parameter: TupleParameter(name: "value", value: property.reference + Reference.named("coreDataFlagValue")))
                    )
                }()

                if property.isRelationship && property.isArray == false {
                    let remoteProperty: FunctionBodyMember
                    let isStoredAsOptional = try property.propertyType.isStoredAsOptional(descriptions)
                    if isStoredAsOptional == false {
                        remoteProperty = coreDataEntity + .named("setProperty") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Value.string("_\(property.coreDataName(useCoreDataLegacyNaming: useCoreDataLegacyNaming))")))
                            .adding(parameter: TupleParameter(name: "value", value: property.entityReference |
                                (property.lazy == false && property.nullable ? .unwrap : .none) |
                                (property.lazy ? .none + .lazyValue | .call() : .none) +
                                .named("remoteCoreDataValue") |
                                .call()))
                        )
                    } else {
                        remoteProperty = Assignment(variable: coreDataEntity + .named("_\(property.coreDataName(useCoreDataLegacyNaming: useCoreDataLegacyNaming))"),
                                                    value: property.entityReference |
                                                        (property.lazy ? .none + .lazyValue | .call() : .none) +
                                                        .named("remoteCoreDataValue") | .call())
                    }

                    let localProperty = Assignment(variable: coreDataEntity + .named("__\(property.coreDataName(useCoreDataLegacyNaming: useCoreDataLegacyNaming))"),
                                                   value: property.entityReference |
                                                    (property.lazy ? .none + .lazyValue | .call() : .none) +
                                                    .named("localCoreDataValue") | .call())
                    
                    let propertyTypeID = try property.valueTypeID(descriptions)
                    let identifierTypeIDProperty = Assignment(variable: coreDataEntity + .named("__\(property.coreDataName(useCoreDataLegacyNaming: useCoreDataLegacyNaming))\(useCoreDataLegacyNaming ? "TypeUID" : "_type_uid")"),
                                                              value: property.entityReference |
                                                                (property.lazy ? .none + .lazyValue | .call() : .none) |
                                                                (propertyTypeID.isOptionalOrLazy ? .unwrap : .none) +
                                                                .named("identifierTypeID"))
                    
                    return [
                        remoteProperty,
                        localProperty,
                        identifierTypeIDProperty,
                        lazyFlagBodyMember
                    ]
                } else {
                    let isStoredAsOptional = try property.propertyType.isStoredAsOptional(descriptions)
                    let propertyValueTypeID = try property.valueTypeID(descriptions)

                    let bodyMember: FunctionBodyMember = {
                        if propertyValueTypeID.isOptionalOrLazy && isStoredAsOptional == false {
                            return coreDataEntity + .named("setProperty") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Value.string(coreDataPropertyName)))
                                .adding(parameter: TupleParameter(name: "value", value: property.referenceValue + coreDataValue))
                            )
                        } else {
                            return Assignment(variable: coreDataEntity + .named(coreDataPropertyName),
                                              value: property.entityReferenceValue + coreDataValue)
                        }
                    }()

                    return [
                        bodyMember,
                        lazyFlagBodyMember
                    ]
                }
            })
    }
    
    private func initFromCoreDataEntity() throws -> Function {
        let entity = try descriptions.entity(for: entityName)
        
        let identifierValue: VariableValue? = {
            if entity.hasVoidIdentifier {
                return nil
            } else if entity.identifier == .none {
                return entity.identifierTypeID().reference | .call()
            } else {
                return .try | .named("coreDataEntity") + .named("identifierValueType") | .call(Tuple()
                    .adding(parameter: TupleParameter(value: entity.identifierTypeID().reference + .named(.`self`)))
                    .adding(parameter: TupleParameter(
                        name: "identifierTypeID",
                        value: .named("coreDataEntity") + .named(useCoreDataLegacyNaming ? "__typeUID" : "__type_uid")
                    ))
                    .adding(parameter: entity.remote ? TupleParameter(
                        name: "remoteSynchronizationState",
                        value: .named("coreDataEntity") + .named(
                            useCoreDataLegacyNaming ? "_remoteSynchronizationState" : "_remote_synchronization_state"
                        ) | .unwrap + .named("synchronizationStateValue")
                    ) : nil)
                )
            }
        }()

        let wrappedIdentifierParameter: [TupleParameter] = {
            guard let identifierValue = identifierValue else { return [] }
            return [TupleParameter(name: "identifier", value: identifierValue)]
        }()
        
        let lastRemoteReadParameter = entity.lastRemoteRead ? [
            TupleParameter(
                name: "lastRemoteRead",
                value: entity.mutable ?
                    .named("coreDataEntity") + .named("dateValue") | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "propertyName", value: Value.string(useCoreDataLegacyNaming ? "__lastRemoteRead" : "__last_remote_read")))
                    ) :
                    .try | .named("coreDataEntity") + .named(useCoreDataLegacyNaming ? "__lastRemoteRead" : "__last_remote_read") + .named("dateValue") | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "propertyName", value: Value.string(useCoreDataLegacyNaming ? "__lastRemoteRead" : "__last_remote_read")))
                    )
            )
        ] : []
        
        let propertyParameters = try wrappedIdentifierParameter + lastRemoteReadParameter + entity.valuesThenRelationships.map { property in
            let coreDataPropertyName = "_\(property.coreDataName(useCoreDataLegacyNaming: useCoreDataLegacyNaming))"
            let propertyValueTypeID = try property.valueTypeID(descriptions)

            if let relationship = property.relationship, property.isArray == false {
                let relationshipEntity = try descriptions.entity(for: relationship.entityName)

                let relationshipValueReference: Reference = {
                    return .named("coreDataEntity") + .named("identifierValueType") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: relationshipEntity.identifierTypeID().reference + .named(.`self`)))
                        .adding(parameter: TupleParameter(name: "identifierTypeID", value: .named("coreDataEntity") + .named("_\(coreDataPropertyName)\(useCoreDataLegacyNaming ? "TypeUID" : "_type_uid")")))
                        .adding(parameter: TupleParameter(name: "propertyName", value: Value.string(coreDataPropertyName)))
                    )
                }()

                if property.lazy {
                    return TupleParameter(
                        name: property.transformedName(),
                        value: (propertyValueTypeID.isOptional && property.lazy == false ? .none : .try) |
                            .named("Lazy") | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "value", value: relationshipValueReference))
                                .adding(parameter: TupleParameter(
                                    name: "requested",
                                    value: Reference.named("coreDataEntity") + .named("boolValue") | .call(Tuple()
                                        .adding(parameter: TupleParameter(
                                            name: "propertyName",
                                            value: Value.string("_\(coreDataPropertyName)\(useCoreDataLegacyNaming ? "ExtraFlag" : "_lazy_flag")")
                                        ))
                                    )
                                ))
                            )
                    )
                } else {
                    return TupleParameter(
                        name: property.transformedName(),
                        value: (propertyValueTypeID.isOptionalOrLazy ? .none : .try) | relationshipValueReference
                    )
                }
            } else {
                let isStoredAsOptional = try property.propertyType.isStoredAsOptional(descriptions)
                let coreDataValueReference = Reference.named(
                    "\(coreDataValueAccessorName(for: property.propertyType))Value".variableCased()
                )

                let isOptional = propertyValueTypeID.isOptionalOrLazy == false && isStoredAsOptional
                let shouldTry = isOptional || property.lazy
                let shouldUsePropertyDirectly = propertyValueTypeID.isOptionalOrLazy == false || isStoredAsOptional
                let shouldPassPropertyName = isOptional || shouldUsePropertyDirectly == false

                let propertyValueReference: Reference = {
                    return .named("coreDataEntity") + (shouldUsePropertyDirectly ? .named(coreDataPropertyName) + .none : .none) |
                        coreDataValueReference |
                        .call(Tuple()
                            .adding(parameter: shouldPassPropertyName ? TupleParameter(name: "propertyName", value: Value.string(coreDataPropertyName)) : nil)
                        )
                }()

                let tryValue: Reference = (shouldTry ? .try : .none)

                if property.lazy {
                    return TupleParameter(
                        name: property.transformedName(),
                        value: tryValue |
                            .named("Lazy") | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "value", value: propertyValueReference))
                                .adding(parameter: TupleParameter(name: "requested", value:
                                    Reference.named("coreDataEntity") + .named("boolValue") |
                                        .call(Tuple()
                                            .adding(parameter: TupleParameter(name: "propertyName", value: Value.string("_\(coreDataPropertyName)\(useCoreDataLegacyNaming ? "ExtraFlag" : "_lazy_flag")")))
                                    )
                                ))
                        )
                    )
                } else {
                    return TupleParameter(
                        name: property.transformedName(),
                        value: tryValue | propertyValueReference
                    )
                }
            }
        }
        
        let shouldThrows = propertyParameters
            .compactMap { $0.value as? Reference }
            .flatMap { $0.array }
            .contains { $0.isTry || $0.isThrow }

        return Function(kind: .`init`(convenience: true))
            .with(accessLevel: .private)
            .with(throws: shouldThrows)
            .adding(parameter: FunctionParameter(name: "coreDataEntity", type: try entity.coreDataEntityTypeID()))
            .adding(member: Reference.named(.`self`) + .named("init") | .call(Tuple()
                .with(parameters: propertyParameters)
            ))
    }
    
    private func coreDataValueAccessorName(for propertyType: EntityProperty.PropertyType) -> String {
        switch propertyType {
        case .scalar(let value):
            return value.rawValue
        case .array(let value):
            return"\(coreDataValueAccessorName(for: value))Array"
        case .relationship(let value) where value.association == .toMany:
            return "\(value.entityName.camelCased())Array"
        case .relationship(let value):
            return value.entityName.camelCased()
        case .subtype(let value):
            return value.camelCased()
        }
    }
    
    private func coreDataConversionUtils() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.hasVoidIdentifier == false else { return [] }

        let identifierValueTypeID = try entity.identifierValueTypeID(descriptions)
        let arrayFunctionName = "\(entity.name.camelCased().variableCased())ArrayValue"
        
        return [
            EmptyLine(),
            Comment.mark("Cross Entities CoreData Conversion Utils"),
            EmptyLine(),
            Extension(type: .data)
                .adding(member: Function(kind: .named(arrayFunctionName))
                    .with(resultType: .optional(wrapped: .anySequence(element: entity.identifierTypeID())))
                    .adding(member:
                        Guard(assignment: Assignment(
                            variable: Variable(name: "values").with(type: .anySequence(element: identifierValueTypeID)),
                            value: .named("identifierValueTypeArrayValue") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: entity.identifierTypeID().reference + .named(.`self`)))
                            )
                        )).adding(member: Return(value: Value.nil))
                    )
                    .adding(member: Return(value: Reference.named("values") + .named("lazy") + .named(.map) | .block(FunctionBody()
                        .adding(member: entity.identifierTypeID().reference | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "value", value: Reference.named("$0")))
                        ))
                    ) + .named("any")))
            ),
            EmptyLine(),
            Extension(type: TypeIdentifier(name: .optional))
                .adding(constraint: .named("Wrapped") == TypeIdentifier.data.reference)
                .adding(member: Function(kind: .named(arrayFunctionName))
                    .with(throws: true)
                    .adding(parameter: FunctionParameter(name: "propertyName", type: .string))
                    .with(resultType: .anySequence(element: entity.identifierTypeID()))
                    .adding(member: Guard(assignment: Assignment(
                        variable: Variable(name: "values"),
                        value: .named(.`self`) | .unwrap + .named(arrayFunctionName) | .call()
                    ))
                        .adding(member: .throw | TypeIdentifier.coreDataConversionError.reference + .named("corruptedProperty") | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "name", value: Reference.named("propertyName")))
                        ))
                    )
                    .adding(member: Return(value: Reference.named("values")))
                )
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .named(arrayFunctionName))
                    .with(resultType: .optional(wrapped: .anySequence(element: entity.identifierTypeID())))
                    .adding(member: Return(value: .named(.`self`) | .unwrap + .named(arrayFunctionName) | .call()))
                )
        ]
    }

    // MARK: - Merging Extension

    private func entityMergingFunction() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)

        return [
            EmptyLine(),
            Comment.mark("Entity Merging"),
            EmptyLine(),
            Extension(type: entity.typeID())
                .adding(member: Function(kind: .named("merging"))
                    .with(accessLevel: .public)
                    .with(parameters: [
                        FunctionParameter(alias: "_", name: "updated", type: entity.typeID())
                    ])
                    .with(resultType: entity.typeID())
                    .with(body: try entityMergingFunctionBodyMembers(entity))
            )
        ]
    }

    private func entityMergingFunctionBodyMembers(_ entity: Entity) throws -> [FunctionBodyMember] {
        if entity.hasLazyProperties {
            return [
                Return(value:
                    entity.typeID().reference | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "identifier", value: Reference.named("updated") + .named("identifier")))
                        .adding(parameters: entity.valuesThenRelationships.map { property in
                            property.lazy ?
                                TupleParameter(name: property.transformedName(), value: Reference.named(property.transformedName()) + .named("merging") | .call(Tuple()
                                    .adding(parameter: TupleParameter(name: "with", value: Reference.named("updated") + .named(property.transformedName())))
                                )) :
                                TupleParameter(name: property.transformedName(), value: Reference.named("updated") + .named(property.transformedName()))
                        })
                    )
                )
            ]
        } else {
            return [
                Return(value: Reference.named("updated"))
            ]
        }
    }
}
