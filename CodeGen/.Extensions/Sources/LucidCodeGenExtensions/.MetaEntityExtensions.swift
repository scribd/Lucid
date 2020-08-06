//
//  MetaEntityExtensions.swift
//  LucidCodeGen
//

import Meta
import LucidCodeGenCore

struct MetaEntityExtensions {

    let entityName: String

    var extensions: [MetaExtension] {
        return [
            /* MyEntityExtension(name: entityName)*/
        ]
    }
}

/*
private struct MyEntityExtension: MetaExtension {

    let name: String

    let extensionName: String = "CustomExtension"

    func imports() throws -> [Import] {
        return []
    }

    func meta(for descriptions: Descriptions) throws -> [FileBodyMember] {
        guard let entity = try descriptions.entity(for: name) else { return [] }
        return [
            Comment.mark("Custom \(entity.name.camelCased()) Extension"),
            EmptyLine(),
            Extension(type: entity.typeID())
        ]
    }
}
*/
