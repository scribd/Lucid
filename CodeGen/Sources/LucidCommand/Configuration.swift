//
//  Configuration.swift
//  LucidCommand
//
//  Created by Théophane Rupin on 4/19/19.
//

import Yams
import PathKit
import Foundation
import LucidCodeGen
import LucidCodeGenCore

enum ConfigurationError: Error {
    case targetNotFound
}

struct SwiftCommandConfiguration {
    
    private(set) var _workingPath: Path = .current
    
    private(set) var targets: TargetConfigurations
    
    /// Description files location.
    let _inputPath: Path
    var inputPath: Path {
        return _inputPath.isRelative ? _workingPath + _inputPath : _inputPath
    }

    /// Cache files location (defaults to /usr/local/share/lucid/cache).
    private var _cachePath: Path
    var cachePath: Path {
        return _cachePath.isRelative ? _workingPath + _cachePath : _cachePath
    }

    /// Company name that will appear in generated file headers.
    let companyName: String

    /// Current application version (defaults to 1.0.0).
    var currentVersion: String
    
    /// Git remote to use for checking out tags (defaults to nil).
    let gitRemote: String?

    /// Skips repository updates for data model changes checks.
    var noRepoUpdate: Bool

    /// Build a new Database Model regardless of changes.
    var forceBuildNewDBModel: Bool

    /// Build a new Database Model regardless of changes for selected versions only.
    var forceBuildNewDBModelForVersions: Set<String>

    /// Name of the function building `CoreManagerContainerClientQueueResponseHandler`.
    let responseHandlerFunction: String?
    
    /// Name of the function building `[CoreDataManager.Migration]`
    let coreDataMigrationsFunction: String?

    /// - Warning: This option requires to manually set `LucidConfiguration.useCoreDataLegacyNaming` to `true`
    ///            before using any `CoreManager`. Failing to do so could lead to unexpected behaviors.
    let useCoreDataLegacyNaming: Bool

    /// Weither to use ReactiveKit's API.
    var reactiveKit: Bool

    /// List of words for which no transformation (capitalization) should be applied.
    let lexicon: [String]

    /// Suffix to apply to entity names.
    let entitySuffix: String

    static func make(with configPath: String,
                     currentVersion: String?,
                     cachePath: String?,
                     noRepoUpdate: Bool?,
                     forceBuildNewDBModel: Bool?,
                     forceBuildNewDBModelForVersions: Set<String>?,
                     selectedTargets: Set<String>,
                     reactiveKit: Bool?,
                     logger: Logger) throws -> SwiftCommandConfiguration {

        let configPath = Path(configPath)
        var configuration = try YAMLDecoder().decode(SwiftCommandConfiguration.self,
                                                     from: try configPath.read(),
                                                     userInfo: [:])
        configuration._workingPath = configPath.parent()
        configuration.targets._app._workingPath = configuration._workingPath
        configuration.targets._appTests._workingPath = configuration._workingPath
        configuration.targets._appTestSupport._workingPath = configuration._workingPath
        
        configuration.targets.select(with: try selectedTargets.map { targetString in
            guard let target = TargetName(rawValue: targetString) else {
                try logger.throwError("Invalid target name: '\(targetString)'")
            }
            return target
        })

        configuration.currentVersion = currentVersion ?? configuration.currentVersion
        configuration._cachePath = cachePath.flatMap { Path($0) } ?? configuration._cachePath
        configuration.noRepoUpdate = noRepoUpdate ?? configuration.noRepoUpdate
        configuration.forceBuildNewDBModel = forceBuildNewDBModel ?? configuration.forceBuildNewDBModel
        configuration.forceBuildNewDBModelForVersions = forceBuildNewDBModelForVersions ?? configuration.forceBuildNewDBModelForVersions
        configuration.reactiveKit = reactiveKit ?? configuration.reactiveKit

        String.Configuration.entitySuffix = configuration.entitySuffix
        String.Configuration.setLexicon(configuration.lexicon)

        return configuration
    }
}

struct TargetConfigurations: Targets {
    
    fileprivate var _app: TargetConfiguration
    var app: Target {
        return _app
    }
    
    fileprivate var _appTests: TargetConfiguration
    var appTests: Target {
        return _appTests
    }
    
    fileprivate var _appTestSupport: TargetConfiguration
    var appTestSupport: Target {
        return _appTestSupport
    }
    
    init() {
        _app = TargetConfiguration(.app)
        _appTests = TargetConfiguration(.appTests)
        _appTestSupport = TargetConfiguration(.appTestSupport)
    }
    
    mutating fileprivate func select(with selectedTargets: [TargetName]) {

        if selectedTargets.isEmpty == false {
            _app.isSelected = false
            _appTests.isSelected = false
            _appTestSupport.isSelected = false
        }
        
        for target in selectedTargets {
            switch target {
            case .app:
                _app.isSelected = true
            case .appTests:
                _appTests.isSelected = true
            case .appTestSupport:
                _appTestSupport.isSelected = true
            }
        }
    }
}

struct TargetConfiguration: Target {
   
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
}

// MARK: - Defaults

private enum Defaults {
    static let companyName = "MyCompany"
    static let currentVersion = "1.0.0"
    static let cachePath = Path("/usr/local/share/lucid/cache")
    static let gitRemote: String? = nil
    static let noRepoUpdate = false
    static let forceBuildNewDBModel = true
    static let forceBuildNewDBModelForVersions = Set<String>()
    static let lexicon = [String]()
    static let entitySuffix = ""
    static let reactiveKit = false
    static let useCoreDataLegacyNaming = false
}

// MARK: - Decodable

extension SwiftCommandConfiguration: Decodable {
    
    private enum Keys: String, CodingKey {
        case targets
        case inputPath = "input_path"
        case cachePath = "cache_path"
        case companyName = "company_name"
        case currentVersion = "current_version"
        case lastReleaseTag = "last_release_tag"
        case gitRemote = "git_remote"
        case forceBuildNewDBModel = "force_build_new_db_model"
        case forceBuildNewDBModelForVersions = "force_build_new_db_model_for_versions"
        case noRepoUpdate = "no_repo_update"
        case lexicon = "lexicon"
        case activeTargets = "active_targets"
        case responseHandlerFunction = "response_handler_function"
        case coreDataMigrationsFunction = "core_data_migrations_function"
        case entitySuffix = "entity_suffix"
        case reactiveKit = "reactive_kit"
        case useCoreDataLegacyNaming = "use_core_data_legacy_naming"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        var targets = try container.decode(TargetConfigurations.self, forKey: .targets)
        let activeTargets = try container.decodeIfPresent([TargetName].self, forKey: .activeTargets) ?? []
        targets.select(with: activeTargets)
        self.targets = targets
        
        _inputPath = try container.decode(Path.self, forKey: .inputPath)
        _cachePath = try container.decodeIfPresent(Path.self, forKey: .cachePath) ?? Defaults.cachePath
        companyName = try container.decodeIfPresent(String.self, forKey: .companyName) ?? Defaults.companyName
        currentVersion = try container.decodeIfPresent(String.self, forKey: .currentVersion) ?? Defaults.currentVersion
        gitRemote = try container.decodeIfPresent(String.self, forKey: .gitRemote) ?? Defaults.gitRemote
        forceBuildNewDBModel = try container.decodeIfPresent(Bool.self, forKey: .forceBuildNewDBModel) ?? Defaults.forceBuildNewDBModel
        forceBuildNewDBModelForVersions = try container.decodeIfPresent(Set<String>.self, forKey: .forceBuildNewDBModelForVersions) ?? Defaults.forceBuildNewDBModelForVersions
        noRepoUpdate = try container.decodeIfPresent(Bool.self, forKey: .noRepoUpdate) ?? Defaults.noRepoUpdate
        responseHandlerFunction = try container.decodeIfPresent(String.self, forKey: .responseHandlerFunction)
        coreDataMigrationsFunction = try container.decodeIfPresent(String.self, forKey: .coreDataMigrationsFunction)
        useCoreDataLegacyNaming = try container.decodeIfPresent(Bool.self, forKey: .useCoreDataLegacyNaming) ?? Defaults.useCoreDataLegacyNaming
        reactiveKit = try container.decodeIfPresent(Bool.self, forKey: .reactiveKit) ?? Defaults.reactiveKit
        lexicon = try container.decodeIfPresent([String].self, forKey: .lexicon) ?? Defaults.lexicon
        entitySuffix = try container.decodeIfPresent(String.self, forKey: .entitySuffix) ?? Defaults.entitySuffix
    }
}

extension TargetName: CodingKey {}

extension TargetConfigurations: Decodable {
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TargetName.self)
        _app = try container.decodeIfPresent(TargetConfiguration.self, forKey: .app) ?? TargetConfiguration()
        _appTests = try container.decodeIfPresent(TargetConfiguration.self, forKey: .appTests) ?? TargetConfiguration()
        _appTestSupport = try container.decodeIfPresent(TargetConfiguration.self, forKey: .appTestSupport) ?? TargetConfiguration()
        
        _app.name = .app
        if _app.moduleName.isEmpty {
            _app.moduleName = TargetName.app.rawValue.camelCased()
        }
        if _app._outputPath.string.isEmpty {
            _app._outputPath = Path("\(_app.moduleName)/Generated")
        }

        _appTests.name = .appTests
        _appTests.isSelected = false
        if _appTests.moduleName.isEmpty {
            _appTests.moduleName = TargetName.appTests.rawValue.camelCased(ignoreLexicon: true)
        }
        if _appTests._outputPath.string.isEmpty {
            _appTests._outputPath = Path("\(_appTests.moduleName)/Generated")
        }

        _appTestSupport.name = .appTestSupport
        _appTestSupport.isSelected = false
        if _appTestSupport.moduleName.isEmpty {
            _appTestSupport.moduleName = TargetName.appTestSupport.rawValue.camelCased(ignoreLexicon: true)
        }
        if _appTestSupport._outputPath.string.isEmpty {
            _appTestSupport._outputPath = Path("\(_appTestSupport.moduleName)/Generated")
        }
    }
}

extension TargetConfiguration: Decodable {
    
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
}

extension Path: Decodable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(String.self))
    }
}
