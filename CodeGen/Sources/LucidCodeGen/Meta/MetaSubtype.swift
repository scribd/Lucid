//
//  MetaSubtype.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/10/19.
//

import Meta
import LucidCodeGenCore

struct MetaSubtype {
    
    let subtypeName: String
    
    let descriptions: Descriptions
    
    func meta() throws -> [FileBodyMember] {
        return [
            [
                try subtypeType(),
                EmptyLine(),
            ],
            try codableExtension().flatMap {
                [
                    Comment.mark("Codable"),
                    EmptyLine(),
                    $0,
                    EmptyLine(),
                ]
            } ?? [],
            [
                Comment.mark("Core Data"),
                EmptyLine()
            ],
            try coreDataConveniences(),
            [
                EmptyLine(),
            ],
            [
                Comment.mark("Comparable"),
                EmptyLine(),
                try comparable(),
            ]
        ].flatMap { $0 }
    }
    
    private func subtypeType() throws -> Type {
        let subtype = try descriptions.subtype(for: subtypeName)
        
        let type = Type(identifier: subtype.typeID())
            .with(accessLevel: .public)
            .adding(inheritedType: .codable)
            .adding(inheritedType: subtype.sendable ? .sendable : nil)
            .adding(inheritedType: .hashable)

        switch subtype.items {
        case .cases(let usedCases, _, _):
            return type
                .with(kind: .enum(indirect: false))
                .adding(inheritedType: .caseIterable)
                .adding(members: usedCases.map { Case(name: $0.camelCased().variableCased()) })
            
        case .options(let allOptions, let unusedOptions):
            let unusedOptions = Set(unusedOptions)
            return type
                .with(kind: .struct)
                .adding(inheritedType: .optionSet)
                .adding(member: Property(variable: Variable(name: "rawValue")
                    .with(type: .int))
                    .with(accessLevel: .public)
                )
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .`init`)
                    .with(accessLevel: .public)
                    .adding(parameter: FunctionParameter(name: "rawValue", type: .int))
                    .adding(member: Assignment(
                        variable: .named(.`self`) + .named("rawValue"),
                        value: Reference.named("rawValue")
                    ))
                )
                .adding(member: EmptyLine())
                .adding(members: allOptions.enumerated().compactMap { offset, option in
                    guard unusedOptions.contains(option) == false else {
                        return nil
                    }
                    return Property(variable: Variable(name: option.camelCased().variableCased())
                        .with(static: true))
                        .with(accessLevel: .public)
                        .with(value: subtype.typeID().reference | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "rawValue", value: Value.int(1 << offset)))
                        ))
                })
            
        case .properties(let properties):
            return type
                .with(kind: .struct)
                .adding(member: EmptyLine())
                .adding(members: properties.map { property in
                    Property(variable: Variable(name: property.name.camelCased().variableCased(ignoreLexicon: true))
                        .with(type: property.typeID()))
                        .with(accessLevel: .public)
                })
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .`init`)
                    .with(accessLevel: .public)
                    .adding(parameters: properties.map { property in
                        FunctionParameter(name: property.name.camelCased().variableCased(ignoreLexicon: true), type: property.typeID())
                            .with(defaultValue: property.defaultValue?.variableValue)
                    })
                    .adding(members: properties.map { property in
                        Assignment(
                            variable: Reference.named(.`self`) + .named(property.name.camelCased().variableCased(ignoreLexicon: true)),
                            value: Reference.named(property.name.camelCased().variableCased(ignoreLexicon: true))
                        )
                    })
                )
        }
    }
  
    private func codableExtension() throws -> Extension? {
        let subtype = try descriptions.subtype(for: subtypeName)
        guard subtype.manualImplementations.contains(.codable) == false else { return nil }
        
        switch subtype.items {
        case .cases(let usedCases, let unusedCases, _):
            
            return Extension(type: subtype.typeID())
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .`init`(optional: true))
                    .adding(parameter: FunctionParameter(name: "rawValue", type: .string))
                    .adding(member: Switch(reference: .named("rawValue"))
                        .adding(cases: usedCases.map { name in
                            SwitchCase()
                                .adding(value: Value.string(name))
                                .adding(member: Assignment(
                                    variable: Reference.named(.`self`),
                                    value: +.named(name.camelCased().variableCased()))
                                )
                        })
                        .adding(case: SwitchCase(name: .default)
                            .adding(member: Return(value: Value.nil))
                        )
                    )
                )
                .adding(member: EmptyLine())
                .adding(member: Function.initFromDecoder
                    .with(accessLevel: .public)
                    .adding(member: Assignment(
                        variable: Variable(name: "container"),
                        value: .try | .named("decoder") + .named("singleValueContainer") | .call()
                    ))
                    .adding(member: Assignment(
                        variable: Variable(name: "rawValue"),
                        value: .try | .named("container") + .named("decode") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: TypeIdentifier.string.reference + .named(.`self`)))
                        )
                    ))
                    .adding(member: Switch(reference: .named("rawValue"))
                        .adding(cases: usedCases.map { name in
                            SwitchCase()
                                .adding(value: Value.string(name))
                                .adding(member: Assignment(
                                    variable: Reference.named(.`self`),
                                    value: +.named(name.camelCased().variableCased()))
                            )
                        })
                        .adding(cases: unusedCases.map { name in
                            SwitchCase()
                                .adding(value: Value.string(name))
                                .adding(member: .throw | .named("DecodingErrorWrapper") + .named("decodingOfUnusedProperty") | .call(Tuple()
                                    .adding(parameter: TupleParameter(value: +Reference.named("dataCorrupted") | .call(Tuple()
                                        .adding(parameter: TupleParameter(value: .named("DecodingError") + .named("Context") | .call(Tuple()
                                            .adding(parameter: TupleParameter(name: "codingPath", value: Value.array([])))
                                            .adding(parameter: TupleParameter(name: "debugDescription", value: Value.string("Unused raw value \\(rawValue).")))
                                        )))
                                    )))
                                ))
                        })
                        .adding(case: SwitchCase(name: .default)
                            .adding(member: .throw | .named("DecodingError") + .named("dataCorrupted") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: .named("DecodingError") + .named("Context") | .call(Tuple()
                                    .adding(parameter: TupleParameter(name: "codingPath", value: Value.array([])))
                                    .adding(parameter: TupleParameter(name: "debugDescription", value: Value.string("Unhandled raw value \\(rawValue).")))
                                    )))
                                )
                            )
                        )
                    )
                )
                .adding(member: EmptyLine())
                .adding(member: ComputedProperty(variable: Variable(name: "rawValue")
                    .with(type: .string))
                    .with(accessLevel: .public)
                    .adding(member: Switch(reference: .named(.`self`))
                        .adding(cases: usedCases.map {
                            SwitchCase(name: $0.camelCased().variableCased()).adding(member: Return(value: Value.string($0)))
                        })
                    )
                )
                .adding(member: EmptyLine())
                .adding(member: Function.encode
                    .with(accessLevel: .public)
                    .adding(member: Assignment(
                        variable: Variable(name: "container").with(immutable: false),
                        value: .named("encoder") + .named("singleValueContainer") | .call()
                    ))
                    .adding(member: .try | .named("container") + .named("encode") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Reference.named("rawValue")))
                    ))
                )

        case .options:
            return Extension(type: subtype.typeID())
                .adding(member: Function.initFromDecoder
                    .with(accessLevel: .public)
                    .adding(member: Assignment(
                        variable: Variable(name: "container"),
                        value: .try | .named("decoder") + .named("singleValueContainer") | .call()
                    ))
                    .adding(member: Assignment(
                        variable: Reference.named("rawValue"),
                        value: .try | .named("container") + .named("decode") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: TypeIdentifier.int.reference + .named(.`self`)))
                        )
                    ))
                )
            
        case .properties(let properties):
            return Extension(type: subtype.typeID())
                .adding(member: EmptyLine())
                .adding(member: Type(identifier: TypeIdentifier(name: "Keys"))
                    .with(kind: .enum(indirect: false))
                    .with(accessLevel: .private)
                    .adding(inheritedType: .string)
                    .adding(inheritedType: .codingKey)
                    .adding(members: properties.map {
                        let _case = Case(name: $0.name.camelCased(ignoreLexicon: true).variableCased(ignoreLexicon: true))
                        if let key = $0.key {
                            return _case.with(value: Value.string(key))
                        } else {
                            return _case
                        }
                    })
                )
                .adding(member: EmptyLine())
                .adding(member: Function.initFromDecoder
                    .with(accessLevel: .public)
                    .adding(member: Assignment(
                        variable: Variable(name: "container"),
                        value: .try | .named("decoder") + .named("container") | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "keyedBy", value: .named("Keys") + .named(.`self`)))
                        )
                    ))
                    .adding(members: properties.map { property in
                        return Assignment(
                            variable: Reference.named(property.name.camelCased().variableCased(ignoreLexicon: true)),
                            value: .try | .named("container") + .named("decode") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: property.typeID().wrappedOrSelf.reference + .named(.`self`)))
                                .adding(parameter: TupleParameter(
                                    name: "forKey",
                                    value: +.named(property.name.camelCased(ignoreLexicon: true).variableCased(ignoreLexicon: true))
                                ))
                                .adding(parameter: TupleParameter(name: "defaultValue", value: property.defaultValue?.variableValue ?? Value.nil))
                                .adding(parameter: TupleParameter(name: "logError", value: Value.bool(property.logError)))
                            )
                        )
                    })
                )
                .adding(member: EmptyLine())
                .adding(member: Function.encode
                    .with(accessLevel: .public)
                    .adding(member: Assignment(
                        variable: Variable(name: "container").with(immutable: false),
                        value: .named("encoder") + .named("container") | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "keyedBy", value: .named("Keys") + .named(.`self`))
                        )
                    )))
                    .adding(members: properties.map { property in
                        .try | .named("container") + .named("encode") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Reference.named(property.name.camelCased().variableCased(ignoreLexicon: true))))
                            .adding(parameter: TupleParameter(
                                name: "forKey",
                                value: +.named(property.name.camelCased(ignoreLexicon: true).variableCased(ignoreLexicon: true))
                            ))
                        )
                    })
                )
        }
    }

    private func coreDataConveniences() throws -> [FileBodyMember] {
        let subtype = try descriptions.subtype(for: subtypeName)
        let subtypeVariableName = subtype.name.camelCased().variableCased()
        let isUsedAsArrayWithDefaultValue = descriptions.entities.contains { entity in
            guard let subtypeProperty = entity.properties.first(where: {
                guard let propertySubtype = try? $0.propertyType.subtypeInArray(descriptions) else { return false }
                return propertySubtype.name == subtypeName
            }) else { return false }

            return subtypeProperty.isArray && subtypeProperty.defaultValue != nil
        }

        switch subtype.items {
        case .cases:
            return [
                Extension(type: subtype.typeID())
                    .adding(member: Function(kind: .named("coreDataValue"))
                        .with(resultType: .string)
                        .adding(member: Return(value: Reference.named("rawValue")))
                    ),
                EmptyLine(),
                Extension(type: .optional())
                    .adding(constraint: .named("Wrapped") == subtype.typeID().reference)
                    .adding(member: Function(kind: .named("coreDataValue"))
                        .with(resultType: .optional(wrapped: .string))
                        .adding(member: Return(value: .named(.`self`) | .unwrap + .named("coreDataValue") | .call()))
                    ),
                EmptyLine(),
                Extension(type: .sequence)
                    .adding(constraint: .named("Element") == subtype.typeID().reference)
                    .adding(member: Function(kind: .named("coreDataValue"))
                        .with(resultType: .optional(wrapped: .data))
                        .adding(member: Return(value: .named("map") | .block(FunctionBody()
                            .adding(member: .named("$0") + .named("rawValue"))
                        ) + .named("coreDataValue") | .call()))
                    ),
                EmptyLine(),
                Extension(type: .optional())
                    .adding(constraint: LogicalStatement.assemble(
                        .value(Reference.named("Wrapped")),
                        .constraintImplement,
                        .value(TypeIdentifier.sequence.reference)
                    ))
                    .adding(constraint: .named("Wrapped") + .named("Element") == subtype.typeID().reference)
                    .adding(member: Function(kind: .named("coreDataValue"))
                        .with(resultType: .optional(wrapped: .data))
                        .adding(member: Return(value: .named(.`self`) | .unwrap + .named("coreDataValue") | .call()))
                    ),
                EmptyLine(),
                Extension(type: .string)
                    .adding(member: Function(kind: .named("\(subtypeVariableName)Value"))
                        .with(resultType: .optional(wrapped: subtype.typeID()))
                        .adding(member: Return(value: subtype.typeID().reference | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "rawValue", value: Reference.named(.`self`)))
                        )))
                    ),
                EmptyLine(),
                Extension(type: .optional())
                    .adding(constraint: .named("Wrapped") == TypeIdentifier.string.reference)
                    .adding(member: Function(kind: .named("\(subtypeVariableName)Value"))
                        .with(resultType: .optional(wrapped: subtype.typeID()))
                        .adding(member: Return(value: .named(.`self`) | .unwrap + .named("\(subtypeVariableName)Value") | .call()))
                    )
                    .adding(member: EmptyLine())
                    .adding(member: Function(kind: .named("\(subtypeVariableName)Value"))
                        .adding(parameter: FunctionParameter(name: "propertyName", type: .string))
                        .with(throws: true)
                        .with(resultType: subtype.typeID())
                        .adding(member: Guard(assignment: Assignment(
                            variable: Variable(name: "value"),
                            value: .named(.`self`) | .unwrap + .named("\(subtypeVariableName)Value") | .call()
                        )).adding(member: .throw | TypeIdentifier.coreDataConversionError.reference + .named("corruptedProperty") | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "name", value: Reference.named("propertyName")))
                        )))
                        .adding(member: Return(value: Reference.named("value")))
                    )
                    .adding(member: EmptyLine())
                    .adding(member: Function(kind: .named("\(subtypeVariableName)Value"))
                        .adding(parameter: FunctionParameter(name: "propertyName", type: .string))
                        .with(resultType: .failableValue(of: subtype.typeID()))
                        .adding(member: Guard(assignment: Assignment(
                            variable: Variable(name: "value"),
                            value: .named(.`self`) | .unwrap + .named("\(subtypeVariableName)Value") | .call()
                        )).adding(member: Return(value: +Reference.named("error") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: TypeIdentifier.coreDataConversionError.reference + .named("corruptedProperty") | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "name", value: Reference.named("propertyName")))
                            )))))
                        ))
                        .adding(member: Return(value: +Reference.named("value") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Reference.named("value")))
                        )))
                    ),
                EmptyLine(),
                Extension(type: .data)
                    .adding(member: Function(kind: .named("\(subtypeVariableName)ArrayValue"))
                        .with(resultType: .optional(wrapped: .anySequence(element: subtype.typeID())))
                        .adding(member: Return(value: Reference.named("stringArrayValue") | .call() | .unwrap + .named("lazy") + .named(.compactMap) | .block(FunctionBody()
                            .adding(member: subtype.typeID().reference | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "rawValue", value: Reference.named("$0")))
                            ))
                        ) + .named("any")))
                    ),
                EmptyLine(),
                Extension(type: .optional())
                    .adding(constraint: Reference.named("Wrapped") == TypeIdentifier.data.reference)
                    .adding(member: Function(kind: .named("\(subtypeVariableName)ArrayValue"))
                        .with(resultType: .optional(wrapped: .anySequence(element: subtype.typeID())))
                        .adding(member: Return(value: Reference.named(.`self`) | .unwrap + .named("\(subtypeVariableName)ArrayValue") | .call()))
                    )
                    .adding(member: isUsedAsArrayWithDefaultValue ? EmptyLine() : nil)
                    .adding(member: isUsedAsArrayWithDefaultValue ? Function(kind: .named("\(subtypeVariableName)ArrayValue"))
                        .adding(parameter: FunctionParameter(name: "propertyName", type: .string))
                        .with(throws: true)
                        .with(resultType: .anySequence(element: subtype.typeID()))
                        .adding(member: Return(value: Reference.named("(") | .optionalTry | Reference.named("stringArrayValue") | .call(Tuple()
                                    .adding(parameter: TupleParameter(name: "propertyName", value: Reference.named("propertyName")))
                                ) + .named("lazy") + .named(.compactMap) | .block(FunctionBody()
                                .adding(member: subtype.typeID().reference | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "rawValue", value: Reference.named("$0")))
                            ))
                        ) + .named("any") | Reference.named(")") | Reference.named(" ?? ") | Reference.named(".empty")))
                    : nil)
            ]

        case .options:
            return [
                Extension(type: .int64)
                    .adding(member: Function(kind: .named("\(subtypeVariableName)Value"))
                        .with(resultType: subtype.typeID())
                        .adding(member: Return(value: subtype.typeID().reference | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "rawValue", value: TypeIdentifier.int.reference | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Reference.named(.`self`))))
                            )))
                        ))),
                EmptyLine(),
                Extension(type: .optional())
                    .adding(constraint: .named("Wrapped") == TypeIdentifier.int64.reference)
                    .adding(member: Function(kind: .named("\(subtypeVariableName)Value"))
                        .with(resultType: .optional(wrapped: subtype.typeID()))
                        .adding(member: Return(value: Reference.named(.`self`) | .unwrap + .named("\(subtypeVariableName)Value") | .call()))
                    )
            ]
            
        case .properties:
            return [
                Extension(type: .data)
                    .adding(member: Function(kind: .named("\(subtypeVariableName)Value"))
                        .with(resultType: .optional(wrapped: subtype.typeID()))
                        .adding(member: Do(body: [
                            Return(value: .try | TypeIdentifier.jsonDecoder.reference | .call() + .named("decode") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: subtype.typeID().reference + .named(.`self`)))
                                .adding(parameter: TupleParameter(name: "from", value: Reference.named(.`self`)))
                            ))
                        ], catch: Catch()
                            .adding(member: Reference.logError(from: subtype.typeID(),
                                                               message: "Could not decode: \\(error)",
                                                               assert: true))
                            .adding(member: Return(value: Value.nil))
                        ))
                    )
                    .adding(member: EmptyLine())
                    .adding(member: Function(kind: .named("\(subtypeVariableName)ArrayValue"))
                        .with(resultType: .optional(wrapped: .anySequence(element: subtype.typeID())))
                        .adding(member: Do(body: [
                            Return(value: .try | TypeIdentifier.jsonDecoder.reference | .call() + .named("decode") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: TypeIdentifier.array(element: subtype.typeID()).reference + .named(.`self`)))
                                .adding(parameter: TupleParameter(name: "from", value: Reference.named(.`self`)))
                            ) + .named("lazy") + .named("any"))], catch: Catch()
                                .adding(member: Reference.logError(from: subtype.typeID(),
                                                                   message: "Could not decode: \\(error)",
                                                                   assert: true))
                                .adding(member: Return(value: Value.nil))
                        ))
                    ),
                EmptyLine(),
                Extension(type: .optional())
                    .adding(constraint: .named("Wrapped") == TypeIdentifier.data.reference)
                    .adding(member: Function(kind: .named("\(subtypeVariableName)Value"))
                        .with(resultType: .optional(wrapped: subtype.typeID()))
                        .adding(member: Return(value: .named(.`self`) | .unwrap + .named("\(subtypeVariableName)Value") | .call()))
                    )
                    .adding(member: EmptyLine())
                    .adding(member: Function(kind: .named("\(subtypeVariableName)Value"))
                        .adding(parameter: FunctionParameter(name: "propertyName", type: .string))
                        .with(throws: true)
                        .with(resultType: subtype.typeID())
                        .adding(member: Guard(assignment: Assignment(
                            variable: Variable(name: "value"),
                            value: .named(.`self`) | .unwrap + .named("\(subtypeVariableName)Value") | .call()
                        )).adding(member: .throw | TypeIdentifier.coreDataConversionError.reference + .named("corruptedProperty") | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "name", value: Reference.named("propertyName")))
                        )))
                        .adding(member: Return(value: Reference.named("value")))
                    )
                    .adding(member: EmptyLine())
                    .adding(member: Function(kind: .named("\(subtypeVariableName)ArrayValue"))
                        .with(resultType: .optional(wrapped: .anySequence(element: subtype.typeID())))
                        .adding(member: Return(value: .named(.`self`) | .unwrap + .named("\(subtypeVariableName)ArrayValue") | .call()))
                    )
                    .adding(member: EmptyLine())
                    .adding(member: Function(kind: .named("\(subtypeVariableName)ArrayValue"))
                        .with(throws: true)
                        .with(resultType: .anySequence(element: subtype.typeID()))
                        .adding(parameter: FunctionParameter(name: "propertyName", type: .string))
                        .adding(member: Guard(assignment: Assignment(
                            variable: Variable(name: "value"),
                            value: .named(.`self`) | .unwrap + .named("\(subtypeVariableName)ArrayValue") | .call()
                        )).adding(member: .throw | TypeIdentifier.coreDataConversionError.reference + .named("corruptedProperty") | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "name", value: Reference.named("propertyName")))
                        )))
                        .adding(member: Return(value: Reference.named("value")))
                    ),
                EmptyLine(),
                Extension(type: subtype.typeID())
                    .adding(member: Function(kind: .named("coreDataValue"))
                        .with(resultType: .optional(wrapped: .data))
                        .adding(member: Do(body: [
                            Return(value: .try | TypeIdentifier.jsonEncoder.reference | .call() + .named("encode") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Reference.named(.`self`)))
                            ))
                        ], catch: Catch()
                            .adding(member: Reference.logError(from: subtype.typeID(),
                                                               message: "Could not encode: \\(error)",
                                                               assert: true))
                            .adding(member: Return(value: Value.nil))
                        ))
                    ),
                EmptyLine(),
                Extension(type: .optional())
                    .adding(constraint: .named("Wrapped") == subtype.typeID().reference)
                    .adding(member: Function(kind: .named("coreDataValue"))
                        .with(resultType: .optional(wrapped: .data))
                        .adding(member: Return(value: .named(.`self`) | .unwrap + .named("coreDataValue") | .call()))
                    ),
                EmptyLine(),
                Extension(type: .sequence)
                    .adding(constraint: .named("Element") == subtype.typeID().reference)
                    .adding(member: Function(kind: .named("coreDataValue"))
                        .with(resultType: .optional(wrapped: .data))
                        .adding(member: Do(body: [
                            Return(value: .try | TypeIdentifier.jsonEncoder.reference | .call() + .named("encode") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Reference.array(withArrayValue: .named(.`self`))))
                            ))
                        ], catch: Catch()
                            .adding(member: Reference.logError(from: subtype.typeID(),
                                                               message: "Could not encode: \\(error)",
                                                               assert: true))
                            .adding(member: Return(value: Value.nil))
                        ))
                    )
                    .adding(member: EmptyLine())
                    .adding(member: Function(kind: .named("apiString"))
                        .with(resultType: .optional(wrapped: .string))
                        .adding(member: PlainCode(code: """
                            guard let data = try? JSONEncoder().encode(Array(self)) else { return nil }
                            return String(bytes: data, encoding: .utf8)
                            """))
                    )
                ,
                EmptyLine(),
                Extension(type: .optional())
                    .adding(constraint: LogicalStatement.assemble(
                        .value(Reference.named("Wrapped")),
                        .constraintImplement,
                        .value(TypeIdentifier.sequence.reference)
                    ))
                    .adding(constraint: .named("Wrapped") + .named("Element") == subtype.typeID().reference)
                    .adding(member: Function(kind: .named("coreDataValue"))
                        .with(resultType: .optional(wrapped: .data))
                        .adding(member: Return(value: .named(.`self`) | .unwrap + .named("coreDataValue") | .call()))
                    )
            ]
        }
    }
    
    private func comparable() throws -> Extension {
        let subtype = try descriptions.subtype(for: subtypeName)
        
        switch subtype.items {
        case .cases where subtype.manualImplementations.contains(.codable) == false,
             .options where subtype.manualImplementations.contains(.codable) == false:
            return
                Extension(type: subtype.typeID())
                    .adding(inheritedType: .comparableRawRepresentable)
            
        case .cases,
             .options,
             .properties:
            return
                Extension(type: subtype.typeID())
                    .adding(inheritedType: .comparable)
                    .adding(member:
                        Function(kind: .operator(.lowerThan))
                            .with(static: true)
                            .with(accessLevel: .public)
                            .adding(parameter: FunctionParameter(name: "lhs", type: subtype.typeID()))
                            .adding(parameter: FunctionParameter(name: "rhs", type: subtype.typeID()))
                            .with(resultType: .bool)
                            .adding(member: Return(value: Value.bool(false)))
                    )
        }
    }
}
