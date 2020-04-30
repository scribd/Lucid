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

enum ConfigurationError: Error {
    case targetNotFound
}

struct SwiftCommandConfiguration {
    
    private var _workingPath: Path = Path(".")
    
    private(set) var targets: TargetConfigurations
    
    // Description files location.
    let _inputPath: Path
    var inputPath: Path {
        return _inputPath.isRelative ? _workingPath + _inputPath : _inputPath
    }

    // Cache files location (defaults to /usr/local/share/lucid/cache).
    private var _cachePath: Path
    var cachePath: Path {
        return _cachePath.isRelative ? _workingPath + _cachePath : _cachePath
    }

    // Current application version (defaults to 1.0.0).
    var currentVersion: String
    
    // Git remote to use for checking out tags (defaults to nil).
    let gitRemote: String?

    // Skips repository updates for data model changes checks.
    var noRepoUpdate: Bool

    // Attempt to build the DataModel regardless of changes.
    var forceBuildModel: Bool

    static func make(with configPath: String,
                     currentVersion: String?,
                     cachePath: String?,
                     noRepoUpdate: Bool?,
                     forceBuildModel: Bool?) throws -> SwiftCommandConfiguration {

        let configPath = Path(configPath)
        var configuration = try YAMLDecoder().decode(SwiftCommandConfiguration.self,
                                                     from: try configPath.read(),
                                                     userInfo: [:])
        configuration._workingPath = configPath.parent()
        configuration.targets._app._workingPath = configuration._workingPath
        configuration.targets._appTests._workingPath = configuration._workingPath
        configuration.targets._appTestSupport._workingPath = configuration._workingPath

        configuration.currentVersion = currentVersion ?? configuration.currentVersion
        configuration._cachePath = cachePath.flatMap { Path($0) } ?? configuration._cachePath
        configuration.noRepoUpdate = noRepoUpdate ?? configuration.noRepoUpdate
        configuration.forceBuildModel = forceBuildModel ?? configuration.forceBuildModel
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
}

struct TargetConfiguration: Target {
   
    fileprivate(set) var name: TargetName
    
    fileprivate var _outputPath: Path
    
    /// Target's module name. Mostly used for imports.
    fileprivate(set) var moduleName: String
    
    fileprivate var _workingPath = Path()

    /// Where to generate the boilerplate code.
    var outputPath: Path {
        return _outputPath.isRelative ? _workingPath + _outputPath : _outputPath
    }
    
    init(_ name: TargetName = .app) {
        self.name = name
        moduleName = name.rawValue.camelCased()
        _outputPath = Path()
    }
}

// MARK: - Defaults

private enum Defaults {
    static let currentVersion = "1.0.0"
    static let cachePath = Path("/usr/local/share/lucid/cache")
    static let gitRemote: String? = nil
    static let noRepoUpdate = false
    static let forceBuildModel = false
}

// MARK: - Decodable

extension SwiftCommandConfiguration: Decodable {
    
    private enum Keys: String, CodingKey {
        case targets
        case inputPath = "input_path"
        case cachePath = "cache_path"
        case currentVersion = "current_version"
        case lastReleaseTag = "last_release_tag"
        case gitRemote = "git_remote"
        case forceBuildModel = "force_build_model"
        case noRepoUpdate = "no_repo_update"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        targets = try container.decode(TargetConfigurations.self, forKey: .targets)
        _inputPath = try container.decode(Path.self, forKey: .inputPath)
        _cachePath = try container.decodeIfPresent(Path.self, forKey: .cachePath) ?? Defaults.cachePath
        currentVersion = try container.decodeIfPresent(String.self, forKey: .currentVersion) ?? Defaults.currentVersion
        gitRemote = try container.decodeIfPresent(String.self, forKey: .gitRemote) ?? Defaults.gitRemote
        forceBuildModel = try container.decodeIfPresent(Bool.self, forKey: .forceBuildModel) ?? Defaults.forceBuildModel
        noRepoUpdate = try container.decodeIfPresent(Bool.self, forKey: .noRepoUpdate) ?? Defaults.noRepoUpdate
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
        if _appTests.moduleName.isEmpty {
            _appTests.moduleName = TargetName.appTests.rawValue.camelCased()
        }
        if _appTests._outputPath.string.isEmpty {
            _appTests._outputPath = Path("\(_appTests.moduleName)/Generated")
        }

        _appTestSupport.name = .appTestSupport
        if _appTestSupport.moduleName.isEmpty {
            _appTestSupport.moduleName = TargetName.appTestSupport.rawValue.camelCased()
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
    }
}

extension Path: Decodable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(String.self))
    }
}
