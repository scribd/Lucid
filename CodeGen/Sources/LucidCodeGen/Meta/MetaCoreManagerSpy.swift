//
//  MetaCoreManagerSpy.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 9/18/19.
//

import Meta
import LucidCodeGenCore

struct MetaCoreManagerSpy {
    
    let descriptions: Descriptions

    
    func imports() -> [Import] {
        return [
            .lucidTestKit,
            .app(descriptions, testable: true),
            .lucid
        ]
    }

    func meta() throws -> [FileBodyMember] {
        return [
            Comment.mark("CoreManagerProviding Extensions")
        ] + descriptions.entities.flatMap { entity -> [FileBodyMember] in
            [
                EmptyLine(),
                Extension(type: .named("CoreManagerSpy"))
                    .adding(inheritedType: entity.coreManagerProvidingTypeID)
                    .adding(constraint: .named("E") == entity.reference)
                    .adding(member:
                        ComputedProperty(variable: Variable(name: entity.coreManagerVariable.name)
                            .with(type: .coreManaging(of: entity.typeID())))
                            .with(accessLevel: .public)
                            .adding(member: Return(value: .named(.`self`) + .named("managing") | .call()))
                )
            ]
        }
    }
}
