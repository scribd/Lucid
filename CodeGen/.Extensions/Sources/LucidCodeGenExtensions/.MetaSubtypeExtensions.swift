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
            /* MySubtypeExtension(subtypeName: subtypeName)*/
        ]
    }
}

/*
private struct MySubtypeExtension: MetaExtension {

    let subtypeName: String

    var filename: String { return subtypeName.camelCased().suffixedName() }

    let extensionName: String? = "CustomExtension"

    func imports() throws -> [Import] {
        return []
    }

    func meta(for descriptions: Descriptions) throws -> [FileBodyMember] {
        let subtype = try descriptions.subtype(for: subtypeName)
        return [
            Comment.mark("Custom \(subtype.name.camelCased()) Extension"),
            EmptyLine(),
            Extension(type: subtype.typeID())
        ]
    }
}
*/
