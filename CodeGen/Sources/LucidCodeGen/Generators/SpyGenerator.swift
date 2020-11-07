//
//  SpyGenerator.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 9/18/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class SpyGenerator: Generator {
    
    public let name = "spies"
    
    private let descriptions: Descriptions

    public init(descriptions: Descriptions) {
        self.descriptions = descriptions
    }
    
    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        switch element {
        case .all:
            let filename = "CoreManagerSpy+ManagerProviding.swift"
            
            let header = MetaHeader(filename: filename, organizationName: organizationName)
            let spyFactory = MetaCoreManagerSpy(descriptions: descriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .with(imports: spyFactory.imports())
                .adding(members: try spyFactory.meta())
                .swiftFile(in: directory)
        case .subtype,
             .entity,
             .endpoint:
            return nil
        }
    }
}
