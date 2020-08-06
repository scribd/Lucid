//
//  MetaSubtypeExtensions.swift
//  LucidCodeGen
//

import Meta
import LucidCodeGenCore

struct MetaSubtypeExtensions {

    let subtypeName: String

    var extensions: [MetaExtension] {
        return [
            /* MySubtypeExtension(name: subtypeName)*/
        ]
    }
}

/*
private struct MySubtypeExtension: MetaExtension {

    let name: String

    let extensionName: String = "CustomExtension"

    func imports() throws -> [Import] {
        return []
    }

    func meta(for descriptions: Descriptions) throws -> [FileBodyMember] {
        let subtype = try descriptions.subtype(for: name)
        return [
            Comment.mark("Custom \(subtype.name.camelCased()) Extension"),
            EmptyLine(),
            Extension(type: subtype.typeID())
        ]
    }
}
*/
