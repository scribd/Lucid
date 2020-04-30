//
//  MetaEntityIdentifier.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/27/19.
//

import Meta

struct MetaEntityIdentifier {
    
    let entityName: String
    
    let descriptions: Descriptions
    
    func imports() throws -> [String] {
        let entity = try descriptions.entity(for: entityName)
        return entity.persist ? ["CoreData"] : []
    }
    
    func meta() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.hasVoidIdentifier == false else { return [] }
        
        return try [
            Comment.mark("Identifier"),
            EmptyLine(),
            try identifierType(),
            EmptyLine(),
            Comment.mark("Identifiable"),
            EmptyLine(),
            try identifiableProtocol(),
            EmptyLine()
        ] + identifiableExtensions()
    }
    
    private let value = Variable(name: "value")
    
    // MARK: - Type
    
    private func identifierType() throws -> Type {
        let entity = try descriptions.entity(for: entityName)

        return Type(identifier: entity.identifierTypeID())
            .with(kind: .class(final: true))
            .with(accessLevel: .public)
            .adding(inheritedType: .coreDataIdentifier)
            .adding(inheritedType: entity.remote ? .remoteIdentifier : nil)
            .adding(inheritedType: entity.persist == false && entity.remote == false ? .rawIdentifiable : nil)
            .adding(member: EmptyLine())
            .adding(member: TypeAlias(
                identifier: TypeAliasIdentifier(name: TypeIdentifier.localValueType.name),
                value: .string
            ).with(accessLevel: .public))
            .adding(member: TypeAlias(
                identifier: TypeAliasIdentifier(name: TypeIdentifier.remoteValueType.name),
                value: try entity.remoteIdentifierValueTypeID(descriptions)
            ).with(accessLevel: .public))
            .adding(member: entity.remote ? EmptyLine() : nil)
            .adding(member: entity.remote ?
                Property(variable: Variable(name: "_remoteSynchronizationState")
                    .with(type: .propertyBox(of: .remoteSynchronizationState))
                ).with(accessLevel: .public) : nil
            )
            .adding(member: EmptyLine())
            .adding(member: Property(variable: Variable(name: "property")
                .with(type: .propertyBox(of: try entity.identifierValueTypeID(descriptions))))
                .with(accessLevel: .fileprivate)
            )
            .adding(member: ComputedProperty(variable: value.with(type: try entity.identifierValueTypeID(descriptions)))
                .with(accessLevel: .public)
                .adding(member: Return(value: .named("property") + .named("value")))
            )
            .adding(member: EmptyLine())
            .adding(member: entityTypeUIDProperty())
            .adding(member: identifierTypeIDProperty())
            .adding(member: EmptyLine())
            .adding(member: try initFromDecoder())
            .adding(member: EmptyLine())
            .adding(member: encodeFunction())
            .adding(member: EmptyLine())
            .adding(members: try initWithValue())
            .adding(member: EmptyLine())
            .adding(member: try equatableFunction())
            .adding(members: try dualHashableFunctions())
            .adding(member: EmptyLine())
            .adding(member: customStringRepresentableProperty())
    }
    
    // MARK: - Initializers
    
    private func initWithValue() throws -> [TypeBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        let identifierValueTypeID = try entity.identifierValueTypeID(descriptions)
        
        if entity.remote {
            return [
                Function(kind: .`init`(convenience: true))
                    .with(accessLevel: .public)
                    .adding(parameter: FunctionParameter(name: value.name, type: identifierValueTypeID))
                    .adding(parameter: FunctionParameter(name: "identifierTypeID", type: .optional(wrapped: .string)).with(defaultValue: Value.nil))
                    .adding(parameter: FunctionParameter(name: "remoteSynchronizationState", type: .optional(wrapped: .remoteSynchronizationState)).with(defaultValue: Value.nil))
                    .adding(member: Reference.named(.`self`) + .named(.`init`) | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "value", value: Reference.named("value")))
                        .adding(parameter: TupleParameter(name: "identifierTypeID", value: Reference.named("identifierTypeID")))
                        .adding(parameter: TupleParameter(name: "remoteSynchronizationState", value: .named("remoteSynchronizationState") ?? +.named("synced")))
                    )),
                EmptyLine(),
                Function(kind: .`init`)
                    .with(accessLevel: .public)
                    .adding(parameter: FunctionParameter(name: value.name, type: identifierValueTypeID))
                    .adding(parameter: FunctionParameter(name: "identifierTypeID", type: .optional(wrapped: .string)))
                    .adding(parameter: FunctionParameter(name: "remoteSynchronizationState", type: .remoteSynchronizationState))
                    .adding(members: [
                        Assignment(
                            variable: Reference.named("property"),
                            value: TypeIdentifier.propertyBox().reference | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Reference.named("value")))
                                .adding(parameter: TupleParameter(name: "atomic", value: Value.bool(entity.mutable)))
                            )),
                        Assignment(
                            variable: Reference.named(.`self`) + .named("identifierTypeID"),
                            value: Reference.named("identifierTypeID") ?? entity.typeID().reference + .named("identifierTypeID")
                        ),
                        Assignment(
                            variable: Reference.named(.`self`) + .named("_remoteSynchronizationState"),
                            value: TypeIdentifier.propertyBox().reference | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Reference.named("remoteSynchronizationState")))
                                .adding(parameter: TupleParameter(name: "atomic", value: Value.bool(entity.mutable)))
                            ))
                    ])
            ]
        } else {
            return [
                Function(kind: .`init`)
                    .with(accessLevel: .public)
                    .adding(parameter: FunctionParameter(name: value.name, type: identifierValueTypeID))
                    .adding(parameter: FunctionParameter(name: "identifierTypeID", type: .optional(wrapped: .string)).with(defaultValue: Value.nil))
                    .adding(parameter: FunctionParameter(name: "remoteSynchronizationState", type: .optional(wrapped: .remoteSynchronizationState)).with(defaultValue: Value.nil))
                    .adding(member: Assignment(
                        variable: Reference.named("property"),
                        value: TypeIdentifier.propertyBox().reference | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Reference.named("value")))
                            .adding(parameter: TupleParameter(name: "atomic", value: Value.bool(entity.mutable)))
                        )
                    ))
                    .adding(member: Assignment(
                        variable: Reference.named(.`self`) + .named("identifierTypeID"),
                        value: Reference.named("identifierTypeID") ?? entity.typeID().reference + .named("identifierTypeID")
                    ))
            ]
        }
    }

    // MARK: - Codable
    
    private func initFromDecoder() throws -> Function {
        let container = Variable(name: "container")
        let entity = try descriptions.entity(for: entityName)
        let identifierValueTypeID = try entity.identifierValueTypeID(descriptions)
        
        return Function.initFromDecoder
            .with(accessLevel: .public)
            .adding(member: entity.remote ? Assignment(
                variable: Reference.named("_remoteSynchronizationState"),
                value: TypeIdentifier.propertyBox().reference | .call(Tuple()
                    .adding(parameter: TupleParameter(value: +.named("synced")))
                    .adding(parameter: TupleParameter(name: "atomic", value: Value.bool(entity.mutable)))
                )
            ) : nil)
            .adding(member: Switch(reference: .named("decoder") + .named("context"))
                .adding(case: SwitchCase(name: .custom("payload, .clientQueueRequest"))
                    .adding(member: Assignment(
                        variable: container,
                        value: .try | .named("decoder") + .named("singleValueContainer") | .call()
                    ))
                    .adding(member: Assignment(
                        variable: Reference.named("property"),
                        value: TypeIdentifier.propertyBox().reference | .call(Tuple()
                            .adding(parameter: TupleParameter(value: .try | container.reference + .named("decode") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: .type(identifierValueTypeID) + .named(.`self`)))
                                )))
                            .adding(parameter: TupleParameter(name: "atomic", value: Value.bool(entity.mutable)))
                        )
                    ))
                    .adding(member: Assignment(
                        variable: Reference.named("identifierTypeID"),
                        value: entity.typeID().reference + .named("identifierTypeID")
                    ))
                )
                .adding(case: SwitchCase(name: "coreDataRelationship")
                    .adding(member: Assignment(
                        variable: container,
                        value: .try | .named("decoder") + .named("container") | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "keyedBy", value: TypeIdentifier.entityIdentifierCodingKeys.reference + .named(.`self`)))
                        )
                    ))
                    .adding(member: Assignment(
                        variable: Reference.named("property"),
                        value: TypeIdentifier.propertyBox().reference | .call(Tuple()
                            .adding(parameter: TupleParameter(value: .try | container.reference + .named("decode") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: .type(identifierValueTypeID) + .named(.`self`)))
                                .adding(parameter: TupleParameter(name: "forKey", value: +.named("value")))
                                )))
                            .adding(parameter: TupleParameter(name: "atomic", value: Value.bool(entity.mutable)))
                        )
                    ))
                    .adding(member: Assignment(
                        variable: Reference.named("identifierTypeID"),
                        value: .try | container.reference + .named("decode") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: TypeIdentifier.string.reference + .named(.`self`)))
                            .adding(parameter: TupleParameter(name: "forKey", value: +.named("identifierTypeID")))
                        )
                    ))
                )
            )
    }
    
    private func encodeFunction() -> Function {
        return Function.encode
            .with(accessLevel: .public)
            .adding(member: Switch(reference: .named("encoder") + .named("context"))
                .adding(case: SwitchCase(name: .custom("payload, .clientQueueRequest"))
                    .adding(member: Assignment(
                        variable: Variable(name: "container").with(immutable: false),
                        value: .named("encoder") + .named("singleValueContainer") | .call()
                    ))
                    .adding(member: .try | .named("container") + .named("encode") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: .named("property") + .named("value")))
                    ))
                )
                .adding(case: SwitchCase(name: "coreDataRelationship")
                    .adding(member: Assignment(
                        variable: Variable(name: "container").with(immutable: false),
                        value: .named("encoder") + .named("container") | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "keyedBy", value: TypeIdentifier.entityIdentifierCodingKeys.reference + .named(.`self`)))
                        )
                    ))
                    .adding(member: .try | .named("container") + .named("encode") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: .named("property") + .named("value")))
                        .adding(parameter: TupleParameter(name: "forKey", value: +.named("value")))
                        ))
                    .adding(member: .try | .named("container") + .named("encode") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Reference.named("identifierTypeID")))
                        .adding(parameter: TupleParameter(name: "forKey", value: +.named("identifierTypeID")))
                    ))
                )
            )
    }
    
    // MARK: - Equatable
    
    private func equatableFunction() throws -> Function {
        let entity = try descriptions.entity(for: entityName)

        return Function(kind: .operator(.equal))
            .with(static: true)
            .with(accessLevel: .public)
            .with(resultType: .bool)
            .adding(parameter: FunctionParameter(alias: "_", name: "lhs", type: entity.identifierTypeID()))
            .adding(parameter: FunctionParameter(alias: "_", name: "rhs", type: entity.identifierTypeID()))
            .adding(member: Return(value:
                .named("lhs") + .named("value") == .named("rhs") + .named("value") &&
                .named("lhs") + .named("identifierTypeID") == .named("rhs") + .named("identifierTypeID")
            ))
    }
    
    // MARK: - DualHashable
    
    private func dualHashableFunctions() throws -> [TypeBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        return [
            EmptyLine(),
            Function(kind: .named("hash"))
                .with(accessLevel: .public)
                .adding(parameter: FunctionParameter(alias: "into", name: "hasher", type: .dualHasher).with(`inout`: true))
                .adding(member: .named("hasher") + .named("combine") | .call(Tuple()
                    .adding(parameter: TupleParameter(value: Reference.named("value")))
                ))
                .adding(member: .named("hasher") + .named("combine") | .call(Tuple()
                    .adding(parameter: TupleParameter(value: Reference.named("identifierTypeID")))
                ))
        ] + (entity.mutable ? [
            EmptyLine(),
            Function(kind: .named("update"))
                .with(accessLevel: .public)
                .adding(parameter: FunctionParameter(alias: "with", name: "newValue", type: entity.identifierTypeID()))
                .adding(member: .named("property") + .named("value") + .named("merge") | .call(Tuple()
                    .adding(parameter: TupleParameter(name: "with", value: .named("newValue") + .named("value")))
                ))
        ] : [])
    }
    
    // MARK: - CustomStringRepresentable
    
    private func customStringRepresentableProperty() -> ComputedProperty {
        return ComputedProperty(variable: Variable(name: "description")
            .with(type: .string))
            .with(accessLevel: .public)
            .adding(member: Return(value: Value.string("\\(identifierTypeID):\\(value.description)")))
    }
    
    // MARK: - EntityTypeUID
    
    private func entityTypeUIDProperty() -> Property {
        return Property(variable: Variable(name: "entityTypeUID")
            .with(static: true))
            .with(accessLevel: .public)
            .with(value: Value.string(entityName.unversionedName.snakeCased))
    }
    
    // MARK: - IdentifierTypeID
    
    private func identifierTypeIDProperty() -> Property {
        return Property(variable: Variable(name: "identifierTypeID")
            .with(type: .string))
            .with(accessLevel: .public)
    }
    
    // MARK: - Identifiable
    
    private func identifiableProtocol() throws -> Type {
        let entity = try descriptions.entity(for: entityName)
        
        return Type(identifier: entity.identifiableTypeID)
            .with(kind: .protocol)
            .with(accessLevel: .public)
            .adding(member: ProtocolProperty(name: entity.identifierVariable.name, type: entity.identifierTypeID()))
    }
    
    private func identifiableExtensions() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        
        let selfExtension = Extension(type: entity.identifierTypeID())
            .adding(inheritedType: entity.identifiableTypeID)
            .adding(member:
                ComputedProperty(variable: entity.identifierVariable.with(type: entity.identifierTypeID()))
                    .with(accessLevel: .public)
                    .adding(member: Return(value: Reference.named(.`self`)))
        )
        
        let relationshipExtensions: [FileBodyMember] = try entity.identifier.relationshipIDs(entity, descriptions).flatMap { relationship -> [FileBodyMember] in
            let relationshipEntity = try descriptions.entity(for: relationship.entityName)
            
            return [
                EmptyLine(),
                Extension(type: relationshipEntity.identifierTypeID())
                    .adding(inheritedType: entity.identifiableTypeID)
                    .adding(member:
                        ComputedProperty(variable: entity.identifierVariable.with(type: entity.identifierTypeID()))
                            .with(accessLevel: .public)
                            .adding(member: Return(value:
                                entity.identifierTypeID().reference | .call(Tuple()
                                    .adding(parameter: TupleParameter(name: value.name, value: value.reference))
                                    .adding(parameter: TupleParameter(name: "identifierTypeID", value: Reference.named("identifierTypeID")))
                                )
                            ))
                ),
                EmptyLine(),
                Extension(type: entity.identifierTypeID())
                    .adding(inheritedType: relationshipEntity.identifiableTypeID)
                    .adding(member:
                        ComputedProperty(variable: relationshipEntity.identifierVariable.with(type: relationshipEntity.identifierTypeID()))
                            .with(accessLevel: .public)
                            .adding(member: Return(value:
                                relationshipEntity.identifierTypeID().reference | .call(Tuple()
                                    .adding(parameter: TupleParameter(name: value.name, value: value.reference))
                                    .adding(parameter: TupleParameter(name: "identifierTypeID", value: Reference.named("identifierTypeID")))
                                )
                            ))
                )
            ]
        }
        
        let equivalentExtensions: [FileBodyMember] = try entity.identifier.equivalentIdentifierName.flatMap { equivalentEntityName -> [FileBodyMember] in
            
            let equivalentEntity = try descriptions.entity(for: equivalentEntityName) 
            
            return [
                EmptyLine(),
                Extension(type: equivalentEntity.identifierTypeID())
                    .adding(inheritedType: entity.identifiableTypeID)
                    .adding(member:
                        ComputedProperty(variable: entity.identifierVariable.with(type: entity.identifierTypeID()))
                            .with(accessLevel: .public)
                            .adding(member: Return(value:
                                entity.identifierTypeID().reference | .call(Tuple()
                                    .adding(parameter: TupleParameter(name: value.name, value: value.reference))
                                    .adding(parameter: TupleParameter(name: "identifierTypeID", value: Reference.named("identifierTypeID")))
                                )
                            ))
                ),
                EmptyLine(),
                Extension(type: entity.identifierTypeID())
                    .adding(inheritedType: equivalentEntity.identifiableTypeID)
                    .adding(member:
                        ComputedProperty(variable: equivalentEntity.identifierVariable.with(type: equivalentEntity.identifierTypeID()))
                            .with(accessLevel: .public)
                            .adding(member: Return(value:
                                equivalentEntity.identifierTypeID().reference | .call(Tuple()
                                    .adding(parameter: TupleParameter(name: value.name, value: value.reference))
                                    .adding(parameter: TupleParameter(name: "identifierTypeID", value: Reference.named("identifierTypeID")))
                                )
                            ))
                )
            ]
        } ?? []
        
        return [selfExtension] + relationshipExtensions + equivalentExtensions
    }
}
