//
//  EndpointPayloadsGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/27/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class EndpointPayloadsGenerator: Generator {
    
    public let name = "payloads"

    public var outputDirectory = OutputDirectory.payloads

    public var targetName = TargetName.app

    public let deleteExtraFiles = true

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }
    
    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        switch element {
        case .all:
            let filename = "EndpointResultPayload.swift"
            
            let header = MetaHeader(filename: filename, organizationName: organizationName)
            let resultPayload = MetaEndpointResultPayload(descriptions: parameters.currentDescriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid)
                .adding(member: try resultPayload.meta())
                .swiftFile(in: directory)

        case .entity(let entityName):
            let entity = try parameters.currentDescriptions.entity(for: entityName)
            guard entity.remote else { return nil }
            
            let filename = "\(entityName.camelCased().suffixedName())Payloads.swift"
            
            let header = MetaHeader(filename: filename, organizationName: organizationName)
            let entityPayload = MetaEntityPayload(entityName: entityName,
                                                  descriptions: parameters.currentDescriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid)
                .with(body: try entityPayload.meta())
                .swiftFile(in: directory)
            
        case .endpoint(let endpointName):
            let filename = "\(endpointName.camelCased(separators: "_/").suffixedName())EndpointPayload.swift"
            
            let header = MetaHeader(filename: filename, organizationName: organizationName)
            let entityPayload = MetaEndpointPayload(endpointName: endpointName,
                                                    descriptions: parameters.currentDescriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid)
                .with(body: try entityPayload.meta())
                .swiftFile(in: directory)
            
        case .subtype:
            return nil
        }
    }
}
