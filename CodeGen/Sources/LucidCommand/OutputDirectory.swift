//
//  Constants.swift
//  LucidCommand
//
//  Created by Théophane Rupin on 1/31/19.
//

import Foundation
import PathKit

enum OutputDirectory {
    case entities
    case payloads
    case endpointPayloads
    case subtypes
    case support
    case factories
    case doubles
    case coreDataModel(version: String)
    case coreDataModelVersion
    case jsonPayloads(String)
    case payloadTests
    case coreDataTests
    case coreDataMigrationTests
    case sqliteFiles
    
    func path(appModuleName: String) -> Path {
        switch self {
        case .entities:
            return Path("Entities")
        case .payloads:
            return Path("Payloads")
        case .endpointPayloads:
            return Path("EndpointPayloads")
        case .subtypes:
            return Path("Subtypes")
        case .support:
            return Path("Support")
        case .factories:
            return Path("Factories")
        case .doubles:
            return Path("Doubles")
        case .coreDataModel(let version):
            return OutputDirectory.support.path(appModuleName: appModuleName) + "\(appModuleName).xcdatamodeld" + "\(appModuleName)_\(version).xcdatamodel"
        case .coreDataModelVersion:
            return OutputDirectory.support.path(appModuleName: appModuleName) + "\(appModuleName).xcdatamodeld"
        case .jsonPayloads(let endpointName):
            return Path("JSONPayloads") + endpointName
        case .payloadTests:
            return Path("Payloads")
        case .coreDataTests:
            return Path("CoreData")
        case .coreDataMigrationTests:
            return Path("CoreDataMigrations")
        case .sqliteFiles:
            return Path("SQLite")
        }
    }
}
