//
//  Generator.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 3/20/19.
//

import Meta
import PathKit

public struct SwiftFile {
    
    public let content: String
    
    public let path: Path

    public init(content: String, path: Path) {
        self.content = content
        self.path = path
    }
}

public protocol Generator {
    
    var name: String { get }
    
    func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile?
}

public protocol ExtensionsGenerator {

    var name: String { get }

    func generate(for element: Description, in directory: Path, organizationName: String) throws -> [SwiftFile]
}

public extension File {
    
    func swiftFile(in directory: Path) -> SwiftFile {
        return SwiftFile(content: swiftString, path: directory + name)
    }
}
