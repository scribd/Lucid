//
//  ClientQueueResponseHandlerGenerator.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 1/12/21.
//

import Meta
import PathKit
import LucidCodeGenCore

public final class ClientQueueResponseHandlerGenerator: Generator {

    public let name = "Core Data migration tests"

    private let filename = "RootClientQueueResponseHandler.swift"

    public let outputDirectory = OutputDirectory.support

    public var targetName = TargetName.app

    private let parameters: GeneratorParameters

    public let deleteExtraFiles = false

    public init(_ parameters: GeneratorParameters) {
        self.parameters = parameters
    }

    public func generate(for element: Description, in directory: Path, organizationName: String) throws -> SwiftFile? {
        guard element == .all else { return nil }

        let header = MetaHeader(filename: filename, organizationName: organizationName)

        guard let clientQueueResponseHandler = try MetaClientQueueResponseHandler(descriptions: parameters.currentDescriptions,
                                                                                  reactiveKit: parameters.reactiveKit) else {
            return nil
        }

        return Meta.File(name: filename)
            .with(header: header.meta)
            .with(imports: clientQueueResponseHandler.imports())
            .adding(members: try clientQueueResponseHandler.meta())
            .swiftFile(in: directory)
    }
}
