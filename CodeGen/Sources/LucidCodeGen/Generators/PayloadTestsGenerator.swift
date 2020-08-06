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

    private let reactiveKit: Bool
    
    public init(descriptions: Descriptions, reactiveKit: Bool) {
        self.descriptions = descriptions
        self.reactiveKit = reactiveKit
    }
    
    public func generate(for element: Description, in directory: Path) throws -> SwiftFile? {
        guard let endpointName = element.endpointName else { return nil }
        
        let filename = "\(endpointName.camelCased(separators: "/_").suffixedName())PayloadsTests.swift"
        
        let header = MetaHeader(filename: filename)
        let endpointPayloadTests = MetaEndpointPayloadTests(endpointName: endpointName,
                                                            descriptions: descriptions,
                                                            reactiveKit: reactiveKit)

        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: endpointPayloadTests.imports())
            .adding(member: try endpointPayloadTests.meta())
            .swiftFile(in: directory)
    }
}
