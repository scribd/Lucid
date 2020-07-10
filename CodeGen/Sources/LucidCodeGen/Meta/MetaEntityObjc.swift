//
//  MetaEntityObjc.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 5/9/19.
//

import Meta

struct MetaEntityObjc {
    
    let entityName: String
    
    let descriptions: Descriptions
    
    func meta() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.objc else { return [] }
        
        return try [
            EmptyLine(),
            Comment.mark("Objc Compatibility")
        ] + entityIdentifierObjcType() + [
            EmptyLine(),
            try entityObjcType()
        ]
    }

    private func entityIdentifierObjcType() throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        guard entity.identifier.objc else { return [] }
        return [
            EmptyLine(),
            Type(identifier: entity.identifierTypeID(objc: true))
                .with(kind: .class(final: true))
                .with(accessLevel: .public)
                .with(objc: true)
                .adding(inheritedType: .nsObject)
                .adding(member: EmptyLine())
                .adding(member: Property(variable: Variable(name: "value")
                    .with(type: entity.identifierTypeID()))
                    .with(accessLevel: .public))
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .`init`)
                    .with(accessLevel: .public)
                    .adding(parameter: FunctionParameter(alias: "_", name: "value", type: entity.identifierTypeID()))
                    .adding(member: Assignment(
                        variable: .named(.`self`) + .named("value"),
                        value: Reference.named("value")
                    ))
                )
        ]
    }
    
    private func entityObjcType() throws -> Type {
        let entity = try descriptions.entity(for: entityName)
        
        let valueVariable = Variable(name: "value")
            .with(immutable: entity.usedProperties.contains { $0.objc && $0.mutable } == false)
            .with(type: entity.typeID())
        
        return Type(identifier: entity.typeID(objc: true))
            .adding(inheritedType: .nsObject)
            .with(kind: .class(final: true))
            .with(accessLevel: .public)
            .with(objc: true)
            .adding(member: EmptyLine())
            .adding(member: Property(variable: valueVariable)
                .with(accessLevel: valueVariable.immutable ? .public : .composite(.public, .privateSet))
            )
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .`init`)
                .with(accessLevel: .public)
                .adding(parameter: FunctionParameter(alias: "_", name: "value", type: entity.typeID()))
                .adding(member: Assignment(
                    variable: .named(.`self`) + .named("value"),
                    value: Reference.named("value")
                ))
            )
            .adding(member: entity.identifier.objc ? EmptyLine() : nil)
            .adding(member: entity.identifier.objc ? ComputedProperty(variable: Variable(name: "identifier")
                .with(type: entity.identifierTypeID(objc: true)))
                .with(objc: true)
                .with(accessLevel: .public)
                .adding(member: Return(value: entity.identifierTypeID(objc: true).reference | .call(Tuple()
                    .adding(parameter: TupleParameter(value: .named("value") + .named("identifier")))
                ))) : nil
            )
            .adding(members: try entity.usedProperties.filter { $0.objc }.flatMap { property -> [TypeBodyMember] in
                return [
                    EmptyLine(),
                    ComputedProperty(variable: property.variable
                        .with(type: try property.valueTypeID(descriptions, objc: true)))
                        .with(objc: true)
                        .with(accessLevel: .public)
                        .adding(member: Return(
                            value: try propertySwiftToObjcValueConversionReference(for: property, baseReference: .named("value") + property.variable.reference))
                        )
                ]
            })
    }
}

// MARK: - Utils

private extension MetaEntityObjc {
    
    func propertySwiftToObjcValueConversionReference(for property: EntityProperty, baseReference: Reference) throws -> Reference {
        let isEnumSubtype = try property.propertyType.subtype(descriptions)?.isEnum ?? false

        func propertyValueReference(with typeID: TypeIdentifier) throws -> Reference {
            if property.isArray {
                return baseReference | (property.optional ? .unwrap : .none) + .named(.map) | .block(FunctionBody()
                    .adding(member: typeID.reference | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Reference.named("$0")))
                    ))
                )
            } else if property.optional && isEnumSubtype == false {
                return baseReference + .named(.flatMap) | .block(FunctionBody()
                    .adding(member: typeID.reference | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Reference.named("$0")))
                    ))
                )
            } else {
                return typeID.reference | .call(Tuple()
                    .adding(parameter: TupleParameter(value: baseReference))
                )
            }
        }
        
        switch property.propertyType {
        case .relationship(let relationship),
             .array(.relationship(let relationship)):
            let relationshipEntity = try descriptions.entity(for: relationship.entityName)
            return try propertyValueReference(with: relationshipEntity.identifierTypeID(objc: true))
        case .subtype(let name),
             .array(.subtype(let name)):
            let subtype = try descriptions.subtype(for: name)
            return try propertyValueReference(with: subtype.typeID(objc: true))
        case .scalar(.color),
             .array(.scalar(.color)):
            return try propertyValueReference(with: PropertyScalarType.color.typeID(objc: true))
        case .scalar(.seconds),
             .array(.scalar(.seconds)):
            return try propertyValueReference(with: PropertyScalarType.seconds.typeID(objc: true))
        case .scalar(.milliseconds),
             .array(.scalar(.milliseconds)):
            return try propertyValueReference(with: PropertyScalarType.milliseconds.typeID(objc: true))
        case .scalar,
             .array:
            var value = baseReference
            
            let valueType = try property.valueTypeID(descriptions, objc: true)
            if valueType == .nsNumber || valueType == .optional(wrapped: .nsNumber) {
                value = value | .as | valueType.reference
            }
            
            return value
        }
    }
    
    func propertyObjcToSwiftValueConversionReference(for property: EntityProperty, baseReference: Reference) throws -> Reference {
        switch property.propertyType {
        case .subtype,
             .array(.subtype),
             .scalar(.color),
             .array(.scalar(.color)),
             .scalar(.milliseconds),
             .array(.scalar(.milliseconds)),
             .scalar(.seconds),
             .array(.scalar(.seconds)):
            let isEnumSubtype = try property.propertyType.subtype(descriptions)?.isEnum ?? false
            var valueMethod: Reference = .named("value") | (isEnumSubtype ? .call() : .none)
            if let defaultValue = property.defaultValue, property.optional {
                valueMethod = valueMethod | .named("??") | .named(defaultValue.variableValue.swiftString)
            }
            if property.isArray {
                return baseReference | (property.optional ? .unwrap : .none) + .named("lazy") + .named(.map) | .block(FunctionBody()
                    .adding(member: .named("$0") + valueMethod)
                ) + .named("any")
            } else if property.optional && isEnumSubtype == false {
                return baseReference + .named(.flatMap) | .block(FunctionBody()
                    .adding(member: .named("$0") + valueMethod)
                )
            } else {
                return baseReference + valueMethod
            }
        case .scalar,
             .array,
             .relationship:
            return baseReference
        }
    }
}
