//
//  MetaSubtypeObjc.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 5/9/19.
//

import Meta

struct MetaSubtypeObjc {
    
    let subtypeName: String

    let descriptions: Descriptions
    
    func meta() throws -> [FileBodyMember] {
        let subtype = try descriptions.subtype(for: subtypeName)
        guard subtype.objc else { return [] }
        
        return [
            EmptyLine(),
            Comment.mark("ObjC Compatibility"),
            EmptyLine(),
            try subtypeObjcType()
                .with(accessLevel: .public)
                .with(objc: true)
        ]
    }
    
    private func subtypeObjcType() throws -> Type {
        let subtype = try descriptions.subtype(for: subtypeName)
        switch subtype.items {
        case .cases(let usedCases, _, let objcNoneCase):
            
            let needsNoneCase = try objcNoneCase || subtype.needsObjcNoneCase(descriptions)
            var subtypeTypeID = subtype.typeID()
            if needsNoneCase {
                subtypeTypeID = .optional(wrapped: subtypeTypeID)
            }
            
            return Type(identifier: subtype.typeID(objc: true))
                .with(kind: .enum(indirect: false))
                .adding(inheritedType: .int)
                .adding(members: usedCases.map { Case(name: $0) })
                .adding(member: needsNoneCase ? Case(name: "none") : nil)
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .`init`)
                    .with(accessLevel: .public)
                    .adding(parameter: FunctionParameter(alias: "_", name: "value", type: subtypeTypeID))
                    .adding(member: Switch(reference: Reference.named("value"))
                        .adding(cases: usedCases.map {
                            SwitchCase(name: "\($0)\(needsNoneCase ? "?" : "")").adding(member: Assignment(
                                variable: Reference.named(.`self`),
                                value: +.named($0)
                            ))
                        })
                        .adding(case: needsNoneCase ? SwitchCase(name: "none")
                            .adding(member: Assignment(
                                variable: Reference.named(.`self`),
                                value: +.named("none")
                            )) : nil
                        )
                    )
                )
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .named("value"))
                    .with(resultType: subtypeTypeID)
                    .with(accessLevel: .public)
                    .adding(member: Switch(reference: Reference.named(.`self`))
                        .adding(cases: usedCases.map {
                            SwitchCase(name: $0).adding(member: Return(value: +.named($0)))
                        })
                        .adding(case: needsNoneCase ? SwitchCase(name: "none")
                            .adding(member: Return(value: Value.nil)) : nil
                        )
                    )
                )
            
        case .options(let allOptions, let unusedOptions):
            let usedOptions = Set(allOptions).subtracting(Set(unusedOptions)).sorted()
            return Type(identifier: subtype.typeID(objc: true))
                .with(kind: .class(final: true))
                .adding(inheritedType: .nsObject)
                .adding(member: Property(variable: Variable(name: "value")
                    .with(type: subtype.typeID()))
                    .with(accessLevel: .public)
                )
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .`init`)
                    .with(accessLevel: .public)
                    .adding(parameter: FunctionParameter(alias: "_", name: "value", type: subtype.typeID()))
                    .adding(member: Assignment(
                        variable: .named(.`self`) + .named("value"),
                        value: Reference.named("value")
                    ))
                )
                .adding(member: EmptyLine())
                .adding(members: usedOptions.map {
                    Property(variable: Variable(name: $0)
                        .with(static: true))
                        .with(accessLevel: .public)
                        .with(objc: true)
                        .with(value: subtype.typeID(objc: true).reference | .call(Tuple()
                            .adding(parameter: TupleParameter(value: +.named($0)))
                        ))
                })

        case .properties(let properties):
            return Type(identifier: subtype.typeID(objc: true))
                .with(kind: .class(final: true))
                .adding(inheritedType: .nsObject)
                .adding(member:
                    Property(variable: Variable(name: "value")
                        .with(type: subtype.typeID()))
                        .with(accessLevel: .public)
                )
                .adding(member: EmptyLine())
                .adding(member: Function(kind: .`init`)
                    .with(accessLevel: .public)
                    .adding(parameter: FunctionParameter(alias: "_", name: "value", type: subtype.typeID()))
                    .adding(member: Assignment(
                        variable: .named(.`self`) + .named("value"),
                        value: Reference.named("value")
                    ))
                )
                .adding(members: properties.filter { $0.objc }.enumerated().flatMap { index, property -> [TypeBodyMember] in
                    return [
                        EmptyLine(),
                        ComputedProperty(variable: Variable(name: property.name)
                            .with(type: property.typeID(objc: true)))
                            .with(accessLevel: .public)
                            .with(objc: true)
                            .adding(member: Return(value: .named("value") + .named(property.name)))
                    ]
                })
        }
    }
}
