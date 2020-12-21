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

    public let outputDirectory = OutputDirectory.doubles

    public let targetName = TargetName.appTestSupport

    public let deleteExtraFiles = true

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }

    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        switch element {
        case .all:
            let filename = "CoreManagerSpy+ManagerProviding.swift"
            
            let header = MetaHeader(filename: filename, organizationName: organizationName)
            let spyFactory = MetaCoreManagerSpy(descriptions: parameters.currentDescriptions)
            
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
