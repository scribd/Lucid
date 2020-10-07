//
//  SupportUtilsGenerator.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 9/18/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class SupportUtilsGenerator: Generator {

    public let name = "support utils"

    private let descriptions: Descriptions

    private let filename = "SupportUtils.swift"

    private let reactiveKit: Bool

    private let moduleName: String

    public init(descriptions: Descriptions, reactiveKit: Bool, moduleName: String) {
        self.descriptions = descriptions
        self.reactiveKit = reactiveKit
        self.moduleName = moduleName
    }

    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard element == .all else { return nil }

        let header = MetaHeader(filename: filename, organizationName: organizationName)
        let localStoreCleanup = MetaSupportUtils(descriptions: descriptions, reactiveKit: reactiveKit, moduleName: moduleName)

        return Meta.File(name: filename)
            .with(header: header.meta)
            .adding(import: .lucid(reactiveKit: reactiveKit))
            .adding(import: reactiveKit ? .reactiveKit : .combine)
            .with(body: [try localStoreCleanup.meta()])
            .swiftFile(in: directory)
    }
}
