//
//  PayloadTestsGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/12/19.
//

import Meta
import PathKit

public final class PayloadTestsGenerator: Generator {
    
    public let name = "payload tests"
    
    private let descriptions: Descriptions
    
    public init(descriptions: Descriptions) {
        self.descriptions = descriptions
    }
    
    public func generate(for element: Description, in directory: Path) throws -> File? {
        guard let endpointName = element.endpointName else { return nil }
        
        let filename = "\(endpointName)PayloadsTests.swift"
        
        let header = MetaHeader(filename: filename)
        let endpointPayloadTests = MetaEndpointPayloadTests(endpointName: endpointName,
                                                            descriptions: descriptions)

        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: endpointPayloadTests.imports())
            .adding(member: try endpointPayloadTests.meta())
            .swiftFile(in: directory)
    }
}
