//
//  EntityGraphGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 2/5/20.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class EntityGraphGenerator: Generator {

    public let name = "entity_graph"

    public let outputDirectory = OutputDirectory.support

    public let targetName = TargetName.app

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }

    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard element == .all else { return nil }
        
        let filename = "EntityGraph.swift"
        
        let header = MetaHeader(filename: filename, organizationName: organizationName)
        let entityGraph = MetaEntityGraph(descriptions: parameters.currentDescriptions,
                                          reactiveKit: parameters.reactiveKit,
                                          useCoreDataLegacyNaming: parameters.useCoreDataLegacyNaming)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .adding(import: .lucid)
            .adding(import: parameters.reactiveKit ? .reactiveKit : .combine)
            .adding(members: entityGraph.meta())
            .swiftFile(in: directory)
    }
}
