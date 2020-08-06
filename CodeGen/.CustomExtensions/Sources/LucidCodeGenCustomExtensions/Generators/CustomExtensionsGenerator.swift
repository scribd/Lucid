//
//  CustomExtensionsGenerator.swift
//  LucidCodeGenCustomExtensions
//
//  Created by Stephane Magne on 07/29/20.
//

import Meta
import PathKit
import LucidCodeGenCore

// MARK: - MetaExtension

public protocol MetaExtension {

    // File will be named "\(name)+\(extensionName).swift"

    var name: String { get }

    var extensionName: String { get }

    func imports() throws -> [Import]

    func meta(for descriptions: Descriptions) throws -> [FileBodyMember]
}

// MARK: - CustomExtensionsGenerator

public final class CustomExtensionsGenerator: ExtensionsGenerator {

    public let name = "Custom Extensions"

    private let descriptions: Descriptions

    public init(descriptions: Descriptions) {
        self.descriptions = descriptions
    }
    
    public func generate(for element: Description, in directory: Path, companyName: String) throws -> [SwiftFile] {

        let extensions: [MetaExtension]

        switch element {
        case .entity(let entityName):
            let customEntity = MetaEntityCustomExtensions(entityName: entityName)
            extensions = customEntity.extensions

        case .subtype(let subtypeName):
            let customSubtype = MetaSubtypeCustomExtensions(subtypeName: subtypeName)
            extensions = customSubtype.extensions

        case .all,
             .endpoint:
            /// No support for custom extensions of .all or .endpoint. Only .entity and .subtype are supported.
            return []
        }

        return try extensions.compactMap { try file(for: $0, in: directory, companyName: companyName) }
    }
}

private extension CustomExtensionsGenerator {

    func file(for metaExtension: MetaExtension, in directory: Path, companyName: String) throws -> SwiftFile? {

        let imports = try metaExtension.imports()
        let body = try metaExtension.meta(for: descriptions)

        guard body.isEmpty == false else { return nil }

        let filename = "\(metaExtension.name.camelCased().suffixedName())+\(metaExtension.extensionName).swift"
        let header = MetaHeader(filename: filename, companyName: companyName)

        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: imports)
            .with(body: body)
            .swiftFile(in: directory)
    }
}
