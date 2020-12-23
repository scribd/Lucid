//
//  Constants.swift
//  LucidCommand
//
//  Created by Théophane Rupin on 1/31/19.
//

import Foundation
import LucidCodeGenCore
import PathKit

extension OutputDirectory {
    
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
            return OutputDirectory.support.path(appModuleName: appModuleName) + "\(appModuleName).xcdatamodeld" + "\(appModuleName)_\(version.dotDescription).xcdatamodel"
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
        case .extensions(let path):
            return Path("Extensions") + path
        }
    }
}
