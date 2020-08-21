//
//  MetaEntityFactory.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/15/19.
//

import Meta
import LucidCodeGenCore

struct MetaEntityFactory {
    
    let entityName: String
    
    let descriptions: Descriptions

    let reactiveKit: Bool

    func imports() -> [Import] {
        return [
            .app(descriptions, testable: true),
            .lucid(reactiveKit: reactiveKit)
        ]
    }
    
    func meta() throws -> Type {
        let entity = try descriptions.entity(for: entityName)
        return Type(identifier: entity.factoryTypeID)
            .with(accessLevel: .public)
            .adding(member: EmptyLine())
            .adding(members: try identifierProperties())
            .adding(member: EmptyLine())
            .adding(member: try lastRemoteReadProperty())
            .adding(members: try properties())
            .adding(member: try initializerFunction())
            .adding(member: EmptyLine())
            .adding(member: try entityComputedProperty())
    }
    
    private func identifierProperties() throws -> [TypeBodyMember] {
        let entity = try descriptions.entity(for: entityName)

        let identifierProperty = ComputedProperty(variable: Variable(name: "identifier")
            .with(type: entity.identifierTypeID()))
            .with(accessLevel: .public)
            .adding(member: Return(value: entity.identifierTypeID().reference | .call(Tuple()
                .adding(parameter: entity.hasVoidIdentifier ? nil :
                    TupleParameter(name: "value", value: +.named("remote") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: try entity.remoteIdentifierValueTypeID(descriptions).reference | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Reference.named("_identifier")))
                            )))
                        .adding(parameter: TupleParameter(value: Value.nil))
                    )))
                )))

        if entity.hasVoidIdentifier {
            return [identifierProperty]
        }

        return [
            Property(variable: Variable(name: "_identifier")
                .with(immutable: false)
                .with(static: true)
                .with(type: .int))
                .with(accessLevel: .private)
                .with(value: Value.int(0)),
            ComputedProperty(variable: Variable(name: "nextIdentifier")
                .with(immutable: false)
                .with(static: true)
                .with(type: .int))
                .with(accessLevel: .private)
                .adding(member: .named("_identifier") += .value(Value.int(1)))
                .adding(member: Return(value: Reference.named("_identifier"))),
            EmptyLine(),
            Function(kind: .named("resetIdentifier"))
                .with(static: true)
                .adding(member: Assignment(variable: Reference.named("_identifier"), value: Value.int(0))),
            EmptyLine(),
            Property(variable: Variable(name: "_identifier")
                .with(type: .int))
                .with(accessLevel: .private),
            identifierProperty
        ]
    }
    
    private func lastRemoteReadProperty() throws -> Property? {
        let entity = try descriptions.entity(for: entityName)
        guard entity.lastRemoteRead == true else { return nil }
        
        return Property(variable: Variable(name: "lastRemoteRead")
            .with(immutable: false)
            .with(static: false))
            .with(accessLevel: .public)
            .with(value: TypeIdentifier.date.reference | .call())
    }
    
    private func properties() throws -> [TypeBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        var result: [TypeBodyMember] = try entity.valuesThenRelationships.map { property in

            var typeID: TypeIdentifier
            switch property.propertyType {
            case .subtype(let name),
                 .array(.subtype(let name)):
                let subtype = try descriptions.subtype(for: name)
                switch subtype.items {
                case .cases,
                     .options:
                    typeID = try property.valueTypeID(descriptions)
                case .properties:
                    typeID = subtype.factoryTypeID
                    typeID = property.isArray ? .anySequence(element: typeID) : typeID
                    typeID = property.optional ? .optional(wrapped: typeID) : typeID
                    typeID = property.lazy ? .lazyValue(of: typeID) : typeID
                }
            case .array,
                 .relationship,
                 .scalar:
                typeID = try property.valueTypeID(descriptions)
            }
            
            return Property(variable: Variable(name: property.transformedName(ignoreLexicon: true))
                .with(type: typeID)
                .with(immutable: false))
                .with(accessLevel: .public)
        }

        if result.isEmpty == false {
            result.append(EmptyLine())
        }
        return result
    }
    
    private func initializerFunction() throws -> Function {
        let entity = try descriptions.entity(for: entityName)

        if entity.hasVoidIdentifier {
            return Function(kind: .`init`)
                .with(accessLevel: .public)
                .adding(member: Assignment(variable: Variable(name: "voidIdentifierValue").with(type: .int), value:Value.int(0)))
                .adding(members: try entity.valuesThenRelationships.map { property in
                    let value = try property.defaultValue(identifier: .named("voidIdentifierValue"), descriptions: descriptions)
                    return Assignment(
                        variable: Reference.named(property.transformedName(ignoreLexicon: true)),
                        value: value
                    )
                })
        }

        return Function(kind: .`init`)
            .with(accessLevel: .public)
            .adding(parameter: FunctionParameter(alias: "_", name: "identifier", type: .optional(wrapped: .int)).with(defaultValue: Value.nil))
            .adding(member: Assignment(
                variable: Reference.named("_identifier"),
                value: .named("identifier") ?? entity.factoryTypeID.reference + .named("nextIdentifier")
            ))
            .adding(members: try entity.valuesThenRelationships.map { property in

                let propertyValue: VariableValue = try {
                    if property.lazy {
                        return Value.reference(Reference.named(".requested") | .call(Tuple()
                            .adding(parameter:
                                TupleParameter(value: try property.defaultValue(
                                    identifier: .named("_identifier"),
                                    descriptions: descriptions
                                ))
                            )
                        ))
                    } else {
                        return try property.defaultValue(identifier: .named("_identifier"), descriptions: descriptions)
                    }
                }()

                return Assignment(
                    variable: Reference.named(property.transformedName(ignoreLexicon: true)),
                    value: propertyValue
                )
            })
    }
    
    private func entityComputedProperty() throws -> ComputedProperty {
        let entity = try descriptions.entity(for: entityName)
        return ComputedProperty(variable: Variable(name: "entity")
            .with(type: entity.typeID()))
            .with(accessLevel: .public)
            .adding(member: Return(value: entity.typeID().reference | .call(Tuple()
                .adding(parameter: entity.hasVoidIdentifier ? nil : TupleParameter(name: "identifier", value: Reference.named("identifier")))
                .adding(parameter: entity.lastRemoteRead ? TupleParameter(name: "lastRemoteRead", value: Reference.named("lastRemoteRead")) : nil)
                .adding(parameters: try entity.valuesThenRelationships.map { property in
                    var value: Reference
                    switch property.propertyType {
                    case .subtype(let name),
                         .array(.subtype(let name)):
                        let subtype = try descriptions.subtype(for: name)
                        switch subtype.items {
                        case .cases,
                             .options:
                            value = .named(property.transformedName(ignoreLexicon: true))
                        case .properties:
                            value = .named(property.transformedName(ignoreLexicon: true)) + .named("subtype")
                        }
                    case .array,
                         .relationship,
                         .scalar:
                        value = .named(property.transformedName(ignoreLexicon: true))
                    }
                    return TupleParameter(name: property.transformedName(ignoreLexicon: true), value: value)
                })
            )))
    }
}
