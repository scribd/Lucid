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
    
    private let descriptions: Descriptions
    
    private let filename = "CoreManagerContainer.swift"
    
    private let responseHandlerFunction: String?

    private let coreDataMigrationsFunction: String?

    private let reactiveKit: Bool

    public init(descriptions: Descriptions,
                responseHandlerFunction: String?,
                coreDataMigrationsFunction: String?,
                reactiveKit: Bool) {

        self.descriptions = descriptions
        self.responseHandlerFunction = responseHandlerFunction
        self.coreDataMigrationsFunction = coreDataMigrationsFunction
        self.reactiveKit = reactiveKit
    }
    
    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard element == .all else { return nil }
        
        let header = MetaHeader(filename: filename, organizationName: organizationName)
        let coreManagerContainer = MetaCoreManagerContainer(descriptions: descriptions,
                                                            responseHandlerFunction: responseHandlerFunction,
                                                            coreDataMigrationsFunction: coreDataMigrationsFunction,
                                                            reactiveKit: reactiveKit)
        
        return Meta.File(name: filename)
            .adding(import: .lucid(reactiveKit: reactiveKit))
            .adding(import: reactiveKit ? .reactiveKit : .combine)
            .with(header: header.meta)
            .with(body: coreManagerContainer.meta())
            .swiftFile(in: directory)
    }
}
