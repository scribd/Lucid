//
//  Generator.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 3/20/19.
//

import Meta
import PathKit

public struct SwiftFile: Codable {
    
    public let content: String
    
    public let path: Path

    public init(content: String, path: Path) {
        self.content = content
        self.path = path
    }
}

public enum OutputDirectory {
    case entities
    case payloads
    case endpointPayloads
    case subtypes
    case support
    case factories
    case doubles
    case coreDataModel(version: Version)
    case coreDataModelVersion
    case jsonPayloads(String)
    case payloadTests
    case coreDataTests
    case coreDataMigrationTests
    case sqliteFiles
    case extensions(Path)
}

public protocol Generator {

    var name: String { get }

    var outputDirectory: OutputDirectory { get }

    var targetName: TargetName { get }

    var deleteExtraFiles: Bool { get }

    func generate(for elements: [Description], in directory: Path, organizationName: String, logger: Logger?) throws -> [SwiftFile]

    func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile?
}

public extension Generator {

    var deleteExtraFiles: Bool { return false }

    func generate(for elements: [Description], in directory: Path, organizationName: String, logger: Logger?) throws -> [SwiftFile] {
        try elements.compactMap { element in
            do {
                return try generate(for: element, in: directory, organizationName: organizationName)
            } catch {
                logger?.error("Failed to generate '\(element)'.")
                throw error
            }
        }
    }
}

public extension File {

    func swiftFile(in directory: Path) -> SwiftFile {
        return SwiftFile(content: swiftString, path: directory + name)
    }
}
