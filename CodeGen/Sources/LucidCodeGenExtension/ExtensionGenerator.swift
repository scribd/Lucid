//
//  ExtensionGenerator.swift
//  LucidCodeGenExtension
//
//  Created by Théophane Rupin on 12/23/20.
//

import Foundation
import LucidCodeGenCore
import PathKit

public protocol ExtensionGenerator {

    static var name: String { get }

    static var outputDirectory: OutputDirectory { get }

    static var targetName: TargetName { get }

    static var deleteExtraFiles: Bool { get }

    init(_ parameters: GeneratorParameters)

    func generate(for elements: [Description], in directory: Path, organizationName: String) throws -> [SwiftFile]
}

public extension ExtensionGenerator {

    static var deleteExtraFiles: Bool { return false }

    static var outputDirectory: OutputDirectory { return .extensions(Path(Self.name)) }
}
