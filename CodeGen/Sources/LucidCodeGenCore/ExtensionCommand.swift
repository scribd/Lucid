//
//  ExtensionCommand.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 12/22/20.
//

import Foundation
import PathKit
import ShellOut

public final class ExtensionCommand<Input, Output> {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public static var defaultCommandName: String { "command" }

    public init() {
        // no-op
    }
}

extension ExtensionCommand where Input == Void, Output: Codable {

    public func request(extensionPath: Path,
                        commandName: String = ExtensionCommand.defaultCommandName) throws -> ExtensionCommandResponse<Output> {
        return try ExtensionCommand<Empty, Output>().request(extensionPath: extensionPath, commandName: commandName, input: Empty())
    }

    public func respond(inputPath: Path,
                        outputPath: Path,
                        run: @escaping () throws -> Output) throws {
        try ExtensionCommand<Empty, Output>().respond(inputPath: inputPath, outputPath: outputPath) { _ in
            return try run()
        }
    }
}

private var builtExtensionPaths = Set<Path>()

extension ExtensionCommand where Input: Codable, Output: Codable {

    public func request(extensionPath: Path,
                        commandName: String = ExtensionCommand.defaultCommandName,
                        input: Input) throws -> ExtensionCommandResponse<Output> {

        let tmpPath = Path("/tmp") + UUID().uuidString

        do {
            try tmpPath.mkdir()

            let inputPath = tmpPath + "input.json"
            let outputPath = tmpPath + "output.json"

            if builtExtensionPaths.contains(extensionPath) == false {
                try shellOut(
                    to: "swift build --configuration release",
                    at: extensionPath.absolute().string
                )
                builtExtensionPaths.insert(extensionPath)
            }

            try inputPath.write(encoder.encode(input))

            try shellOut(
                to: ".build/release/extension \(commandName) \(inputPath.absolute().string) \(outputPath.absolute().string)",
                at: extensionPath.absolute().string
            )

            let output = try decoder.decode(ExtensionCommandResponse<Output>.self, from: outputPath.read())
            try tmpPath.delete()
            return output

        } catch {
            if tmpPath.exists {
                try tmpPath.delete()
            }
            throw error
        }
    }

    public func respond(inputPath: Path,
                        outputPath: Path,
                        run: @escaping (Input) throws -> Output) throws {

        do {
            let input = try decoder.decode(Input.self, from: inputPath.read())
            let output = try run(input)
            try outputPath.write(encoder.encode(ExtensionCommandResponse.success(output)))
        } catch {
            try outputPath.write(encoder.encode(ExtensionCommandResponse<Output>.failure("Extension error: \(error)")))
        }
    }
}

public enum ExtensionCommandResponse<Success> where Success: Codable {
    case success(Success)
    case failure(String)
}

private struct Empty: Codable {}
