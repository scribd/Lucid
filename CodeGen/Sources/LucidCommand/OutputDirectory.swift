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
    case localEntities
    case compositeEntities
    case payloads
    case endpointPayloads
    case alternateEndpointPayloads
    case subtypes
    case additional
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
        case .localEntities:
            return Path("LocalEntities")
        case .compositeEntities:
            return Path("CompositeEntities")
        case .payloads:
            return Path("Payloads")
        case .endpointPayloads:
            return Path("EndpointPayloads")
        case .alternateEndpointPayloads:
            return Path("AlternateEndpointPayloads")
        case .subtypes:
            return Path("Subtypes")
        case .additional:
            return Path("AdditionalFiles")
        case .factories:
            return Path("Factories")
        case .doubles:
            return Path("Doubles")
        case .coreDataModel(let version):
            return OutputDirectory.additional.path(appModuleName: appModuleName) + "\(appModuleName).xcdatamodeld" + "\(appModuleName)_\(version).xcdatamodel"
        case .coreDataModelVersion:
            return OutputDirectory.additional.path(appModuleName: appModuleName) + "\(appModuleName).xcdatamodeld"
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
