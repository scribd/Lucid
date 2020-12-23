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

    /// Name of the generator.
    static var name: String { get }

    /// Directory in which the files will be generated (defaults to `Extensions/$name`).
    static var outputDirectory: OutputDirectory { get }

    /// Target in which the files will be generated.
    static var targetName: TargetName { get }

    /// Should remove extra files from target directory.
    static var deleteExtraFiles: Bool { get }

    init(_ parameters: GeneratorParameters)

    func generate(for elements: [Description], in directory: Path, organizationName: String) throws -> [SwiftFile]
}

public extension ExtensionGenerator {

    static var deleteExtraFiles: Bool { return false }

    static var outputDirectory: OutputDirectory { return .extensions(Path(Self.name)) }
}
