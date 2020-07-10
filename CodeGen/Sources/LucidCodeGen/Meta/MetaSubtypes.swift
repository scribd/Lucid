//
//  MetaSubtypes.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/11/19.
//

import Meta

struct MetaSubtypes {
    
    let descriptions: Descriptions
    
    func meta() throws -> [FileBodyMember] {
        return [
            Comment.mark("EntityRelationshipIdentifier"),
            EmptyLine(),
            relationshipIdentifierEnum,
            EmptyLine(),
            Comment.mark("Comparable"),
            EmptyLine(),
            relationshipIdentifierComparableExtension,
            EmptyLine(),
            Comment.mark("DualHashable"),
            EmptyLine(),
            dualHashableExtension,
            EmptyLine(),
            Comment.mark("Conversions"),
            EmptyLine(),
            relationshipIdentifierConversionsExtension,
            EmptyLine(),
            Comment.mark("EntitySubtype"),
            EmptyLine(),
            entitySubtypeEnum,
            EmptyLine(),
            Comment.mark("Conversions"),
            EmptyLine(),
            entitySubtypeConversionsExtension,
            EmptyLine(),
            Comment.mark("Comparable"),
            EmptyLine(),
            entitySubtypeComparableExtension
        ]
    }
    
    private var relationshipIdentifierEnum: Type {
        return Type(identifier: .entityRelationshipIdentifier)
            .adding(inheritedType: .anyCoreDataRelationshipIdentifier)
            .with(kind: .enum(indirect: false))
            .with(accessLevel: .public)
            .adding(members: descriptions.entities.map { entity in
                Case(name: entity.transformedName.variableCased()).adding(parameter: CaseParameter(type: entity.identifierTypeID()))
            })
    }
    
    private var relationshipIdentifierComparableExtension: Extension {
        return Extension(type: .entityRelationshipIdentifier)
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .operator(.lowerThan))
                .with(accessLevel: .public)
                .with(static: true)
                .adding(parameter: FunctionParameter(name: "lhs", type: .entityRelationshipIdentifier))
                .adding(parameter: FunctionParameter(name: "rhs", type: .entityRelationshipIdentifier))
                .with(resultType: .bool)
                .adding(member: Switch(reference: .tuple(Tuple()
                    .adding(parameter: TupleParameter(value: Reference.named("lhs")))
                    .adding(parameter: TupleParameter(value: Reference.named("rhs")))
                ))
                    .adding(cases: descriptions.entities.map { entity in
                        SwitchCase()
                            .adding(value: +.named(entity.transformedName.variableCased()) | .tuple(Tuple()
                                .adding(parameter: TupleParameter(variable: Variable(name: "lhs")))
                            ))
                            .adding(value: +.named(entity.transformedName.variableCased()) | .tuple(Tuple()
                                .adding(parameter: TupleParameter(variable: Variable(name: "rhs")))
                            ))
                            .adding(member: Return(value: .named("lhs") < .named("rhs")))
                    })
                    .adding(case: SwitchCase(name: .default)
                        .adding(member: Return(value: Value.bool(false)))
                    )
                )
            )
    }
    
    private var dualHashableExtension: Extension {
        return Extension(type: .entityRelationshipIdentifier)
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .named("hash"))
                .with(accessLevel: .public)
                .adding(parameter: FunctionParameter(alias: "into", name: "hasher", type: .dualHasher).with(`inout`: true))
                .adding(member: Switch(reference: .named(.`self`))
                    .adding(cases: descriptions.entities.map { entity in
                        SwitchCase()
                            .adding(value: +.named(entity.transformedName.variableCased()) | .tuple(Tuple()
                                .adding(parameter: TupleParameter(variable: Variable(name: "identifier")))
                            ))
                            .adding(member: .named("hasher") + .named("combine") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Reference.named("identifier")))
                            ))
                    })
                )
            )
    }
    
    private var relationshipIdentifierConversionsExtension: Extension {
        return Extension(type: .entityRelationshipIdentifier)
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .named("toRelationshipID"))
                .with(accessLevel: .public)
                .adding(genericParameter: GenericParameter(name: "ID"))
                .adding(constraint: .assemble(.value(Reference.named("ID")),
                                              .constraintImplement,
                                              .value(TypeIdentifier.entityIdentifier.reference)))
                .with(resultType: .optional(wrapped: TypeIdentifier(name: "ID")))
                .adding(member: Switch(reference: .named(.`self`)).with(cases: descriptions.entities.flatMap { entity in
                    [
                        SwitchCase()
                            .adding(value: +.named(entity.transformedName.variableCased()) | .tuple(Tuple()
                                .adding(parameter: TupleParameter(variable: Variable(name: entity.transformedName.variableCased())
                                    .with(as: true)
                                    .with(type: TypeIdentifier(name: "ID"))
                                ))
                            ))
                            .adding(member: Return(value: Reference.named(entity.transformedName.variableCased()))),
                        SwitchCase(name: entity.transformedName.variableCased()).adding(member: Return(value: Value.nil))
                    ]
                }))
            )
            .adding(member: EmptyLine())
            .adding(member: ComputedProperty(variable: Variable(name: "coreDataIdentifierValue")
                .with(type: .named("CoreDataRelationshipIdentifierValueType")))
                .with(accessLevel: .public)
                .adding(member: Switch(reference: .named(.`self`))
                    .with(cases: descriptions.entities.filter { $0.persist }.map { entity in
                        SwitchCase()
                            .adding(value: +.named(entity.transformedName.variableCased()) | .tuple(Tuple()
                                .adding(parameter: TupleParameter(variable: Variable(name: entity.transformedName.variableCased())))
                            ))
                            .adding(member: Return(value: Reference.named(entity.transformedName.variableCased()) + .named("coreDataIdentifierValue")))
                    }
                )
                .adding(cases: descriptions.entities.filter { $0.persist == false }.map { entity in
                    SwitchCase()
                        .adding(value: +.named(entity.transformedName.variableCased()))
                        .adding(member: Return(value: Reference.named(".none")))
                    })
                )
            )
            .adding(member: EmptyLine())
            .adding(member: ComputedProperty(variable: Variable(name: "identifierTypeID")
                .with(type: .string))
                .with(accessLevel: .public)
                .adding(member: Switch(reference: .named(.`self`))
                    .with(cases: descriptions.entities.map { entity in
                        SwitchCase()
                            .adding(value: +.named(entity.transformedName.variableCased()) | .tuple(Tuple()
                                .adding(parameter: TupleParameter(variable: Variable(name: entity.transformedName.variableCased())))
                            ))
                            .adding(member: Return(value: Reference.named(entity.transformedName.variableCased()) + .named("identifierTypeID")))
                    })
                )
            )
            .adding(member: EmptyLine())
            .adding(member: ComputedProperty(variable: Variable(name: "entityTypeUID").with(static: true)
                .with(type: .string))
                .with(accessLevel: .public)
                .adding(member: Return(value: Value.string(String())))
            )
            .adding(member: EmptyLine())
            .adding(member: ComputedProperty(variable: Variable(name: "entityTypeUID")
                .with(type: .string))
                .with(accessLevel: .public)
                .adding(member: Switch(reference: .named(.`self`))
                    .with(cases: descriptions.entities.map { entity in
                        SwitchCase()
                            .adding(value: +.named(entity.transformedName.variableCased()) | .tuple(Tuple()
                                .adding(parameter: TupleParameter(variable: Variable(name: entity.transformedName.variableCased())))
                            ))
                            .adding(member: Return(value: Reference.named(entity.transformedName.variableCased()) + .named("entityTypeUID")))
                    })
                )
            )
            .adding(member: EmptyLine())
            .adding(member: ComputedProperty(variable: Variable(name: "description")
                .with(type: .string))
                .with(accessLevel: .public)
                .adding(member: Switch(reference: .named(.`self`))
                    .with(cases: descriptions.entities.map { entity in
                        SwitchCase()
                            .adding(value: +.named(entity.transformedName.variableCased()) | .tuple(Tuple()
                                .adding(parameter: TupleParameter(variable: Variable(name: entity.transformedName.variableCased())))
                            ))
                            .adding(member: Return(value: Reference.named(entity.transformedName.variableCased()) + .named("description")))
                    })
                )
            )
    }
    
    private var entitySubtypeEnum: Type {
        return Type(identifier: .entitySubtype)
            .with(accessLevel: .public)
            .adding(inheritedType: .anyCoreDataSubtype)
            .with(kind: .enum(indirect: false))
            .adding(members: descriptions.subtypes.map { subtype in
                Case(name: subtype.name.camelCased().suffixedName().variableCased()).adding(parameter: CaseParameter(type: subtype.typeID()))
            })
    }
    
    private var entitySubtypeConversionsExtension: Extension {
        return Extension(type: .entitySubtype)
            .adding(member: EmptyLine())
            .adding(member: ComputedProperty(variable: Variable(name: "predicateValue")
                .with(type: .optional(wrapped: .any)))
                .with(accessLevel: .public)
                .adding(member: Switch(reference: Reference.named(.`self`))
                    .adding(cases: descriptions.subtypes.map { subtype in
                        SwitchCase()
                            .adding(value: +.named(subtype.name.camelCased().suffixedName().variableCased()) |
                                (subtype.isStruct ? .none : .tuple(Tuple()
                                    .adding(parameter: TupleParameter(variable: Variable(name: "subtype")))
                                ))
                            )
                            .adding(member: subtype.isStruct ?
                                Return(value: Value.nil) :
                                Return(value: .named("subtype") + .named("rawValue"))
                            )
                    })
                )
            )
    }
    
    private var entitySubtypeComparableExtension: Extension {
        return Extension(type: .entitySubtype)
            .adding(inheritedType: .comparable)
            .adding(member: EmptyLine())
            .adding(member:
                Function(kind: .operator(.lowerThan))
                    .with(static: true)
                    .with(accessLevel: .public)
                    .adding(parameter: FunctionParameter(name: "lhs", type: .entitySubtype))
                    .adding(parameter: FunctionParameter(name: "rhs", type: .entitySubtype))
                    .with(resultType: .bool)
                    .adding(member:
                        Switch(reference: .tuple(Tuple()
                            .adding(parameter: TupleParameter(value: Reference.named("lhs")))
                            .adding(parameter: TupleParameter(value: Reference.named("rhs")))
                        ))
                        .adding(cases: descriptions.subtypes.map { entity in
                            SwitchCase()
                                .adding(value: +.named(entity.name.camelCased().suffixedName().variableCased()) | .tuple(Tuple()
                                    .adding(parameter: TupleParameter(variable: Variable(name: "lhs")))
                                ))
                                .adding(value: +.named(entity.name.camelCased().suffixedName().variableCased()) | .tuple(Tuple()
                                    .adding(parameter: TupleParameter(variable: Variable(name: "rhs")))
                                ))
                                .adding(member: Return(value: .named("lhs") < .named("rhs")))
                        })
                        .adding(case: SwitchCase(name: .default)
                            .adding(member: Return(value: Value.bool(false)))
                        )
                )
            )
    }
}
