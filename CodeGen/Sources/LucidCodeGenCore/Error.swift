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
    case endpointRequiresAtLeastOnePayload(String)
    case endpointRequiresSeparateReadAndWritePayloads(String)
    case endpointTestsRequiresAtLeastOneType
    case propertyNotFound(Entity, String)
    case unsupportedPayloadIdentifier
    case unsupportedMetadataIdentifier
    case unsupportedNestedKeys
    case couldNotFindTargetEntity
    case subtypeDoesNotHaveAnyCase(String)
    case cannotPersistIdentifier(String)
    case incompatiblePropertyKey(String)
    case unsupportedCaseConversion
    case `extension`(String)
    case systemPropertyNameCollision(String)
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
        case .endpointRequiresAtLeastOnePayload(let name):
            return "Endpoint '\(name)' requires at least one read, write, or readwrite payload."
        case .endpointRequiresSeparateReadAndWritePayloads(let name):
            return "Endpoint '\(name)' with shared 'read_write' payload cannot specify custom HTTP methods. Create separate 'read' and 'write' payloads."
        case .endpointTestsRequiresAtLeastOneType:
            return "Tests for endpoint requires at least one read or write value."
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
        case .unsupportedCaseConversion:
            return "Unsupported case conversion."
        case .extension(let error):
            return "Extension: \(error)"
        case .systemPropertyNameCollision(let propertyName):
            return "'\(propertyName)' is a reserved system property name. Please choose a different one."
        }
    }
}
