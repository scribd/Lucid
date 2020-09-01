//
//  MetaAllExtensions.swift
//  LucidCodeGen
//

import Meta
import LucidCodeGenCore

struct MetaAllExtensions {

    var extensions: [MetaExtension] {
        return [
            /* MyAllExtension()*/
        ]
    }
}

/*
private struct MyAllExtension: MetaExtension {

    let filename: String = "EntitySupport"

    let extensionName: String? = nil

    func imports() throws -> [Import] {
        return [
            Import(name: "CoreData")
        ]
    }

    func meta(for descriptions: Descriptions) throws -> [FileBodyMember] {
        return [
            Comment.mark("Support Classes"),
            EmptyLine(),
            Type(identifier: TypeIdentifier(name: "MySupportClass"))
                .adding(inheritedType: .codable)
                .with(kind: .class(final: true))
        ]
    }
}
*/
