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

    private let filename = "SupportUtils.swift"

    public let outputDirectory = OutputDirectory.support

    public let targetName = TargetName.app

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }

    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard element == .all else { return nil }

        let header = MetaHeader(filename: filename, organizationName: organizationName)

        let localStoreCleanup = MetaSupportUtils(
            descriptions: parameters.currentDescriptions,
            reactiveKit: parameters.reactiveKit,
            moduleName: parameters.currentDescriptions.targets.app.moduleName
        )

        return Meta.File(name: filename)
            .with(header: header.meta)
            .adding(import: .lucid)
            .adding(import: parameters.reactiveKit ? .reactiveKit : .combine)
            .with(body: [try localStoreCleanup.meta()])
            .swiftFile(in: directory)
    }
}
