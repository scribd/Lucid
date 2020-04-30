//
//  LocalStoreCleanupManagerGenerator.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 9/18/19.
//

import Meta
import PathKit

public final class LocalStoreCleanupManagerGenerator: Generator {

    public let name = "local store cleanup manager"

    private let descriptions: Descriptions

    private let filename = "LocalStoreCleanupManager.swift"

    public init(descriptions: Descriptions) {
        self.descriptions = descriptions
    }

    public func generate(for element: Description, in directory: Path) throws -> File? {
        guard element == .all else { return nil }

        let header = MetaHeader(filename: filename)
        let localStoreCleanup = MetaLocalStoreCleanupManager(descriptions: descriptions)

        return Meta.File(name: filename)
            .with(header: header.meta)
            .adding(import: .lucid())
            .with(body: [try localStoreCleanup.meta()])
            .swiftFile(in: directory)
    }
}
