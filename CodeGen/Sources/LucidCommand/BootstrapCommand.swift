//
//  Bootstrap.swift
//  LucidCommand
//
//  Created by Stephane Magne on 8/6/20.
//

import Foundation
import LucidCodeGen
import LucidCodeGenCore
import PathKit
import Yams
import ShellOut

final class BootstrapCommand {

    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func saveDefaultConfiguration(with configPath: Path) throws {
        let configuration = try CommandConfiguration.make(with: logger, configPath: configPath)
        let yamlConfiration = try YAMLEncoder().encode(configuration)
        try configPath.write(yamlConfiration)
    }

    private func saveExampleEntityDescription(_ configuration: CommandConfiguration) throws {
        let entity = Entity(
            name: "my_entity",
            remote: true,
            persist: true,
            identifier: EntityIdentifier(identifierType: .scalarType(.int)),
            properties: [
                EntityProperty(
                    name: "my_string_property",
                    propertyType: .scalar(.string)
                ),
                EntityProperty(
                    name: "my_bool_property",
                    propertyType: .scalar(.bool)
                )
            ],
            identifierTypeID: "my_entity",
            versionHistory: [VersionHistoryItem(version: try Version(configuration.currentVersion, source: .description))]
        )
        try configuration.save(entity)
    }

    private func saveExampleEndpointPayloadDescription(_ configuration: CommandConfiguration) throws {
        let endpoint = EndpointPayload(
            name: "/my_entity",
            entity: EndpointPayloadEntity(
                entityName: "my_entity",
                structure: .single
            )
        )
        try configuration.save(endpoint)
    }

    private func saveExampleExtension(_ extensionsPath: Path) throws {
        if extensionsPath.exists == false {
            try extensionsPath.mkpath()
        }

        let lucidPath = extensionsPath + ".lucid"
        if lucidPath.exists == false {
            try shellOut(
                to: "git clone --single-branch --branch theo/plugins git@github.com:scribd/Lucid.git .lucid",
                at: extensionsPath.absolute().string
            )
        }

        let gitIgnorePath = extensionsPath + ".gitignore"
        if gitIgnorePath.exists == false {
            try gitIgnorePath.write("""
            .lucid
            """)
        }

        let myExtensionPath = extensionsPath + "MyExtension"
        if myExtensionPath.exists == false {

            try myExtensionPath.mkdir()

            let packagePath = myExtensionPath + "package.swift"
            try packagePath.write("""
            // swift-tools-version:5.0
            import PackageDescription

            let package = Package(
                name: "Extension",
                products: [
                    .executable(name: "extension", targets: ["Extension"])
                ],
                dependencies: [
                    .package(path: "../.lucid/CodeGen")
                ],
                targets: [
                    .target(name: "Extension", dependencies: ["LucidCodeGenExtension"])
                ]
            )
            """)

            let sourcesPath = myExtensionPath + "Sources/Extension"
            try sourcesPath.mkpath()

            let mainPath = sourcesPath + "main.swift"
            try mainPath.write("""
            import LucidCodeGenExtension
            import LucidCodeGenCore
            import PathKit

            struct Generator: ExtensionGenerator {

                static let name = "MyExtensionGenerator"

                static let targetName: TargetName = .app

                private let parameters: GeneratorParameters

                init(_ parameters: GeneratorParameters) {
                    self.parameters = parameters
                }

                func generate(for elements: [Description], in directory: Path, organizationName: String) throws -> [SwiftFile] {
                    return []
                }
            }

            ExtensionCommands.generator(Generator.self).run()
            """)

            try shellOut(
                to: "swift package generate-xcodeproj",
                at: myExtensionPath.absolute().string
            )
        }
    }

    func createFileStructure(_ configuration: CommandConfiguration) throws {

        logger.moveToChild("Generating folders.")
        if configuration.inputPath.exists == false {
            logger.info("Adding \(configuration.inputPath).")
            try configuration.inputPath.mkdir()

            let endpointsPath = configuration.inputPath + OutputDirectory.endpointPayloads.path(appModuleName: configuration.targets.value.app.moduleName)
            logger.info("Adding \(endpointsPath).")
            try endpointsPath.mkdir()

            let entitiesPath = configuration.inputPath + OutputDirectory.entities.path(appModuleName: configuration.targets.value.app.moduleName)
            logger.info("Adding \(entitiesPath).")
            try entitiesPath.mkdir()

            let subtypesPath = configuration.inputPath + OutputDirectory.subtypes.path(appModuleName: configuration.targets.value.app.moduleName)
            logger.info("Adding \(subtypesPath).")
            try subtypesPath.mkdir()

            try saveExampleEntityDescription(configuration)
            try saveExampleEndpointPayloadDescription(configuration)
        } else {
            logger.info("Folder \(configuration.inputPath) already exists.")
        }

        if let extensionsPath = configuration.extensionsPath {
            try saveExampleExtension(extensionsPath)
        }

        logger.moveToParent()
    }
}

// MARK: - Saving

private extension CommandConfiguration {

    private func save<T>(_ data: T, at path: Path) throws where T: Encodable {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let json = try encoder.encode(data)
        try path.write(json)
    }

    func save(_ entity: Entity) throws {
        let fileName = entity.name.camelCased(ignoreLexicon: false) + ".json"
        let descriptionPath = inputPath + OutputDirectory.entities.path(appModuleName: targets.value.app.moduleName) + fileName
        try save(entity, at: descriptionPath)
    }

    func save(_ endpointPayload: EndpointPayload) throws {
        let fileName = endpointPayload.name.camelCased(separators: "/_", ignoreLexicon: false) + ".json"
        let descriptionPath = inputPath + OutputDirectory.endpointPayloads.path(appModuleName: targets.value.app.moduleName) + fileName
        try save(endpointPayload, at: descriptionPath)
    }
}
