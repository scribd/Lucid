//
//  CustomExtensionsGenerator.swift
//  LucidCodeGenCustomExtensions
//
//  Created by Stephane Magne on 07/29/20.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class CustomExtensionsGenerator: Generator {

    public let name = "Custom Extensions"

    private let descriptions: Descriptions

    private let extensionName: String

    public init(descriptions: Descriptions,
                extensionName: String) {
        self.descriptions = descriptions
        self.extensionName = extensionName
    }
    
    public func generate(for element: Description, in directory: Path, companyName: String) throws -> SwiftFile? {
        let typeName: String
        let fileExtensionName: String
        let imports: [Import]
        let body: [FileBodyMember]

        switch element {
        case .entity(let entityName):
            let customEntity = MetaEntityCustomExtension(entityName: entityName, descriptions: descriptions)
            typeName = entityName
            fileExtensionName = customEntity.extensionName ?? extensionName
            imports = try customEntity.imports()
            body = try customEntity.meta()

        case .subtype(let subtypeName):
            let customSubtype = MetaSubtypeCustomExtension(subtypeName: subtypeName, descriptions: descriptions)
            typeName = subtypeName
            fileExtensionName = customSubtype.extensionName ?? extensionName
            imports = try customSubtype.imports()
            body = try customSubtype.meta()

        case .all,
             .endpoint:
            /// No support for custom extensions of .all or .endpoint. Only .entity and .subtype are supported.
            return nil
        }

        guard body.isEmpty == false else { return nil }

        let filename = "\(typeName.camelCased().suffixedName())+\(fileExtensionName).swift"
        let header = MetaHeader(filename: filename, companyName: companyName)

        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: imports)
            .with(body: body)
            .swiftFile(in: directory)
    }
}
