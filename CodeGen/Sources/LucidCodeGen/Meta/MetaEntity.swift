//
//  MetaEntity.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/20/19.
//

import Meta

struct MetaEntity {
    
    let entityName: String
    
    let descriptions: Descriptions
    
    let appVersion: String
    
    func imports() throws -> [Import] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.persist else { return [] }
        return [Import(name: "CoreData")]
    }
    
    func meta() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)

        return try [
            [
                Comment.mark(entity.name),
                EmptyLine(),
                try entityType()
            ],
            payloadInitializer(),
            [
                EmptyLine(),
                Comment.mark("\(entity.remote ? "Remote" : "")Entity"),
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
                        .with(immutable: entity.mutable == false)
                        .with(type: entity.identifierTypeID()))
                        .with(accessLevel: .public),
                    EmptyLine(),
                ],
                try lastRemoteReadProperty(),
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
                Property(variable: Variable(name: property.name)
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
                .with(type: .date))
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
            .adding(parameter: entity.lastRemoteRead ? FunctionParameter(name: "lastRemoteRead", type: .date) : nil)
            .adding(parameters: try entity.valuesThenRelationships.map { property in
                FunctionParameter(name: property.name, type: try property.valueTypeID(descriptions))
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
            return TupleParameter(name: property.name, value: Reference.named("payload") + Reference.named(property.payloadName))
        case .relationship(let relationship):
            let relationshipEntity = try descriptions.entity(for: relationship.entityName)
            switch relationship.association {
            case .toOne where relationshipEntity.identifier.isRelationship:
                let value: Reference
                if property.extra {
                    value = Reference.named("payload") +
                        .named(property.payloadName) +
                        .named("identifier") | .call(Tuple()
                            .adding(parameter:  TupleParameter(name: "from", value: .named("payload") + .named("identifier") + relationshipEntity.identifierVariable.reference))
                        )
                } else if property.optional {
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
                return TupleParameter(name: property.name, value: value)

            case .toOne:
                let value: Reference
                if property.extra {
                    value = Reference.named("payload") +
                        .named(property.payloadName) +
                        .named("identifier") | .call()
                } else {
                    value = Reference.named("payload") +
                        .named(property.payloadName) |
                        (property.optional ? .unwrap : .none) +
                        .named("identifier")
                }
                return TupleParameter(name: property.name, value: value)

            case .toMany:
                let value: Reference
                if property.extra {
                    value = Reference.named("payload") +
                        .named(property.payloadName) +
                        .named("identifiers") | .call()
                } else {
                    value = Reference.named("payload") +
                        .named(property.payloadName) |
                        (property.optional ? .unwrap : .none) +
                        .named("lazy") +
                        .named(.map) |
                        .block(FunctionBody()
                            .adding(member: Reference.named("$0") + .named("identifier"))
                        ) + .named("any")
                }
                return TupleParameter(name: property.name, value: value)
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
                                name: property.name,
                                type: try property.valueTypeID(descriptions)
                            ).with(defaultValue: property.defaultValue?.variableValue)
                        }
                    )
                    .with(resultType: entity.typeID())
                    .adding(member: EmptyLine())
                    .adding(member:
                        Return(value: entity.typeID().reference | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "identifier", value: .named(.`self`) + .named("identifier")))
                            .adding(parameter: entity.lastRemoteRead ? TupleParameter(name: "lastRemoteRead", value: +.named("distantPast")) : nil)
                            .adding(parameters: entity.valuesThenRelationships.map { property in
                                TupleParameter(
                                    name: property.name,
                                    value: property.mutable ? .named(property.name) : .named(.`self`) + .named(property.name)
                                )
                            })
                        ))
                    )
                )
        ]
    }

    // MARK: - Entity / RemoteEntity Extension
    
    private func remoteEntityExtension() throws -> Extension {
        let entity = try descriptions.entity(for: entityName)
        return Extension(type: entity.typeID())
            .adding(inheritedType: entity.remote ? .remoteEntity : .entity)
            .adding(members: try extrasTypeAlias(entity))
            .adding(member: EmptyLine())
            .adding(member: try indexValueFunction())
            .adding(member: EmptyLine())
            .adding(member: try entityRelationshipIndicesProperty())
            .adding(member: EmptyLine())
            .adding(member: try entityRelationshipEntityTypeUIDsProperty())
            .adding(member: EmptyLine())
            .adding(member: try equalityFunction())
    }

    private func extrasTypeAlias(_ entity: Entity) throws -> [TypeBodyMember] {
        guard entity.remote else { return [] }
        return [
            EmptyLine(),
            TypeAlias(
                identifier: TypeAliasIdentifier(name: "ExtrasIndexName"),
                value: try entity.extrasIndexNameTypeID(descriptions)
            ).with(accessLevel: .public)
        ]
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
                        .adding(parameter: TupleParameter(value: +.named(name.variableCased) | .call(Tuple()
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
                
                if try property.valueTypeID(descriptions).isOptionalOrExtra {
                    return SwitchCase(name: property.name)
                        .adding(member: Return(value: (property.entityReferenceValue + .named("flatMap") | .block(FunctionBody()
                            .adding(parameter: FunctionBodyParameter(name: property.name))
                            .adding(member: +.named("optional") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: returnReference))
                            ))) ?? +.named("none")
                        )))
                } else {
                    return SwitchCase(name: property.name).adding(member: Return(value: returnReference))
                }
            }
        
        return Function(kind: .named("entityIndexValue"))
            .with(accessLevel: .public)
            .adding(parameter: FunctionParameter(alias: "for", name: "indexName", type: entity.indexNameTypeID))
            .with(resultType: .entityIndexValue)
            .adding(member: Switch(reference: .named("indexName"))
                .with(cases: cases)
                .adding(case: entity.lastRemoteRead ?
                    SwitchCase(name: "lastRemoteRead").adding(member: Return(value: +.named("date") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Reference.named("lastRemoteRead")))
                    ))) : nil
                )
            )
    }
    
    private func entityRelationshipIndicesProperty() throws -> ComputedProperty {
        let entity = try descriptions.entity(for: entityName)
        
        return ComputedProperty(variable: Variable(name: "entityRelationshipIndices")
            .with(type: .array(element: entity.indexNameTypeID)))
            .with(accessLevel: .public)
            .adding(member: Return(value: Value.array(try entity.indexes(descriptions).compactMap { property in
                switch property.propertyType {
                case .relationship,
                     .array(.relationship):
                    return .reference(+.named(property.name))
                case .scalar,
                     .subtype,
                     .array:
                    return nil
                }
            })))
    }
    
    private func entityRelationshipEntityTypeUIDsProperty() throws -> ComputedProperty {
        let entity = try descriptions.entity(for: entityName)
        
        return ComputedProperty(variable: Variable(name: "entityRelationshipEntityTypeUIDs")
            .with(type: .array(element: .string)))
            .with(accessLevel: .public)
            .adding(member: Return(value: Value.array(try entity.indexes(descriptions).compactMap { property in
                switch property.propertyType {
                case .relationship(let entityRelationship),
                     .array(.relationship(let entityRelationship)):
                    return .reference(try entityRelationship.identifierTypeID(descriptions).arrayElementOrSelf.reference + .named("entityTypeUID"))
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

    // MARK: - CoreData Extensions
    
    private func coreDataExtensions() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.persist else { return [] }
        
        return [
            EmptyLine(),
            Comment.mark("CoreDataIndexName"),
            EmptyLine(),
            try coreDataIndexNameExtension(),
            EmptyLine(),
            Comment.mark("CoreDataEntity"),
            EmptyLine(),
            try coreDataEntityExtension()
        ]
    }
    
    private func coreDataIndexNameExtension() throws -> Extension {
        let entity = try descriptions.entity(for: entityName)

        return Extension(type: entity.indexNameTypeID)
            .adding(inheritedType: .coreDataIndexName)
            .adding(member: EmptyLine())
            .adding(member: ComputedProperty(variable: Variable(name: "predicateString")
                .with(type: .string))
                .with(accessLevel: .public)
                .adding(member: Switch(reference: .named(.`self`))
                    .with(cases: try entity.indexes(descriptions).map { property in
                        SwitchCase(name: property.name)
                            .adding(member: Return(value: Value.string("_\(property.name)")))
                    })
                    .adding(case: entity.lastRemoteRead ?
                        SwitchCase(name: "lastRemoteRead")
                            .adding(member: Return(value: Value.string("__lastRemoteRead"))) : nil
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
                        return SwitchCase(name: property.name)
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
                        SwitchCase(name: property.name)
                            .adding(member: Return(value: property.relationship?.association == .toOne ? Value.string("__\(property.name)TypeUID") : Value.nil))
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
                    .adding(parameter: TupleParameter(value: Value.string("\\(\(entity.name).self): \\(error)")))
                    .adding(parameter: TupleParameter(name: "assert", value: Value.bool(true)))
                ))
                .adding(member: Return(value: Value.nil))
            )
        }
        
        return Function(kind: .named("entity"))
            .with(accessLevel: .public)
            .with(static: true)
            .adding(parameter: FunctionParameter(alias: "from", name: "coreDataEntity", type: try entity.coreDataEntityTypeID(appVersion: appVersion)))
            .with(resultType: .optional(wrapped: entity.typeID()))
            .adding(member: body)
    }
    
    private func mergeInCoreDataEntityFunction() throws -> Function {
        let entity = try descriptions.entity(for: entityName)

        let coreDataEntity = Reference.named("coreDataEntity")
        let coreDataValue = Reference.named("coreDataValue") | .call()
        
        return Function(kind: .named("merge"))
            .with(accessLevel: .public)
            .adding(parameter: FunctionParameter(alias: "into", name: "coreDataEntity", type: try entity.coreDataEntityTypeID(appVersion: appVersion)))
            .adding(member: coreDataEntity + .named("setProperty") | .call(Tuple()
                .adding(parameter: TupleParameter(value: entity.identifierTypeID().reference + .named("remotePredicateString")))
                .adding(parameter: TupleParameter(name: "value", value: .named("identifier") + .named("remoteCoreDataValue") | .call()))
            ))
            .adding(member: coreDataEntity + .named("setProperty") | .call(Tuple()
                .adding(parameter: TupleParameter(value: entity.identifierTypeID().reference + .named("localPredicateString")))
                .adding(parameter: TupleParameter(name: "value", value: .named("identifier") + .named("localCoreDataValue") | .call()))
            ))
            .adding(member: Assignment(
                variable: coreDataEntity + .named("__typeUID"),
                value: .named("identifier") + .named("identifierTypeID")
            ))
            .adding(member: entity.remote ?
                Assignment(variable: coreDataEntity + .named("_remoteSynchronizationState"), value: .named("identifier") + .named("_remoteSynchronizationState") + .named("value") + coreDataValue)
                : nil
            )
            .adding(member: entity.lastRemoteRead ?
                Assignment(variable: coreDataEntity + .named("__lastRemoteRead"), value: Reference.named("lastRemoteRead")) : nil
            )
            .adding(members: try entity.valuesThenRelationships.flatMap { property -> [FunctionBodyMember] in
                let coreDataPropertyName = "_\(property.name)"
                let extraFlagBodyMember: FunctionBodyMember = {
                    guard property.extra else { return Reference.none }
                    return coreDataEntity + .named("setProperty") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Value.string("_\(coreDataPropertyName)ExtraFlag")))
                        .adding(parameter: TupleParameter(name: "value", value: property.reference + Reference.named("coreDataFlagValue")))
                    )
                }()

                if property.isRelationship && property.isArray == false {
                    let remoteProperty: FunctionBodyMember
                    let isStoredAsOptional = try property.propertyType.isStoredAsOptional(descriptions)
                    if isStoredAsOptional == false {
                        remoteProperty = coreDataEntity + .named("setProperty") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Value.string("_\(property.name)")))
                            .adding(parameter: TupleParameter(name: "value", value: property.entityReference |
                                (property.extra == false && property.optional ? .unwrap : .none) |
                                (property.extra ? .none + .named("extraValue") | .call() : .none) +
                                .named("remoteCoreDataValue") |
                                .call()))
                        )
                    } else {
                        remoteProperty = Assignment(variable: coreDataEntity + .named("_\(property.name)"),
                                                    value: property.entityReference |
                                                        (property.extra ? .none + .named("extraValue") | .call() : .none) +
                                                        .named("remoteCoreDataValue") | .call())
                    }

                    let localProperty = Assignment(variable: coreDataEntity + .named("__\(property.name)"),
                                                   value: property.entityReference |
                                                    (property.extra ? .none + .named("extraValue") | .call() : .none) +
                                                    .named("localCoreDataValue") | .call())
                    
                    let propertyTypeID = try property.valueTypeID(descriptions)
                    let identifierTypeIDProperty = Assignment(variable: coreDataEntity + .named("__\(property.name)TypeUID"),
                                                              value: property.entityReference |
                                                                (property.extra ? .none + .named("extraValue") | .call() : .none) |
                                                                (propertyTypeID.isOptionalOrExtra ? .unwrap : .none) +
                                                                .named("identifierTypeID"))
                    
                    return [
                        remoteProperty,
                        localProperty,
                        identifierTypeIDProperty,
                        extraFlagBodyMember
                    ]
                } else {
                    let isStoredAsOptional = try property.propertyType.isStoredAsOptional(descriptions)
                    let propertyValueTypeID = try property.valueTypeID(descriptions)

                    let bodyMember: FunctionBodyMember = {
                        if propertyValueTypeID.isOptionalOrExtra && isStoredAsOptional == false {
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
                        extraFlagBodyMember
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
                        value: .named("coreDataEntity") + .named("__typeUID")
                    ))
                    .adding(parameter: entity.remote ? TupleParameter(
                        name: "remoteSynchronizationState",
                        value: .named("coreDataEntity") + .named("_remoteSynchronizationState") | .unwrap + .named("synchronizationStateValue")
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
                value: .try | .named("coreDataEntity") + .named("__lastRemoteRead") + .named("dateValue") | .call(Tuple()
                    .adding(parameter: TupleParameter(name: "propertyName", value: Value.string("__lastRemoteRead")))
                )
            )
        ] : []
        
        let propertyParameters = try wrappedIdentifierParameter + lastRemoteReadParameter + entity.valuesThenRelationships.map { property in
            let coreDataPropertyName = "_\(property.name)"
            let propertyValueTypeID = try property.valueTypeID(descriptions)

            if let relationship = property.relationship, property.isArray == false {
                let relationshipEntity = try descriptions.entity(for: relationship.entityName)

                let relationshipValueReference: Reference = {
                    return .named("coreDataEntity") + .named("identifierValueType") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: relationshipEntity.identifierTypeID().reference + .named(.`self`)))
                        .adding(parameter: TupleParameter(name: "identifierTypeID", value: .named("coreDataEntity") + .named("__\(property.name)TypeUID")))
                        .adding(parameter: TupleParameter(name: "propertyName", value: Value.string("_\(property.name)")))
                    )
                }()

                if property.extra {
                    return TupleParameter(
                        name: property.name,
                        value: (propertyValueTypeID.isOptional && property.extra == false ? .none : .try) |
                            .named("Extra") | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "value", value: relationshipValueReference))
                                .adding(parameter: TupleParameter(name: "requested", value:
                                    Reference.named("coreDataEntity") + .named("boolValue") |
                                        .call(Tuple()
                                            .adding(parameter: TupleParameter(name: "propertyName", value: Value.string("_\(coreDataPropertyName)ExtraFlag")))
                                    )
                                ))
                            )
                    )
                } else {
                    return TupleParameter(
                        name: property.name,
                        value: (propertyValueTypeID.isOptionalOrExtra ? .none : .try) | relationshipValueReference
                    )
                }
            } else {
                let isStoredAsOptional = try property.propertyType.isStoredAsOptional(descriptions)
                let coreDataValueReference = Reference.named(
                    "\(coreDataValueAccessorName(for: property.propertyType).variableCased)Value"
                )

                let isOptional = propertyValueTypeID.isOptionalOrExtra == false && isStoredAsOptional
                let shouldTry = isOptional || property.extra
                let shouldUsePropertyDirectly = propertyValueTypeID.isOptionalOrExtra == false || isStoredAsOptional
                let shouldPassPropertyName = isOptional || shouldUsePropertyDirectly == false

                let propertyValueReference: Reference = {
                    return .named("coreDataEntity") + (shouldUsePropertyDirectly ? property.privateReference + .none : .none) |
                        coreDataValueReference |
                        .call(Tuple()
                            .adding(parameter: shouldPassPropertyName ? TupleParameter(name: "propertyName", value: Value.string("_\(property.name)")) : nil)
                        )
                }()

                let tryValue: Reference = (shouldTry ? .try : .none)

                if property.extra {
                    return TupleParameter(
                        name: property.name,
                        value: tryValue |
                            .named("Extra") | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "value", value: propertyValueReference))
                                .adding(parameter: TupleParameter(name: "requested", value:
                                    Reference.named("coreDataEntity") + .named("boolValue") |
                                        .call(Tuple()
                                            .adding(parameter: TupleParameter(name: "propertyName", value: Value.string("_\(coreDataPropertyName)ExtraFlag")))
                                    )
                                ))
                        )
                    )
                } else {
                    return TupleParameter(
                        name: property.name,
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
            .adding(parameter: FunctionParameter(name: "coreDataEntity", type: try entity.coreDataEntityTypeID(appVersion: appVersion)))
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
            return "\(value.entityName)Array"
        case .relationship(let value):
            return value.entityName
        case .subtype(let value):
            return value
        }
    }
    
    private func coreDataConversionUtils() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.hasVoidIdentifier == false else { return [] }

        let identifierValueTypeID = try entity.identifierValueTypeID(descriptions)
        let arrayFunctionName = "\(entity.name.variableCased)ArrayValue"
        
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
        if entity.hasPropertyExtras {
            return [
                Return(value:
                    entity.typeID().reference | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "identifier", value: Reference.named("updated") + .named("identifier")))
                        .adding(parameters: entity.valuesThenRelationships.map { property in
                            property.extra ?
                                TupleParameter(name: property.name, value: Reference.named(property.name) + .named("merging") | .call(Tuple()
                                    .adding(parameter: TupleParameter(name: "with", value: Reference.named("updated") + .named(property.name)))
                                )) :
                                TupleParameter(name: property.name, value: Reference.named("updated") + .named(property.name))
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
