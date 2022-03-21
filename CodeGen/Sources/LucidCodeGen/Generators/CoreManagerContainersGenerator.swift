//
//  CoreManagerContainersGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/11/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class CoreManagerContainersGenerator: Generator {

    public let name = "core manager containers"
    
    private let filename = "CoreManagerContainer.swift"

    public let outputDirectory = OutputDirectory.support

    public let targetName = TargetName.app

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }

    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard element == .all else { return nil }
        
        let header = MetaHeader(filename: filename, organizationName: organizationName)
        let coreManagerContainer = MetaCoreManagerContainer(descriptions: parameters.currentDescriptions,
                                                            coreDataMigrationsFunction: parameters.coreDataMigrationsFunction)
        
        return Meta.File(name: filename)
            .adding(import: .lucid)
            .adding(import: .combine)
            .with(header: header.meta)
            .with(body: try coreManagerContainer.meta())
            .swiftFile(in: directory)
    }
}
