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

        var body: [FileBodyMember] = []
        var imports: [Import] = []

        if let readPayloadTests = try MetaEndpointReadPayloadTests(endpointName: endpointName,
                                                                   descriptions: parameters.currentDescriptions) {

            imports = readPayloadTests.imports()
            body.append(try readPayloadTests.meta())
        }

        if let writePayloadTests = try MetaEndpointWritePayloadTests(endpointName: endpointName,
                                                                     descriptions: parameters.currentDescriptions) {

            if imports.isEmpty {
                imports = writePayloadTests.imports()
            }
            if body.isEmpty == false {
                body.append(EmptyLine())
            }

            body.append(try writePayloadTests.meta())
        }

        guard body.isEmpty == false else {
            return nil
        }

        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: imports)
            .with(body: body)
            .swiftFile(in: directory)
    }
}
