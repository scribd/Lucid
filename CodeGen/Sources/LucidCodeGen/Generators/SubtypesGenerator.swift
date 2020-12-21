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

    public let outputDirectory = OutputDirectory.subtypes

    public let targetName = TargetName.app

    public let deleteExtraFiles = true

    private let parameters: GeneratorParameters

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }
    
    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard let subtypeName = element.subtypeName else { return nil }
        
        let filename = "\(subtypeName.camelCased().suffixedName()).swift"
        
        let header = MetaHeader(filename: filename, organizationName: organizationName)
        let subtype = MetaSubtype(subtypeName: subtypeName, descriptions: parameters.currentDescriptions)
        let subtypeObjc = MetaSubtypeObjc(subtypeName: subtypeName, descriptions: parameters.currentDescriptions)
        
        return Meta.File(name: filename)
            .with(header: header.meta)
            .adding(import: .lucid)
            .adding(members: try subtype.meta())
            .adding(members: try subtypeObjc.meta())
            .swiftFile(in: directory)
    }
}
