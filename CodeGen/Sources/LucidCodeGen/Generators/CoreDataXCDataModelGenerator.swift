//
//  CoreDataXCDataModelGenerator.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/18/19.
//

import PathKit
import Foundation

public final class CoreDataXCDataModelGenerator: Generator {

    public let name = "Core Data model"
    
    private let filename = "contents"

    private let version: String

    private let useCoreDataLegacyNaming: Bool

    private let descriptions: [String: Descriptions]
    
    public init(version: String,
                useCoreDataLegacyNaming: Bool,
                descriptions: [String: Descriptions]) {

        self.version = version
        self.useCoreDataLegacyNaming = useCoreDataLegacyNaming
        self.descriptions = descriptions
    }
    
    public func generate(for element: Description, in directory: Path) throws -> File? {

        guard let currentDescriptions = self.descriptions[version] else {
            fatalError("Could not find descriptions for version: \(version)")
        }
        
        guard element == .all else { return nil }
        
        let content = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="14460.32" systemVersion="18A391" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="\(version)">

        \(try currentDescriptions.entities.filter { $0.persist }.flatMap { entity -> [String] in
            return try entity.modelMappingHistory.resolve(for: entity, in: self.descriptions, currentVersion: version).map {
                try generate(for: $0, in: $1, version: $2, previousName: $3)
            }
        }.joined(separator: "\n"))
        
        </model>
        """
        
        return File(content: content, path: directory + filename)
    }
    
    private func generate(for entity: Entity, in descriptions: Descriptions, version: String, previousName: String? = nil) throws -> String {

        let elementIDText = previousName.flatMap { " elementID=\"\($0)\"" } ?? ""
        let entityCoreDataName = try entity.coreDataName(for: version, useCoreDataLegacyNaming: useCoreDataLegacyNaming)
        let entityCoreDataManagedName = try entity.coreDataEntityTypeID(for: version).swiftString
        return """
            <entity name="\(entityCoreDataName)" representedClassName="\(entityCoreDataManagedName)" syncable="YES" codeGenerationType="class"\(elementIDText)>
                <attribute name="_identifier" attributeType="\(try identifierCoreDataType(for: entity, in: descriptions))" usesScalarValueType="YES" syncable="YES" optional="YES"/>
                <attribute name="__identifier" attributeType="\(entity.hasVoidIdentifier ? "Integer 64" : "String")" usesScalarValueType="YES" syncable="YES" optional="YES"/>
                <attribute name="\(useCoreDataLegacyNaming ? "__typeUID" : "__type_uid")" attributeType="String" usesScalarValueType="YES" syncable="YES" optional="YES"/>
        \(entity.remote ?
            """
                    <attribute name="\(useCoreDataLegacyNaming ? "_remoteSynchronizationState" : "_remote_synchronization_state")" attributeType="String" syncable="YES" optional="YES"/>
            """
            : String()
        )
        \(entity.lastRemoteRead ?
            """
                    <attribute name="\(useCoreDataLegacyNaming ? "__lastRemoteRead" : "__last_remote_read")" attributeType="Date" syncable="YES" optional="NO"/>
            """
            : String()
        )
        \(try entity.usedProperties.map { property in
            let propertyCoreDataName = property.coreDataName(useCoreDataLegacyNaming: useCoreDataLegacyNaming)
            let propertyElementIDText = property.previousName.flatMap { " elementID=\"_\($0)\"" } ?? ""
            var value = String()
            if property.isRelationship && property.isArray == false {
                let _propertyElementIDText = property.previousName.flatMap { " elementID=\"__\($0)\"" } ?? ""
                let _typeUIDElementIDText = property.previousName.flatMap { " elementID=\"__\($0)\(useCoreDataLegacyNaming ? "TypeUID" : "_type_uid")\"" } ?? ""

                value += """
                        <attribute name="_\(propertyCoreDataName)" optional="YES" attributeType="\(try propertyCoreDataType(for: property, in: descriptions))" syncable="YES"\(propertyElementIDText)/>
                        <attribute name="__\(propertyCoreDataName)" optional="YES" attributeType="String" syncable="YES"\(_propertyElementIDText)/>
                        <attribute name="__\(propertyCoreDataName)\(useCoreDataLegacyNaming ? "TypeUID" : "_type_uid")" optional="YES" attributeType="String" syncable="YES"\(_typeUIDElementIDText)/>
                """
            } else {
                let optional = property.optional || property.extra
                let optionalText = optional ? " optional=\"YES\"" : ""
                let defaultValueText = property.defaultValue.flatMap { " \($0.coreDataAttributeName)=\"\($0.coreDataValue)\"" } ?? ""

                value += """
                        <attribute name="_\(propertyCoreDataName)"\(optionalText) attributeType="\(try propertyCoreDataType(for: property, in: descriptions))" \(property.propertyType.usesScalarValueType ? "usesScalarValueType=\"YES\" ": "")syncable="YES"\(propertyElementIDText)\(defaultValueText)/>
                """
            }
            if property.extra {
                value += """
                
                        <attribute name="__\(propertyCoreDataName)\(useCoreDataLegacyNaming ? "ExtraFlag" : "_extra_flag")" optional="NO" attributeType="\(PropertyScalarType.bool.coreDataType)" usesScalarValueType="YES" syncable="YES" defaultValueString="0"/>
                """
            }
            return value
        }.joined(separator: "\n"))
            </entity>
        """
    }
    
    private func identifierCoreDataType(for entity: Entity, in descriptions: Descriptions) throws -> String {
        switch entity.identifier.identifierType {
        case .property(let name):
            let property = try entity.property(for: name)
            switch property.propertyType {
            case .scalar(let scalarType):
                return scalarType.coreDataType
            case .relationship(let relationship):
                let relationshipEntity = try descriptions.entity(for: relationship.entityName)
                return try identifierCoreDataType(for: relationshipEntity, in: descriptions)
            case .array,
                 .subtype:
                throw CodeGenError.cannotPersistIdentifier(entity.name)
            }
            
        case .relationships(let type, _),
             .scalarType(let type):
            return type.coreDataType

        case .void:
            return PropertyScalarType.int.coreDataType
        }
    }
    
    private func propertyCoreDataType(for property: EntityProperty, in descriptions: Descriptions) throws -> String {
        switch property.propertyType {
        case .subtype(let name):
            let subtype = try descriptions.subtype(for: name)
            return subtype.coreDataType
        case .relationship(let relationship):
            switch relationship.association {
            case .toMany:
                return "Binary"
            case .toOne:
                let relationshipEntity = try descriptions.entity(for: relationship.entityName)
                return try identifierCoreDataType(for: relationshipEntity, in: descriptions)
            }
        case .scalar(let type):
            return type.coreDataType
        case .array:
            return "Binary"
        }
    }
}

private extension PropertyScalarType {
    
    var coreDataType: String {
        switch self {
        case .string,
             .url,
             .color:
            return "String"
        case .int,
             .bool:
            return "Integer 64"
        case .double,
             .seconds,
             .milliseconds:
            return "Double"
        case .float:
            return "Float"
        case .date:
            return "Date"
        }
    }
}

private extension Subtype {
    
    var coreDataType: String {
        switch items {
        case .cases:
            return "String"
        case .options:
            return "Integer 64"
        case .properties:
            return "Binary"
        }
    }
}

private extension DefaultValue {
    
    var coreDataAttributeName: String {
        switch self {
        case .bool,
             .float,
             .int,
             .string,
             .enumCase,
             .`nil`:
            return "defaultValueString"
        case .date,
             .currentDate:
            return "defaultDateTimeInterval"
        }
    }

    var coreDataValue: String {
        switch self {
        case .bool(let value):
            return value ? "1" : "0"
        case .float(let value):
            return value.description
        case .int(let value):
            return value.description
        case .string(let value):
            return value
        case .date(let date):
            return date.timeIntervalSince1970.description
        case .currentDate:
            return "0"
        case .enumCase(let value):
            return value
        case .`nil`:
            return "nil"
        }
    }
}

private extension Optional where Wrapped == [ModelMapping] {
    
    typealias ResolvedModelMapping = (
        entity: Entity,
        descriptions: Descriptions,
        version: String,
        previousName: String?
    )
    
    func resolve(for entity: Entity, in descriptions: [String: Descriptions], currentVersion: String) throws -> [ResolvedModelMapping] {
        guard let currentDescriptions = descriptions[currentVersion] else {
            fatalError("Could not find descriptions for version: \(currentVersion)")
        }
        
        guard let modelMappingHistory = self else {
            guard let addedAtVersion = entity.addedAtVersion else {
                fatalError("Could not find added_at_version for entity: \(entity.name)")
            }
            return [(entity: entity, descriptions: currentDescriptions, version: addedAtVersion, previousName: entity.previousName)]
        }
        
        var mappings = [ResolvedModelMapping]()
        
        for (index, mapping) in modelMappingHistory.enumerated() {
            let previousMapping = index > 0 ? modelMappingHistory[index - 1] : nil
            if previousMapping != nil {
                mappings.removeLast()
            }
            
            guard let fromDescriptions = descriptions[mapping.from] else {
                fatalError("Could not find descriptions for version: \(mapping.from)")
            }

            let fromEntity = try fromDescriptions.entity(for: entity.name)

            mappings.append((
                entity: fromEntity,
                descriptions: fromDescriptions,
                version: mapping.from,
                previousName: nil
            ))

            mappings.append((
                entity: entity,
                descriptions: currentDescriptions,
                version: mapping.to,
                previousName: nil
            ))
        }
        
        return mappings
    }
}
