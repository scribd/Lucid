//
//  SubtypesGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/10/19.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class SubtypesGenerator: Generator {
    
    public let name = "subtypes"
    
    private let descriptions: Descriptions

    private let reactiveKit: Bool
    
    public init(descriptions: Descriptions, reactiveKit: Bool) {
        self.descriptions = descriptions
        self.reactiveKit = reactiveKit
    }
    
    public func generate(for element: Description, in directory: Path, companyName: String) throws -> SwiftFile? {
        guard let subtypeName = element.subtypeName else { return nil }
        
        let filename = "\(subtypeName.camelCased().suffixedName()).swift"
        
        let header = MetaHeader(filename: filename, companyName: companyName)
        let subtype = MetaSubtype(subtypeName: subtypeName, descriptions: descriptions)
        let subtypeObjc = MetaSubtypeObjc(subtypeName: subtypeName, descriptions: descriptions)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .adding(import: .lucid(reactiveKit: reactiveKit))
            .adding(members: try subtype.meta())
            .adding(members: try subtypeObjc.meta())
            .swiftFile(in: directory)
    }
}
