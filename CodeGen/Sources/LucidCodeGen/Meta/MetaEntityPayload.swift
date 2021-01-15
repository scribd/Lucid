//
//  MetaEntityPayload.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/22/19.
//

import Meta
import LucidCodeGenCore

struct MetaEntityPayload {
    
    let entityName: String
    
    let descriptions: Descriptions
    
    func meta() throws -> [FileBodyMember] {
        return [
            [try entityPayload()],
            try identifiable(),
            try metadata(),
            try defaultEndpointPayload(),
            try relationshipsForIdentifierDerivationAccessors()
        ].flatMap { $0 }
    }
    
    // MARK: - Entity Payload
    
    private func entityPayload() throws -> Type {
        let entity = try descriptions.entity(for: entityName)
        return Type(identifier: entity.payloadTypeID)
            .with(kind: .class(final: true))
            .adding(inheritedType: .arrayConvertable)
            .adding(members: try identifier())
            .adding(members: entity.values.isEmpty ? [] : [EmptyLine(), Comment.comment("properties")])
            .adding(members: try properties(for: entity.values))
            .adding(members: entity.relationships.isEmpty ? [] : [EmptyLine(), Comment.comment("relationships")])
            .adding(members: try properties(for: entity.relationships))
            .adding(member: EmptyLine())
            .adding(member: try initializer())
    }
    
    private func identifier() throws -> [TypeBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        if let identifierTypeID = entity.payloadIdentifierTypeID {
            return [
                EmptyLine(),
                Comment.comment("identifier"),
                Property(variable: try entity.identifier.payloadVariable()
                    .with(type: identifierTypeID)
                )
            ]
        } else {
            return []
        }
    }
    
    private func properties(for properties: [EntityProperty]) throws -> [TypeBodyMember] {
        return try properties.map { property in
            return Property(variable: Variable(name: property.payloadName)
                .with(type: try property.payloadValueTypeID(descriptions))
            )
        }
    }
    
    private func initializer() throws -> Function {
        let entity = try descriptions.entity(for: entityName)
        return Function(kind: .`init`)
            .adding(parameters: entity.payloadIdentifierTypeID.flatMap { [FunctionParameter(name: "id", type: $0)] } ?? [])
            .adding(parameters: try entity.valuesThenRelationships.map { property in
                return FunctionParameter(name: property.payloadName, type: try property.payloadValueTypeID(descriptions))
            })
            .adding(member: EmptyLine())
            .adding(members: entity.payloadIdentifierTypeID.flatMap { _ in
                [Assignment(variable: .named(.`self`) + .named("id"), value: Reference.named("id"))]
            } ?? [])
            .adding(members: entity.valuesThenRelationships.map { property in
                Assignment(
                    variable: .named(.`self`) + .named(property.payloadName.variableCased(ignoreLexicon: true)),
                    value: Reference.named(property.payloadName.variableCased(ignoreLexicon: true))
                )
            })
    }
    
    private func identifiable() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.identifier.isRelationship == false && entity.hasVoidIdentifier == false else {
            return []
        }

        return [
            EmptyLine(),
            Extension(type: entity.payloadTypeID)
                .adding(inheritedType: .payloadIdentifierDecodableKeyProvider)
                .adding(member: EmptyLine())
                .adding(member: Property(variable: Variable(name: "identifierKey")
                    .with(immutable: true)
                    .with(static: true)
                ).with(value: Value.string(try entity.identifier.payloadVariable().name)))
                .adding(member: ComputedProperty(variable:
                    Variable(name: "identifier")
                        .with(immutable: false)
                        .with(type: entity.identifierTypeID())
                ).adding(member: Return(value: entity.identifierTypeID().reference | .call(Tuple()
                    .adding(parameter: TupleParameter(name: "value", value: try entity.payloadIdentifierReference()))
                ))))
        ]
    }
    
    private func metadata() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard try entity.hasVoidMetadata(descriptions) == false else { return [] }
        
        let properties = try metadataProperties()
        let codingKeys = try metadataCodingKeys()
        let decoding = try metadataDecoding()
        
        return try [
            EmptyLine(),
            Comment.mark("Metadata"),
            EmptyLine(),
            Type(identifier: entity.metadataTypeID)
                .with(kind: .class(final: true))
                .with(accessLevel: .public)
                .adding(inheritedType: .decodable)
                .adding(inheritedType: .entityMetadata)
                .adding(member: properties.isEmpty ? nil : EmptyLine())
                .adding(members: properties)
                .adding(member: codingKeys != nil ? EmptyLine() : nil)
                .adding(member: codingKeys)
                .adding(member: decoding != nil ? EmptyLine() : nil)
                .adding(member: decoding)
        ] + metadataIdentifier()
    }
    
    private func metadataDirectProperties(ignoreLexicon: Bool = false) throws -> [Property] {
        let entity = try descriptions.entity(for: entityName)
        return [
            entity.hasPayloadIdentifier ? [
                Property(variable: try entity.identifier.payloadVariable(ignoreLexicon: ignoreLexicon)
                    .with(type: try entity.remoteIdentifierValueTypeID(descriptions)))
                    .with(accessLevel: .public)
                ] : [],
            entity.metadata?.map { property in
                Property(variable: property.variable(ignoreLexicon: ignoreLexicon)
                    .with(type: property.typeID))
                    .with(accessLevel: .public)
                } ?? []
        ].flatMap { $0 }
    }
    
    private func metadataIndirectProperties() throws -> [Property] {
        let entity = try descriptions.entity(for: entityName)
        return try entity.relationships.compactMap { (property: EntityProperty) in
            guard let metadataTypeID = try property.metadataTypeID(descriptions) else { return nil }
            return Property(variable: property.variable
                .with(immutable: false)
                .with(type: metadataTypeID))
                .with(accessLevel: .composite(.public, .fileprivateSet))
                .with(value: metadataTypeID.isOptional ? Value.nil : metadataTypeID.reference | .call())
        }
    }
    
    private func metadataProperties() throws -> [Property] {
        return try metadataDirectProperties() + metadataIndirectProperties()
    }
    
    private func metadataIdentifier() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)

        guard let identifier = try entity.metadataIdentifierReference() else {
            return []
        }

        return [
            EmptyLine(),
            Extension(type: entity.metadataTypeID)
                .adding(inheritedType: .entityIdentifiable)
                .adding(member: EmptyLine())
                .adding(member: ComputedProperty(variable: Variable(name: "identifier")
                    .with(type: entity.identifierTypeID()))
                    .with(accessLevel: .public)
                    .adding(member: Return(value: entity.identifierTypeID().reference | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "value", value: identifier))
                    )))
                )
        ]
    }
    
    private func metadataCodingKeys() throws -> Type? {
        let metadataProperties = try self.metadataDirectProperties(ignoreLexicon: true)
        guard metadataProperties.isEmpty == false else { return nil }
        return Type(identifier: TypeIdentifier(name: "Keys"))
            .with(accessLevel: .private)
            .adding(inheritedType: .codingKey)
            .with(kind: .enum(indirect: false))
            .adding(members: metadataProperties.map { property in
                Case(name: property.variable.name)
            })
    }

    private func metadataDecoding() throws -> Function? {
        let metadataPropertyKeys = try self.metadataDirectProperties(ignoreLexicon: true)
        let metadataProperties = try self.metadataDirectProperties()
        guard metadataProperties.isEmpty == false else { return nil }

        return Function.initFromDecoder
            .with(accessLevel: .public)
            .adding(member: Assignment(
                variable: Variable(name: "container"),
                value: .try | .named("decoder") + .named("container") | .call(Tuple()
                    .adding(parameter: TupleParameter(name: "keyedBy", value: .named("Keys") + .named(.`self`)))
                ))
            )
            .adding(members: metadataProperties.enumerated().compactMap { index, property in
                guard let type = property.variable.type?.wrappedOrSelf else { return nil }
                let propertyKey = metadataPropertyKeys[index]
                return Assignment(
                    variable: Reference.named(property.variable.name),
                    value: .try | .named("container") + .named("decode") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: type.reference + .named(.`self`)))
                        .adding(parameter: TupleParameter(name: "forKey", value: +.named(propertyKey.variable.name)))
                        .adding(parameter: TupleParameter(name: "defaultValue", value: Value.nil))
                        .adding(parameter: TupleParameter(name: "logError", value: Value.bool(true)))
                    )
                )
            })
    }
    
    // MARK: - DefaultEndpointPayload
    
    private func defaultEndpointPayload() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        
        return try [
            EmptyLine(),
            Comment.mark("Default Endpoint Payload"),
            EmptyLine(),
            Type(identifier: entity.defaultEndpointPayloadTypeID)
                .adding(inheritedType: .decodable)
                .adding(inheritedType: .payloadConvertable)
                .adding(inheritedType: .arrayConvertable)
                .adding(member: EmptyLine())
                .adding(member: Property(variable: Variable(name: "rootPayload")
                    .with(type: entity.payloadTypeID))
                )
                .adding(member: Property(variable: Variable(name: "entityMetadata")
                    .with(type: .optional(wrapped: try entity.metadataTypeID(descriptions))))
                )
                .adding(member: EmptyLine())
                .adding(member: try defaultEndpointPayloadKeys())
                .adding(member: EmptyLine())
                .adding(member: try defaultEndpointPayloadDecoderInitializer())
        ] + defaultEndpointPayloadIdentifierDecodableKeyProvider()
    }
    
    private func defaultEndpointPayloadKeys() throws -> Type {
        let entity = try descriptions.entity(for: entityName)

        let identifierCase: [Case] = entity.identifier.payloadVariable(ignoreLexicon: true).flatMap {
            entity.payloadIdentifierTypeID != nil ? [Case(name: $0.name)] : []
        } ?? []

        let valueCases = entity.values
            .lazy
            .flatMap { $0.keysPathComponents }
            .flatMap { $0 }
            .map { Case(name: $0) }
        
        let relationshipCases = entity.usedProperties.flatMap { property -> [Case] in
            guard let relationship = property.relationship else { return [] }
            if relationship.idOnly && property.matchExactKey == false {
                return property.keysPathComponents.flatMap { keys in
                    keys.enumerated().map { index, key in
                        let isLastKey = index == keys.count - 1
                        switch relationship.association {
                        case .toMany where key.hasSuffix("Ids") == false && isLastKey:
                            return Case(name: key).with(value: Value.string("\(key)Ids"))
                        case .toOne where key.hasSuffix("Id") == false && isLastKey:
                            return Case(name: key).with(value: Value.string("\(key)Id"))
                        case .toOne,
                             .toMany:
                            return Case(name: key)
                        }
                    }
                }
            } else {
                return property.keysPathComponents.lazy.flatMap { $0 }.map { Case(name: $0) }
            }
        }
        
        return Type(identifier: TypeIdentifier(name: "Keys"))
            .with(accessLevel: .private)
            .with(kind: .enum(indirect: false))
            .adding(inheritedType: .string)
            .adding(inheritedType: .codingKey)
            .with(body: (identifierCase + valueCases + relationshipCases).removingDuplicates())
    }
    
    private func defaultEndpointPayloadDecoderInitializer() throws -> Function {
        let entity = try descriptions.entity(for: entityName)
        let hasVoidMetadata = try entity.hasVoidMetadata(descriptions)

        return Function.initFromDecoder
            .adding(member: Assignment(
                variable: Variable(name: "container"),
                value: .try | .named("decoder") + .named("container") | .call(Tuple()
                    .adding(parameter: TupleParameter(name: "keyedBy", value: .named("Keys") + .name(.`self`))
                ))
            ))
            .adding(member: Assignment(
                variable: Variable(name: "excludedProperties"),
                value: .named("decoder") + .named("excludedPropertiesAtCurrentPath")
            ))
            .adding(member: Assignment(
                variable: Variable(name: "rootPayload"),
                value: entity.payloadTypeID.reference | .call(Tuple()
                    .adding(parameter: try entity.payloadIdentifierTypeID.flatMap { _ in
                        TupleParameter(name: "id", value: .try |
                            .named("container") + .named("decode") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: try entity.remoteIdentifierValueTypeID(descriptions).reference + .named(.`self`)))
                                                                            .adding(parameter: TupleParameter(name: "forKey", value: try +entity.payloadIdentifierValueReference(ignoreLexicon: true)))
                                .adding(parameter: TupleParameter(name: "defaultValue", value: Value.nil))
                                .adding(parameter: TupleParameter(name: "excludedProperties", value: Reference.named("excludedProperties")))
                                .adding(parameter: TupleParameter(name: "logError", value: Value.bool(true)))
                            )
                        )
                    })
                    .adding(parameters: try entity.valuesThenRelationships.map { property in
                        let container = try defaultEndpointPayloadDecodingContainer(for: property)

                        switch property.propertyType {
                        case .subtype,
                             .scalar,
                             .array:
                            
                            let valueTypeID = try property.valueTypeID(descriptions, includeLazy: false).wrappedOrSelf
                            let value = .try | container.reference + .named(property.isArray ? "decodeSequence" : "decode") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: valueTypeID.reference + .named(.`self`)))
                                .adding(parameter: TupleParameter(name: "forKeys", value: Value.array(container.lastKeys.map { .reference(+.named($0)) })))
                                .adding(parameter: TupleParameter(name: "defaultValue", value: property.defaultValue?.variableValue ?? Value.nil))
                                .adding(parameter: TupleParameter(name: "excludedProperties", value: Reference.named("excludedProperties")))
                                .adding(parameter: TupleParameter(name: "logError", value: Value.bool(property.logError)))
                            )
                            return TupleParameter(name: property.transformedName(), value: value)
                            
                        case .relationship(let relationship):
                            let relationshipEntity = try descriptions.entity(for: relationship.entityName)

                            var decodableType: TypeIdentifier = relationship.idOnly ?
                                relationshipEntity.identifierTypeID() : relationshipEntity.defaultEndpointPayloadTypeID
                            if relationship.association == .toMany {
                                decodableType = .anySequence(element: decodableType)
                            }

                            let value = .try | container.reference + .named(property.isArray ? "decodeSequence" : "decode") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: decodableType.reference + .named(.`self`)))
                                .adding(parameter: TupleParameter(name: "forKeys", value: Value.array(container.lastKeys.map { .reference(+.named($0)) })))
                                .adding(parameter: TupleParameter(name: "excludedProperties", value: Reference.named("excludedProperties")))
                                .adding(parameter: TupleParameter(name: "logError", value: Value.bool(property.logError)))
                            )

                            return TupleParameter(name: property.payloadName, value: value)
                        }
                    })
                )
            ))
            .adding(member: Assignment(
                variable: Variable(name: "entityMetadata"),
                value: .try | TypeIdentifier.failableValue(of: try entity.metadataTypeID(descriptions)).reference | .call(Tuple()
                    .adding(parameter: TupleParameter(name: "from", value: Reference.named("decoder")))
                ) + .named("value") | .call()
            ))
            .adding(members: hasVoidMetadata == false ? try entity.relationships.compactMap { property in
                guard try property.metadataTypeID(descriptions) != nil else { return nil }

                if property.isArray {
                    return Assignment(
                        variable: .named("entityMetadata") | .unwrap + property.variable.reference,
                        value: .named("rootPayload")  + property.payloadName.reference |
                            (property.lazy ? .none + .lazyValue | .call() : .none ) +
                            .named("values") | .call()
                    )
                } else {
                    return Assignment(
                        variable: .named("entityMetadata") | .unwrap + property.variable.reference,
                        value: .named("rootPayload") + property.payloadName.reference |
                            (property.lazy ? .none + .lazyValue | .call() | .unwrap : .none ) |
                            (property.nullable ? .unwrap : .none) + .named("value") | .unwrap + .named("entityMetadata")
                    )
                }
            } : [])
            .adding(member: Assignment(variable: .named(.`self`) + .named("rootPayload"), value: Reference.named("rootPayload")))
            .adding(member: Assignment(variable: .named(.`self`) + .named("entityMetadata"), value: Reference.named("entityMetadata")))
    }
    
    private func defaultEndpointPayloadDecodingContainer(for property: EntityProperty) throws -> (reference: Reference, lastKeys: [String]) {
        
        return try property
            .keysPathComponents
            .reduce(into: (reference: Reference.none, lastKeys: [String]())) { container, keyPathComponents in
            
            if keyPathComponents.count <= 1 {
                container.reference = .named("container")
                container.lastKeys.append(keyPathComponents[0])
            } else {
                guard container.reference == .none else {
                    throw CodeGenError.incompatiblePropertyKey(property.key)
                }
                
                container.lastKeys.append(keyPathComponents[keyPathComponents.count - 1])
                
                var containerReference = .named("container") + .named("nestedContainer") | .call(Tuple()
                    .adding(parameter:TupleParameter(
                        name: "forKeyChain",
                        value: Reference.array(with: keyPathComponents.dropLast().map { +.named($0) }, ofType: TypeIdentifier(name: "Keys"))
                    ))
                )
                
                if property.nullable {
                    containerReference = .call(Tuple()
                        .adding(parameter: TupleParameter(value: .optionalTry | containerReference))
                    ) | .unwrap
                }
                
                container.reference = containerReference
            }
            
        }
    }
    
    private func defaultEndpointPayloadIdentifierDecodableKeyProvider() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)

        switch entity.identifier.identifierType {
        case .void,
             .relationships:
            return []
        case .scalarType,
             .property:
            return [
                EmptyLine(),
                Extension(type: entity.defaultEndpointPayloadTypeID)
                    .adding(inheritedType: .payloadIdentifierDecodableKeyProvider)
                    .adding(member: EmptyLine())
                    .adding(member: Property(variable: Variable(name: "identifierKey")
                        .with(static: true))
                        .with(value: entity.payloadTypeID.reference + .named("identifierKey"))
                    )
                    .adding(member: ComputedProperty(variable: Variable(name: "identifier")
                        .with(type: entity.identifierTypeID()))
                        .adding(member: Return(value: Reference.named("rootPayload") + .named("identifier"))))
            ]
        }
    }
    
    private func relationshipsForIdentifierDerivationAccessors() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)

        let extractablePropertyEntities = try entity.extractablePropertyEntities(descriptions)
        guard extractablePropertyEntities.isEmpty == false else { return [] }
        
        let relationshipsForIdentifierDerivation = entity.relationshipsForIdentifierDerivation
        
        return [
            EmptyLine(),
            Comment.mark("Relationship Entities Accessors"),
            EmptyLine(),
            Extension(type: entity.payloadTypeID)
                .adding(members: try extractablePropertyEntities.flatMap { relationshipEntity -> [TypeBodyMember] in
                    
                    let directRelationships = (relationshipsForIdentifierDerivation[relationshipEntity.name] ?? []).filter { property, relationship in
                        let isEmbedded = relationship.idOnly == false
                        return isEmbedded
                    }
                    
                    let directRelationshipVariables: [Assignment] = try directRelationships.map { property, relationship in
                        let relationshipEntity = try descriptions.entity(for: relationship.entityName)

                        return Assignment(
                            variable: Variable(name: property.payloadName),
                            value: .named(.`self`) + .named(property.payloadName) | (property.lazy ? .none + .lazyValue | .call() : .none) + .named("values") | .call() + .named("lazy") + .named(.map) | .block(FunctionBody()
                                .adding(member: relationshipEntity.typeID().reference | .call(Tuple()
                                    .adding(parameter: relationshipEntity.identifier.isRelationship ?
                                        TupleParameter(name: "identifier", value: .named(.`self`) + .named("identifier")) : nil
                                    )
                                    .adding(parameter: TupleParameter(name: "payload", value: .named("$0") + .named("rootPayload")))
                                ))
                            ) + .named("any")
                        )
                    }
                    
                    let indirectRelationships = try entity.properties.filter { property in
                        guard let relationship = property.relationship else { return false }
                        let isEmbedded = relationship.idOnly == false
                        let canExtractEntity = try descriptions.entity(for: relationship.entityName)
                            .extractablePropertyEntities(descriptions)
                            .contains { $0.name == relationshipEntity.name }
                        return isEmbedded && canExtractEntity
                    }
                    
                    let indirectRelationshipVariables: [Assignment] = indirectRelationships.map { property in
                        return Assignment(
                            variable: Variable(name: "_\(property.payloadName)"),
                            value: .named(.`self`) + .named(property.payloadName) | (property.lazy ? .none + .lazyValue | .call() : .none) + .named("values") | .call() + .named("lazy") + .named(.flatMap) | .block(FunctionBody()
                                .adding(member: .named("$0") + .named("rootPayload") + relationshipEntity.payloadEntityAccessorVariable.reference)
                            ) + .named("any")
                        )
                    }
                    
                    return [
                        ComputedProperty(variable: relationshipEntity.payloadEntityAccessorVariable
                            .with(type: .anySequence(element: relationshipEntity.typeID())))
                            .adding(members: directRelationshipVariables)
                            .adding(members: indirectRelationshipVariables)
                            .adding(member:
                                Return(value: directRelationships.isEmpty && indirectRelationships.isEmpty ?
                                    Reference.array() + .named("lazy") :
                                    Reference.array(with: (
                                        directRelationships.map { Reference.named($0.property.payloadName) } +
                                        indirectRelationships.map { Reference.named("_\($0.payloadName)") }
                                    )) + .named("joined") | .call() + .named("any")
                                )
                            )
                    ]
                })
        ]
    }
}

// MARK: - Utils

private extension Sequence where Element: Hashable {
    
    func removingDuplicates() -> [Element] {
        var uniqueItems = Set<Element>()
        return filter { uniqueItems.insert($0).inserted }
    }
}
