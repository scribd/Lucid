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
    
    private let descriptions: Descriptions

    public init(descriptions: Descriptions) {
        self.descriptions = descriptions
    }
    
    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard let endpointName = element.endpointName else { return nil }
        
        let filename = "\(endpointName.camelCased(separators: "/_").suffixedName())PayloadsTests.swift"
        
        let header = MetaHeader(filename: filename, organizationName: organizationName)
        let endpointPayloadTests = MetaEndpointPayloadTests(endpointName: endpointName,
                                                            descriptions: descriptions)

        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: endpointPayloadTests.imports())
            .adding(member: try endpointPayloadTests.meta())
            .swiftFile(in: directory)
    }
}
