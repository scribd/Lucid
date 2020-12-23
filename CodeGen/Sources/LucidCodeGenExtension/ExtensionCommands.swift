//
//  ExtensionCommands.swift
//  LucidCodeGenExtension
//
//  Created by Théophane Rupin on 12/22/20.
//

import Foundation
import Commander
import LucidCodeGenCore
import PathKit

// MARK: - Commands

public enum ExtensionCommands {

    public static func generator<Generator>(_ generatorType: Generator.Type) -> Group where Generator: ExtensionGenerator {
        Group {
            $0.extensionCommand(name: "configuration") {
                ExtensionGeneratorConfiguration(
                    name: Generator.name,
                    outputDirectory: Generator.outputDirectory,
                    targetName: Generator.targetName
                )
            }

            $0.extensionCommand(name: "generate") { (input: ExtensionGeneratorInput) -> [SwiftFile] in
                try Generator(input.parameters).generate(
                    for: input.elements,
                    in: input.directory,
                    organizationName: input.organizationName
                )
            }
        }
    }
}

// MARK: - Utils

private extension Group {

    func extensionCommand<Output>(name: String = ExtensionCommand<Void, Output>.defaultCommandName,
                                  run: @escaping () throws -> Output) where Output: Codable {

        command(
            name,
            Argument<String>("io-path")
        ) { ioPath in
            let command = ExtensionCommand<Void, Output>()
            try command.respond(ioPath: Path(ioPath), run: run)
        }
    }

    func extensionCommand<Input, Output>(name: String = ExtensionCommand<Input, Output>.defaultCommandName,
                                         run: @escaping (Input) throws -> Output) where Input: Codable, Output: Codable {

        command(
            name,
            Argument<String>("io-path")
        ) { ioPath in
            let command = ExtensionCommand<Input, Output>()
            try command.respond(ioPath: Path(ioPath), run: run)
        }
    }
}
