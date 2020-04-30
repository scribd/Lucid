//
//  EntityGraphGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 2/5/20.
//

import Meta
import PathKit

public final class EntityGraphGenerator: Generator {
    
    public let name = "entity_graph"
    
    private let descriptions: Descriptions
    
    public init(descriptions: Descriptions) {
        self.descriptions = descriptions
    }
    
    public func generate(for element: Description, in directory: Path) throws -> File? {
        guard element == .all else { return nil }
        
        let filename = "EntityGraph.swift"
        
        let header = MetaHeader(filename: filename)
        let entityGraph = MetaEntityGraph(descriptions: descriptions)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .adding(import: .lucid())
            .adding(members: entityGraph.meta())
            .swiftFile(in: directory)
    }
}
