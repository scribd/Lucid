//
//  Error.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 3/20/19.
//

// MARK: - Error

public enum CodeGenError: Error, CustomStringConvertible {
    case unsupportedType(String)
    case subtypeNotFound(String)
    case entityNotFound(String)
    case entityAddedAtVersionNotFound(String)
    case entityUIDNotFound(String)
    case endpointPayloadNotFound(String)
    case propertyNotFound(Entity, String)
    case unsupportedPayloadIdentifier
    case unsupportedMetadataIdentifier
    case unsupportedNestedKeys
    case couldNotFindTargetEntity
    case subtypeDoesNotHaveAnyCase(String)
    case cannotPersistIdentifier(String)
    case incompatiblePropertyKey(String)
    case unsupportedCaseConvertion
    case `extension`(String)
}

// MARK: - Description

public extension CodeGenError {
    
    var description: String {
        switch self {
        case .unsupportedType(let type):
            return "Unsupported type: '\(type)'."
        case .subtypeNotFound(let name):
            return "Could not find subtype named: '\(name)'."
        case .entityNotFound(let name):
            return "Could not find entity named: '\(name)'."
        case .entityUIDNotFound(let name):
            return "Could not find or infer UID for entity named: '\(name)'."
        case .entityAddedAtVersionNotFound(let name):
            return "Could not find added_at_version for entity named: '\(name)'."
        case .endpointPayloadNotFound(let name):
            return "Could not find endpoint named: '\(name)'."
        case .propertyNotFound(let entity, let name):
            return "Could not find property named: '\(name)' in entity named: '\(entity.name)'."
        case .unsupportedPayloadIdentifier:
            return "Unsupported payload identifier."
        case .unsupportedMetadataIdentifier:
            return "Unsupported metadata identifier."
        case .unsupportedNestedKeys:
            return "Nested keys with more than two levels aren't supported."
        case .couldNotFindTargetEntity:
            return "At least one entity should have the property 'isTarget' set to true."
        case .subtypeDoesNotHaveAnyCase(let name):
            return "Subtype named '\(name)' does not have any case."
        case .cannotPersistIdentifier(let name):
            return "Cannot persist identifier in entity: '\(name)'."
        case .incompatiblePropertyKey(let key):
            return "Incompatible property key: \(key)."
        case .unsupportedCaseConvertion:
            return "Unsupported case convertion."
        case .extension(let error):
            return "Extension: \(error)"
        }
    }
}
