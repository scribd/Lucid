//
//  EndpointPayloadsGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/27/19.
//

import Meta
import PathKit

public final class EndpointPayloadsGenerator: Generator {
    
    public let name = "payloads"
    
    private let descriptions: Descriptions

    private let reactiveKit: Bool
    
    public init(descriptions: Descriptions, reactiveKit: Bool) {
        self.descriptions = descriptions
        self.reactiveKit = reactiveKit
    }
    
    public func generate(for element: Description, in directory: Path) throws -> File? {
        switch element {
        case .all:
            let filename = "EndpointResultPayload.swift"
            
            let header = MetaHeader(filename: filename)
            let resultPayload = MetaEndpointResultPayload(descriptions: descriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid(reactiveKit: reactiveKit))
                .adding(member: try resultPayload.meta())
                .swiftFile(in: directory)

        case .entity(let entityName):
            let entity = try descriptions.entity(for: entityName)
            guard entity.remote else { return nil }
            
            let filename = "\(entityName.camelCased().suffixedName())Payloads.swift"
            
            let header = MetaHeader(filename: filename)
            let entityPayload = MetaEntityPayload(entityName: entityName,
                                                  descriptions: descriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid(reactiveKit: reactiveKit))
                .with(body: try entityPayload.meta())
                .swiftFile(in: directory)
            
        case .endpoint(let endpointName):
            let filename = "\(endpointName.camelCased(separators: "_/").suffixedName())EndpointPayload.swift"
            
            let header = MetaHeader(filename: filename)
            let entityPayload = MetaEndpointPayload(endpointName: endpointName,
                                                    descriptions: descriptions)
            
            return Meta.File(name: filename)
                .with(header: header.meta)
                .adding(import: .lucid(reactiveKit: reactiveKit))
                .with(body: try entityPayload.meta())
                .swiftFile(in: directory)
            
        case .subtype:
            return nil
        }
    }
}
