//
//  CoreManagerContainersGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/11/19.
//

import Meta
import PathKit

public final class CoreManagerContainersGenerator: Generator {
    
    public let name = "core manager containers"
    
    private let descriptions: Descriptions
    
    private let filename = "CoreManagerContainer.swift"
    
    public init(descriptions: Descriptions) {
        self.descriptions = descriptions
    }
    
    public func generate(for element: Description, in directory: Path) throws -> File? {
        guard element == .all else { return nil }
        
        let header = MetaHeader(filename: filename)
        let coreManagerContainer = MetaCoreManagerContainer(descriptions: descriptions)
        
        return Meta.File(name: filename)
            .adding(import: .lucid())
            .with(header: header.meta)
            .with(body: coreManagerContainer.meta())
            .swiftFile(in: directory)
    }
}
