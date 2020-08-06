//  MetaSubtypeCustomExtension.swift
//  LucidCodeGen
//

import Meta
import LucidCodeGenCore

struct MetaSubtypeCustomExtension {

    let subtypeName: String

    let descriptions: Descriptions

    var extensionName: String? {
        return nil
    }

    func imports() throws -> [Import] {
        return []
    }

    func meta() throws -> [FileBodyMember] {
        return []
    }
}
