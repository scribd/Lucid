//
//  MetaCoreManagerSpy.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 9/18/19.
//

import Meta

struct MetaCoreManagerSpy {
    
    let descriptions: Descriptions

    let reactiveKit: Bool
    
    func imports() -> [Import] {
        return [
            .lucidTestKit(reactiveKit: reactiveKit),
            .app(descriptions, testable: true),
            .lucid(reactiveKit: reactiveKit, testable: true)
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
