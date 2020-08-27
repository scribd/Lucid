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
            /* MyEntityExtension(entityName: entityName)*/
        ]
    }
}

/*
private struct MyEntityExtension: MetaExtension {

    let entityName: String

    var filename: String { return entityName.camelCased().suffixedName() }

    let extensionName: String? = "CustomExtension"

    func imports() throws -> [Import] {
        return []
    }

    func meta(for descriptions: Descriptions) throws -> [FileBodyMember] {
        let entity = try descriptions.entity(for: entityName)
        return [
            Comment.mark("Custom \(entity.name.camelCased()) Extension"),
            EmptyLine(),
            Extension(type: entity.typeID())
        ]
    }
}
*/
