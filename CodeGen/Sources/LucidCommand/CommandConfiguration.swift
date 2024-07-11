//
//  CommandConfiguration.swift
//  LucidCommand
//
//  Created by Théophane Rupin on 4/19/19.
//

import Yams
import PathKit
import Foundation
import LucidCodeGenCore

enum ConfigurationError: Error {
    case targetNotFound
}

struct CommandConfiguration {
    
    private(set) var _workingPath: Path = .current
    
    private(set) var targets = TargetConfigurations()
    
    /// Description files location.
    var _inputPath = Defaults.inputPath
    var inputPath: Path {
        return _inputPath.isRelative ? _workingPath + _inputPath : _inputPath
    }

    var _extensionsPath: Path? = nil
    var extensionsPath: Path? {
        guard let path = _extensionsPath else { return nil }
        return path.isRelative ? _workingPath + path : path
    }

    /// Cache files location (defaults to /usr/local/share/lucid/cache).
    private var _cachePath: Path = Defaults.cachePath
    var cachePath: Path {
        return _cachePath.isRelative ? _workingPath + _cachePath : _cachePath
    }

    /// Company name that will appear in generated file headers.
    var organizationName = Defaults.organizationName

    /// Current application version (defaults to 1.0.0).
    var currentVersion = Defaults.currentVersion
    
    /// Git remote to use for checking out tags (defaults to nil).
    var gitRemote: String? = nil

    /// Build a new Database Model regardless of changes.
    var forceBuildNewDBModel = Defaults.forceBuildNewDBModel

    /// Build a new Database Model regardless of changes for selected versions only.
    var forceBuildNewDBModelForVersions = Defaults.forceBuildNewDBModelForVersions

    /// Name of the function building `[CoreDataManager.Migration]`
    var coreDataMigrationsFunction: String? = nil

    /// - Warning: This option requires to manually set `LucidConfiguration.useCoreDataLegacyNaming` to `true`
    ///            before using any `CoreManager`. Failing to do so could lead to unexpected behaviors.
    var useCoreDataLegacyNaming = Defaults.useCoreDataLegacyNaming

    /// List of words for which no transformation (capitalization) should be applied.
    var lexicon = Defaults.lexicon

    /// Suffix to apply to entity names.
    var entitySuffix = Defaults.entitySuffix

    static func make(with configPath: String?,
                     currentVersion: String?,
                     cachePath: String?,
                     forceBuildNewDBModel: Bool?,
                     forceBuildNewDBModelForVersions: Set<String>?,
                     selectedTargets: Set<String>,
                     logger: Logger) throws -> CommandConfiguration {

        let configPath = configPath.flatMap { Path($0) } ?? Defaults.configPath
        let configuration = try YAMLDecoder().decode(CommandConfiguration.self, from: try configPath.read())

        return try make(with: configuration,
                        configPath: configPath,
                        currentVersion: currentVersion,
                        cachePath: cachePath,
                        forceBuildNewDBModel: forceBuildNewDBModel,
                        forceBuildNewDBModelForVersions: forceBuildNewDBModelForVersions,
                        selectedTargets: selectedTargets,
                        logger: logger)
    }

    private static func make(with configuration: CommandConfiguration = CommandConfiguration(),
                             configPath: Path,
                             currentVersion: String?,
                             cachePath: String?,
                             forceBuildNewDBModel: Bool?,
                             forceBuildNewDBModelForVersions: Set<String>?,
                             selectedTargets: Set<String>,
                             logger: Logger) throws -> CommandConfiguration {

        var configuration = configuration

        logger.info("cache path: \(cachePath)")

        configuration._workingPath = configPath.parent()
        configuration.targets.app._workingPath = configuration._workingPath
        configuration.targets.appTests._workingPath = configuration._workingPath
        configuration.targets.appTestSupport._workingPath = configuration._workingPath
        
        configuration.targets.select(with: try selectedTargets.map { targetString in
            guard let target = TargetName(rawValue: targetString) else {
                try logger.throwError("Invalid target name: '\(targetString)'")
            }
            return target
        })

        configuration.currentVersion = currentVersion ?? configuration.currentVersion
        configuration._cachePath = cachePath.flatMap { Path($0) } ?? configuration._cachePath
        configuration.forceBuildNewDBModel = forceBuildNewDBModel ?? configuration.forceBuildNewDBModel
        configuration.forceBuildNewDBModelForVersions = forceBuildNewDBModelForVersions ?? configuration.forceBuildNewDBModelForVersions

        String.Configuration.entitySuffix = configuration.entitySuffix
        String.Configuration.setLexicon(configuration.lexicon)

        return configuration
    }

    static func make(with configPath: Path) throws -> CommandConfiguration {
        return try YAMLDecoder().decode(CommandConfiguration.self,
                                        from: try configPath.read(),
                                        userInfo: [:])
    }

    static func make(with logger: Logger, configPath: Path) throws -> CommandConfiguration {

        logger.info("default cache path string: \(Defaults.cachePath.string)")

        var configuration = try make(
            configPath: configPath,
            currentVersion: Defaults.currentVersion,
            cachePath: Defaults.cachePath.string,
            forceBuildNewDBModel: nil,
            forceBuildNewDBModelForVersions: nil,
            selectedTargets: {
                var targets = [TargetName]()
                targets.append(.app)
                if logger.ask("Do you want Lucid to generate code for testing?", defaultValue: false) {
                    targets.append(.appTests)
                    targets.append(.appTestSupport)
                }
                return Set(targets.map { $0.rawValue })
            }(),
            logger: logger
        )

        configuration.targets.app.configure()
        configuration.targets.appTests.configure()
        configuration.targets.appTestSupport.configure()

        return configuration
    }
}

struct TargetConfigurations {
    
    fileprivate var app: TargetConfiguration
    fileprivate var appTests: TargetConfiguration
    fileprivate var appTestSupport: TargetConfiguration

    init() {
        app = TargetConfiguration(.app)
        appTests = TargetConfiguration(.appTests)
        appTestSupport = TargetConfiguration(.appTestSupport)
    }
    
    mutating fileprivate func select(with selectedTargets: [TargetName]) {

        if selectedTargets.isEmpty == false {
            app.isSelected = false
            appTests.isSelected = false
            appTestSupport.isSelected = false
        }
        
        for target in selectedTargets {
            switch target {
            case .app:
                app.isSelected = true
            case .appTests:
                appTests.isSelected = true
            case .appTestSupport:
                appTestSupport.isSelected = true
            }
        }
    }

    var value: Targets {
        return Targets(
            app: app.value,
            appTests: appTests.value,
            appTestSupport: appTestSupport.value
        )
    }
}

struct TargetConfiguration {

    fileprivate(set) var name: TargetName
    
    fileprivate var _outputPath: Path
    
    /// Target's module name. Mostly used for imports.
    fileprivate(set) var moduleName: String
    
    fileprivate var _workingPath = Path()
    
    fileprivate(set) var isSelected: Bool

    /// Where to generate the boilerplate code.
    var outputPath: Path {
        return _outputPath.isRelative ? _workingPath + _outputPath : _outputPath
    }
    
    init(_ name: TargetName = .app) {
        self.name = name
        moduleName = name.rawValue.camelCased()
        _outputPath = Path()
        isSelected = true
    }

    mutating func configure() {
        if moduleName.isEmpty {
            moduleName = name.rawValue.camelCased()
        }
        if _outputPath == Path() {
            _outputPath = Path(moduleName) + Defaults.targetOutputPath
        }
    }

    var value: Target {
        return Target(
            name: name,
            moduleName: moduleName,
            outputPath: outputPath,
            isSelected: isSelected
        )
    }
}

// MARK: - Defaults

private enum Defaults {
    static let inputPath = Path("Descriptions")
    static let configPath = Path(".lucid.yaml")
    static let organizationName = "MyOrganization"
    static let currentVersion = "1.0.0"
    static let cachePath = Path("~/Library/Caches/Lucid").absolute()
    static let gitRemote: String? = nil
    static let forceBuildNewDBModel = true
    static let forceBuildNewDBModelForVersions = Set<String>()
    static let lexicon = [String]()
    static let entitySuffix = ""
    static let useCoreDataLegacyNaming = false
    static let targetOutputPath = Path("Generated")
}

// MARK: - Codable

extension CommandConfiguration: Codable {
    
    private enum Keys: String, CodingKey {
        case targets
        case inputPath = "input_path"
        case extensionsPath = "extensions_path"
        case cachePath = "cache_path"
        case organizationName = "organization_name"
        case currentVersion = "current_version"
        case lastReleaseTag = "last_release_tag"
        case gitRemote = "git_remote"
        case forceBuildNewDBModel = "force_build_new_db_model"
        case forceBuildNewDBModelForVersions = "force_build_new_db_model_for_versions"
        case lexicon = "lexicon"
        case activeTargets = "active_targets"
        case coreDataMigrationsFunction = "core_data_migrations_function"
        case entitySuffix = "entity_suffix"
        case useCoreDataLegacyNaming = "use_core_data_legacy_naming"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        var targets = try container.decode(TargetConfigurations.self, forKey: .targets)
        let activeTargets = try container.decodeIfPresent([TargetName].self, forKey: .activeTargets) ?? []
        targets.select(with: activeTargets)
        self.targets = targets
        
        _inputPath = try container.decodeIfPresent(Path.self, forKey: .inputPath) ?? Defaults.inputPath
        _extensionsPath = try container.decodeIfPresent(Path.self, forKey: .extensionsPath)
        _cachePath = try container.decodeIfPresent(Path.self, forKey: .cachePath) ?? Defaults.cachePath
        organizationName = try container.decodeIfPresent(String.self, forKey: .organizationName) ?? Defaults.organizationName
        currentVersion = try container.decodeIfPresent(String.self, forKey: .currentVersion) ?? Defaults.currentVersion
        gitRemote = try container.decodeIfPresent(String.self, forKey: .gitRemote) ?? Defaults.gitRemote
        forceBuildNewDBModel = try container.decodeIfPresent(Bool.self, forKey: .forceBuildNewDBModel) ?? Defaults.forceBuildNewDBModel
        forceBuildNewDBModelForVersions = try container.decodeIfPresent(Set<String>.self, forKey: .forceBuildNewDBModelForVersions) ?? Defaults.forceBuildNewDBModelForVersions
        coreDataMigrationsFunction = try container.decodeIfPresent(String.self, forKey: .coreDataMigrationsFunction)
        useCoreDataLegacyNaming = try container.decodeIfPresent(Bool.self, forKey: .useCoreDataLegacyNaming) ?? Defaults.useCoreDataLegacyNaming
        lexicon = try container.decodeIfPresent([String].self, forKey: .lexicon) ?? Defaults.lexicon
        entitySuffix = try container.decodeIfPresent(String.self, forKey: .entitySuffix) ?? Defaults.entitySuffix
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(targets, forKey: .targets)

        let activeTargets = [
            TargetName.app.rawValue,
            targets.appTests.isSelected ? TargetName.appTests.rawValue : nil,
            targets.appTestSupport.isSelected ? TargetName.appTestSupport.rawValue : nil
        ].compactMap { $0 }

        if activeTargets.count > 1 {
            try container.encode(activeTargets, forKey: .activeTargets)
        }

        try container.encodeIfPresent(_inputPath, forKey: .inputPath)
        try container.encodeIfPresent(_extensionsPath, forKey: .extensionsPath)
        try container.encodeIfPresent(_cachePath == Defaults.cachePath ? nil : _cachePath, forKey: .cachePath)
        try container.encodeIfPresent(organizationName == Defaults.organizationName ? nil : organizationName, forKey: .organizationName)
        try container.encodeIfPresent(currentVersion == Defaults.currentVersion ? nil : currentVersion, forKey: .currentVersion)
        try container.encodeIfPresent(gitRemote, forKey: .gitRemote)
        try container.encodeIfPresent(forceBuildNewDBModel == Defaults.forceBuildNewDBModel ? nil : forceBuildNewDBModel, forKey: .forceBuildNewDBModel)
        try container.encodeIfPresent(forceBuildNewDBModelForVersions.isEmpty ? nil : forceBuildNewDBModelForVersions.sorted(), forKey: .forceBuildNewDBModelForVersions)
        try container.encodeIfPresent(coreDataMigrationsFunction, forKey: .coreDataMigrationsFunction)
        try container.encodeIfPresent(useCoreDataLegacyNaming == Defaults.useCoreDataLegacyNaming ? nil : useCoreDataLegacyNaming, forKey: .useCoreDataLegacyNaming)
        try container.encodeIfPresent(lexicon == Defaults.lexicon ? nil : lexicon.sorted(), forKey: .lexicon)
        try container.encodeIfPresent(entitySuffix == Defaults.entitySuffix ? nil : entitySuffix, forKey: .entitySuffix)
    }
}

extension TargetName: CodingKey {}

extension TargetConfigurations: Codable {
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TargetName.self)
        app = try container.decodeIfPresent(TargetConfiguration.self, forKey: .app) ?? TargetConfiguration()
        appTests = try container.decodeIfPresent(TargetConfiguration.self, forKey: .appTests) ?? TargetConfiguration()
        appTestSupport = try container.decodeIfPresent(TargetConfiguration.self, forKey: .appTestSupport) ?? TargetConfiguration()
        
        app.name = .app
        app.configure()

        appTests.name = .appTests
        appTests.isSelected = false
        appTests.configure()

        appTestSupport.name = .appTestSupport
        appTestSupport.isSelected = false
        appTestSupport.configure()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TargetName.self)
        try container.encode(app, forKey: .app)

        if appTests.isSelected {
            try container.encode(appTests, forKey: .appTests)
        }

        if appTestSupport.isSelected {
            try container.encode(appTestSupport, forKey: .appTestSupport)
        }
    }
}

extension TargetConfiguration: Codable {
    
    private enum Keys: String, CodingKey {
        case outputPath = "output_path"
        case moduleName = "module_name"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        _outputPath = try container.decodeIfPresent(Path.self, forKey: .outputPath) ?? Path()
        moduleName = try container.decodeIfPresent(String.self, forKey: .moduleName) ?? String()
        name = .app
        isSelected = true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(_outputPath, forKey: .outputPath)
        try container.encode(moduleName, forKey: .moduleName)
    }
}
