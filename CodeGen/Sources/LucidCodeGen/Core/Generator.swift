//
//  Generator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/20/19.
//

import Meta
import PathKit

public struct File {
    
    public let content: String
    
    public let path: Path
}

public protocol Generator {
    
    var name: String { get }
    
    func generate(for element: Description, in directory: Path) throws -> File?
}

extension Meta.File {
    
    func swiftFile(in directory: Path) -> File {
        return File(content: swiftString, path: directory + name)
    }
}
