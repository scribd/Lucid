//
//  ExtensionGenerator.swift
//  LucidCommand
//
//  Created by Théophane Rupin on 12/22/20.
//

import Foundation
import PathKit
import LucidCodeGenCore
import ShellOut

final class ExtensionGenerator: Generator {

    private let parameters: GeneratorParameters

    private let extensionPath: Path

    let name: String

    let outputDirectory: OutputDirectory

    let targetName: TargetName

    let logger: Logger

    init(_ parameters: GeneratorParameters, extensionPath: Path, logger: Logger) throws {
        self.parameters = parameters
        self.extensionPath = extensionPath
        self.logger = logger

        let command = ExtensionCommand<Void, ExtensionGeneratorConfiguration>()
        switch try command.request(extensionPath: extensionPath, commandName: "configuration") {
        case .success(let configuration):
            outputDirectory = configuration.outputDirectory
            name = configuration.name
            targetName = configuration.targetName
        case .failure(let error):
            try logger.throwError(error)
        }
    }

    func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        fatalError("Not implemented")
    }

    func generate(for elements: [Description], in directory: Path, organizationName: String, logger: Logger?) throws -> [SwiftFile] {

        let command = ExtensionCommand<ExtensionGeneratorInput, [SwiftFile]>()

        let input = ExtensionGeneratorInput(
            paramters: parameters,
            elements: elements,
            directory: directory,
            organizationName: organizationName
        )

        switch try command.request(extensionPath: extensionPath, commandName: "generate", input: input) {
        case .success(let files):
            return files
        case .failure(let error):
            try self.logger.throwError(error)
        }
    }
}
