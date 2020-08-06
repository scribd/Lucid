//
//  LocalStoreCleanupManagerGenerator.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 9/18/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class LocalStoreCleanupManagerGenerator: Generator {

    public let name = "local store cleanup manager"

    private let descriptions: Descriptions

    private let filename = "LocalStoreCleanupManager.swift"

    private let reactiveKit: Bool

    public init(descriptions: Descriptions, reactiveKit: Bool) {
        self.descriptions = descriptions
        self.reactiveKit = reactiveKit
    }

    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard element == .all else { return nil }

        let header = MetaHeader(filename: filename, organizationName: organizationName)
        let localStoreCleanup = MetaLocalStoreCleanupManager(descriptions: descriptions, reactiveKit: reactiveKit)

        return Meta.File(name: filename)
            .with(header: header.meta)
            .adding(import: .lucid(reactiveKit: reactiveKit))
            .adding(import: reactiveKit ? .reactiveKit : .combine)
            .with(body: [try localStoreCleanup.meta()])
            .swiftFile(in: directory)
    }
}
