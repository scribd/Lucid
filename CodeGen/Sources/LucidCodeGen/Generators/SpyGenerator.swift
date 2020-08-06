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

    private let reactiveKit: Bool
    
    public init(descriptions: Descriptions, reactiveKit: Bool) {
        self.descriptions = descriptions
        self.reactiveKit = reactiveKit
    }
    
    public func generate(for element: Description, in directory: Path) throws -> SwiftFile? {
        switch element {
        case .all:
            let filename = "CoreManagerSpy+ManagerProviding.swift"
            
            let header = MetaHeader(filename: filename)
            let spyFactory = MetaCoreManagerSpy(descriptions: descriptions, reactiveKit: reactiveKit)
            
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
