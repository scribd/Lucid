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
    
    private let descriptions: Descriptions

    private let reactiveKit: Bool

    private let useCoreDataLegacyNaming: Bool
    
    public init(descriptions: Descriptions, reactiveKit: Bool, useCoreDataLegacyNaming: Bool) {
        self.descriptions = descriptions
        self.reactiveKit = reactiveKit
        self.useCoreDataLegacyNaming = useCoreDataLegacyNaming
    }
    
    public func generate(for element: Description, in directory: Path) throws -> SwiftFile? {
        guard element == .all else { return nil }
        
        let filename = "EntityGraph.swift"
        
        let header = MetaHeader(filename: filename)
        let entityGraph = MetaEntityGraph(descriptions: descriptions,
                                          reactiveKit: reactiveKit,
                                          useCoreDataLegacyNaming: useCoreDataLegacyNaming)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .adding(import: .lucid(reactiveKit: reactiveKit))
            .adding(import: reactiveKit ? .reactiveKit : .combine)
            .adding(members: entityGraph.meta())
            .swiftFile(in: directory)
    }
}
