//
//  PayloadTestsGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/12/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class PayloadTestsGenerator: Generator {
    
    public let name = "payload tests"

    public var outputDirectory = OutputDirectory.payloadTests

    public var targetName = TargetName.appTests

    public let deleteExtraFiles = true

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }
    
    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard let endpointName = element.endpointName else { return nil }
        
        let filename = "\(endpointName.camelCased(separators: "/_").suffixedName())PayloadsTests.swift"
        
        let header = MetaHeader(filename: filename, organizationName: organizationName)

        guard let endpointPayloadTests = try MetaEndpointPayloadTests(endpointName: endpointName,
                                                                      payloadType: .read,
                                                                      descriptions: parameters.currentDescriptions) else {
            return nil
        }

        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: endpointPayloadTests.imports())
            .adding(member: try endpointPayloadTests.meta())
            .swiftFile(in: directory)
    }
}
