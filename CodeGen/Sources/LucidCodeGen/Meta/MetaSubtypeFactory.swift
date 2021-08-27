//
//  MetaSubtypeFactory.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/16/19.
//

import Meta
import LucidCodeGenCore

struct MetaSubtypeFactory {
    
    let subtypeName: String
    
    let descriptions: Descriptions

    func imports() -> [Import] {
        return [
            .app(descriptions, testable: true),
            .lucid
        ]
    }
    
    func meta() throws -> [FileBodyMember] {
        let subtype = try descriptions.subtype(for: subtypeName)
        
        let defautlValueProperty = Property(variable: Variable(name: "defaultValue")
            .with(type: subtype.typeID())
            .with(static: true))
            .with(accessLevel: .public)
        
        switch subtype.items {
        case .cases(let usedCases, _, _):
            guard let firstCase = usedCases.first else {
                throw CodeGenError.subtypeDoesNotHaveAnyCase(subtype.name)
            }
            return [
                Extension(type: subtype.typeID())
                    .adding(member: defautlValueProperty
                        .with(value: +.named(firstCase.camelCased().variableCased(ignoreLexicon: false)))
                    )
            ]
            
        case .options(let allOptions, let unusedOptions):
            let usedOptions = Set(allOptions).subtracting(Set(unusedOptions)).sorted()
            guard let firstOption = usedOptions.first else {
                throw CodeGenError.subtypeDoesNotHaveAnyCase(subtype.name)
            }
            return [
                Extension(type: subtype.typeID())
                    .adding(member: defautlValueProperty
                        .with(value: +.named(firstOption.camelCased().variableCased(ignoreLexicon: false)))
                    )
            ]

        case .properties(let properties):
            
            return [
                Type(identifier: subtype.factoryTypeID)
                    .with(accessLevel: .public)
                    .adding(inheritedType: .subtypeFactory)
                    .adding(members: properties.map { property in
                        Property(variable: Variable(name: property.name.camelCased().variableCased(ignoreLexicon: true))
                            .with(immutable: false)
                            .with(type: property.typeID()))
                            .with(accessLevel: .public)
                    })
                    .adding(member: EmptyLine())
                    .adding(member: Function(kind: .`init`)
                        .with(accessLevel: .public)
                        .adding(parameter: FunctionParameter(alias: "_", name: "identifier", type: .int).with(defaultValue: Value.int(0)))
                        .adding(members: properties.map { property in
                            let value: VariableValue
                            switch property.propertyType {
                            case .custom(let _value):
                                value = .named(_value.camelCased().suffixedName()) + .named("factoryDefaultValue")
                            case .scalar(let _value):
                                value = _value.defaultValue(
                                    propertyName: property.name.camelCased().variableCased(ignoreLexicon: true),
                                    identifier: .named("identifier")
                                )
                            case .array(.scalar(let _value)):
                                let itemValue: VariableValue = _value.defaultValue(
                                    propertyName: property.name.camelCased().variableCased(ignoreLexicon: true),
                                    identifier: .named("identifier")
                                )
                                value = Reference.named("[\(itemValue.swiftString)]")
                            case .array,
                                 .dictionary:
                                value = .type(property.propertyType.typeID(objc: property.objc)) + .named("factoryDefaultValue")
                            }

                            return Assignment(
                                variable: Reference.named(property.name.camelCased().variableCased(ignoreLexicon: true)),
                                value: value
                            )
                        })
                    )
                    .adding(member: EmptyLine())
                    .adding(member: ComputedProperty(variable: Variable(name: "subtype")
                        .with(type: subtype.typeID()))
                        .with(accessLevel: .public)
                        .adding(member: Return(value: subtype.typeID().reference | .call(Tuple()
                            .adding(parameters: properties.map { property in
                                TupleParameter(
                                    name: property.name.camelCased().variableCased(ignoreLexicon: true),
                                    value: Reference.named(property.name.camelCased().variableCased(ignoreLexicon: true)
                                ))
                            })
                        )))
                    )
            ]
        }
    }
}
