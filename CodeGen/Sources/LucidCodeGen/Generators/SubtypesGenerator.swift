//
//  SubtypesGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/10/19.
//

import Meta
import PathKit

public final class SubtypesGenerator: Generator {
    
    public let name = "subtypes"
    
    private let descriptions: Descriptions
    
    public init(descriptions: Descriptions) {
        self.descriptions = descriptions
    }
    
    public func generate(for element: Description, in directory: Path) throws -> File? {
        guard let subtypeName = element.subtypeName else { return nil }
        
        let filename = "\(subtypeName).swift"
        
        let header = MetaHeader(filename: filename)
        let subtype = MetaSubtype(subtypeName: subtypeName, descriptions: descriptions)
        let subtypeObjc = MetaSubtypeObjc(subtypeName: subtypeName, descriptions: descriptions)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .adding(import: .lucid())
            .adding(members: try subtype.meta())
            .adding(members: try subtypeObjc.meta())
            .swiftFile(in: directory)
    }
}
