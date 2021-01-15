//
//  MetaUtils.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 3/22/19.
//

import Meta
import Foundation

// MARK: - Type Checking

public extension TypeIdentifier {
    
    var isArray: Bool {
        return arrayElement != nil
    }
    
    var arrayElement: TypeIdentifier? {
        if name == .array || name == TypeIdentifier.anySequence().name {
            return genericParameters.first
        } else if wrapped?.name == .array || wrapped?.name == TypeIdentifier.anySequence().name {
            return wrapped?.genericParameters.first
        } else {
            return nil
        }
    }
    
    var arrayElementOrSelf: TypeIdentifier {
        return arrayElement ?? self
    }
    
    var isOptional: Bool {
        return wrapped != nil
    }

    var isLazy: Bool {
        return name == .custom("Lazy")
    }

    var isOptionalOrLazy: Bool {
        return isOptional || isLazy
    }

    var wrapped: TypeIdentifier? {
        if name == .optional {
            return genericParameters.first
        } else {
            return nil
        }
    }
    
    var wrappedOrSelf: TypeIdentifier {
        return wrapped ?? self
    }
    
    var isDictionary: Bool {
        return name == .dictionary ||
            name.string == TypeIdentifier.dualHashDictionary().name.string ||
            name.string == TypeIdentifier.orderedDualHashDictionary().name.string
    }
}

// MARK: - Static Imports

public extension Import {
    
    static var xcTest: Import {
        return Import(name: "XCTest", testable: false)
    }
    
    static var lucid: Import {
        return Import(name: "Lucid", testable: false)
    }
    
    static var lucidTestKit: Import {
        return Import(name: "LucidTestKit", testable: false)
    }
    
    static func app(_ descriptions: Descriptions, testable: Bool = false) -> Import {
        return Import(name: descriptions.targets.app.moduleName, testable: testable)
    }
    
    static func appTestKit(_ descriptions: Descriptions) -> Import {
        return Import(name: descriptions.targets.appTestSupport.moduleName, testable: true)
    }
    
    static var reactiveKit: Import {
        return Import(name: "ReactiveKit")
    }

    static var combine: Import {
        return Import(name: "Combine")
    }
}

// MARK: - Static TypeIdentifiers

public extension TypeIdentifier {
    
    static var coreDataIdentifier: TypeIdentifier {
        return TypeIdentifier(name: "CoreDataIdentifier")
    }
    
    static var entityIdentifier: TypeIdentifier {
        return TypeIdentifier(name: "EntityIdentifier")
    }
    
    static var entityIdentifiable: TypeIdentifier {
        return TypeIdentifier(name: "EntityIdentifiable")
    }
    
    static var voidEntityIdentifier: TypeIdentifier {
        return TypeIdentifier(name: "VoidEntityIdentifier")
    }
    
    static var voidMetadata: TypeIdentifier {
        return TypeIdentifier(name: "VoidMetadata")
    }
    
    static var rawIdentifiable: TypeIdentifier {
        return TypeIdentifier(name: "RawIdentifiable")
    }
    
    static var remoteIdentifier: TypeIdentifier {
        return TypeIdentifier(name: "RemoteIdentifier")
    }
    
    static var failableValue: TypeIdentifier {
        return TypeIdentifier(name: "FailableValue")
    }
    
    static func failableValue(of type: TypeIdentifier? = nil) -> TypeIdentifier {
        return failableValue.adding(genericParameter: type)
    }

    static var lazyValue: TypeIdentifier {
        return TypeIdentifier(name: "Lazy")
    }

    static func lazyValue(of type: TypeIdentifier? = nil) -> TypeIdentifier {
        return lazyValue.adding(genericParameter: type)
    }

    static var payloadRelationship: TypeIdentifier {
        return TypeIdentifier(name: "PayloadRelationship")
    }
    
    static func payloadRelationship(of type: TypeIdentifier? = nil) -> TypeIdentifier {
        return payloadRelationship.adding(genericParameter: type)
    }
    
    static func orderedDualHashDictionary(key: TypeIdentifier? = nil, value: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "OrderedDualHashDictionary")
            .adding(genericParameter: key)
            .adding(genericParameter: value)
    }
    
    static func dualHashDictionary(key: TypeIdentifier? = nil, value: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "DualHashDictionary")
            .adding(genericParameter: key)
            .adding(genericParameter: value)
    }

    static func dualHashSet(element: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "DualHashSet")
            .adding(genericParameter: element)
    }

    static var localEntity: TypeIdentifier {
        return TypeIdentifier(name: "LocalEntity")
    }

    static var remoteEntity: TypeIdentifier {
        return TypeIdentifier(name: "RemoteEntity")
    }
    
    static var entity: TypeIdentifier {
        return TypeIdentifier(name: "Entity")
    }

    static var mutableEntity: TypeIdentifier {
        return TypeIdentifier(name: "MutableEntity")
    }

    static var entityIndexValue: TypeIdentifier {
        return TypeIdentifier(name: "EntityIndexValue")
            .adding(genericParameter: .entityRelationshipIdentifier)
            .adding(genericParameter: .entitySubtype)
    }

    static var coreDataIndexName: TypeIdentifier {
        return TypeIdentifier(name: "CoreDataIndexName")
    }
    
    static var coreDataEntity: TypeIdentifier {
        return TypeIdentifier(name: "CoreDataEntity")
    }
    
    static var managedObject: TypeIdentifier {
        return TypeIdentifier(name: "NSManagedObject")
    }
    
    static var coreDataConversionError: TypeIdentifier {
        return TypeIdentifier(name: "CoreDataConversionError")
    }
    
    static var equatable: TypeIdentifier {
        return TypeIdentifier(name: "Equatable")
    }
    
    static var encodable: TypeIdentifier {
        return TypeIdentifier(name: "Encodable")
    }
    
    static var decodable: TypeIdentifier {
        return TypeIdentifier(name: "Decodable")
    }

    static var codable: TypeIdentifier {
        return TypeIdentifier(name: "Codable")
    }

    static var decoder: TypeIdentifier {
        return TypeIdentifier(name: "Decoder")
    }

    static var encoder: TypeIdentifier {
        return TypeIdentifier(name: "Encoder")
    }

    static var jsonDecoder: TypeIdentifier {
        return TypeIdentifier(name: "JSONDecoder")
    }

    static var jsonEncoder: TypeIdentifier {
        return TypeIdentifier(name: "JSONEncoder")
    }

    static var payloadIdentifierDecodableKeyProvider: TypeIdentifier {
        return TypeIdentifier(name: "PayloadIdentifierDecodableKeyProvider")
    }
    
    static var entityMetadata: TypeIdentifier {
        return TypeIdentifier(name: "EntityMetadata")
    }
    
    static var payloadConvertable: TypeIdentifier {
        return TypeIdentifier(name: "PayloadConvertable")
    }
    
    static var codingKey: TypeIdentifier {
        return TypeIdentifier(name: "CodingKey")
    }
    
    static var endpointMetadata: TypeIdentifier {
        return TypeIdentifier(name: "EndpointMetadata")
    }

    static var endpointResultPayload: TypeIdentifier {
        return TypeIdentifier(name: "EndpointResultPayload")
    }

    static var resultPayload: TypeIdentifier {
        return TypeIdentifier(name: "ResultPayload")
    }
    
    static var resultPayloadConvertible: TypeIdentifier {
        return TypeIdentifier(name: "ResultPayloadConvertible")
    }

    static var endpoint: TypeIdentifier {
        return TypeIdentifier(name: "Endpoint")
    }
    
    static var endpointResultMetadata: TypeIdentifier {
        return TypeIdentifier(name: "EndpointResultMetadata")
    }
    
    static var endpointResultPayloadError: TypeIdentifier {
        return TypeIdentifier(name: "EndpointResultPayloadError")
    }
    
    static var hashable: TypeIdentifier {
        return TypeIdentifier(name: "Hashable")
    }
    
    static var anyHashable: TypeIdentifier {
        return TypeIdentifier(name: "AnyHashable")
    }
    
    static var comparable: TypeIdentifier {
        return TypeIdentifier(name: "Comparable")
    }

    static var caseIterable: TypeIdentifier {
        return TypeIdentifier(name: "CaseIterable")
    }
    
    static var optionSet: TypeIdentifier {
        return TypeIdentifier(name: "OptionSet")
    }
    
    static var logger: TypeIdentifier {
        return TypeIdentifier(name: "Logger")
    }
    
    static var sequence: TypeIdentifier {
        return TypeIdentifier(name: "Sequence")
    }
    
    static var entityRelationshipIdentifier: TypeIdentifier {
        return TypeIdentifier(name: "EntityRelationshipIdentifier")
    }
    
    static var entitySubtype: TypeIdentifier {
        return TypeIdentifier(name: "EntitySubtype")
    }
    
    static var queryContext: TypeIdentifier {
        return TypeIdentifier(name: "QueryContext")
    }
    
    static var never: TypeIdentifier {
        return TypeIdentifier(name: "Never")
    }

    static func coreManager(of typeID: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "CoreManager")
            .adding(genericParameter: typeID)
    }

    static func coreManaging(of typeID: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "CoreManaging")
            .adding(genericParameter: typeID)
            .adding(genericParameter: typeID != nil ? .appAnyEntity : nil)
    }
    
    static func storing(of typeID: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "Storing")
            .adding(genericParameter: typeID)
    }
    
    static var coreManagerContainer: TypeIdentifier {
        return TypeIdentifier(name: "CoreManagerContainer")
    }
        
    static var coreManagerResolver: TypeIdentifier {
        return TypeIdentifier(name: "CoreManagerResolver")
    }
    
    static var apiClient: TypeIdentifier {
        return TypeIdentifier(name: "APIClient")
    }

    static var coreDataManager: TypeIdentifier {
        return TypeIdentifier(name: "CoreDataManager")
    }
    
    static func lruStore(of typeID: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "LRUStore")
            .adding(genericParameter: typeID)
    }

    static func cacheStore(of typeID: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "CacheStore")
            .adding(genericParameter: typeID)
    }

    static func inMemoryStore(of typeID: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "InMemoryStore")
            .adding(genericParameter: typeID)
    }
    
    static func coreDataStore(of typeID: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "CoreDataStore")
            .adding(genericParameter: typeID)
    }
    
    static func remoteStore(of typeID: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "RemoteStore")
            .adding(genericParameter: typeID)
    }
    
    static var xcTestCase: TypeIdentifier {
        return TypeIdentifier(name: "XCTestCase")
    }
    
    static var color: TypeIdentifier {
        return TypeIdentifier(name: "Color")
    }
    
    static var date: TypeIdentifier {
        return TypeIdentifier(name: "Date")
    }
    
    static var url: TypeIdentifier {
        return TypeIdentifier(name: "URL")
    }
    
    static var localValueType: TypeIdentifier {
        return TypeIdentifier(name: "LocalValueType")
    }
    
    static var remoteValueType: TypeIdentifier {
        return TypeIdentifier(name: "RemoteValueType")
    }
    
    static func identifierValueType(of remoteValueTypeID: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "IdentifierValueType")
            .adding(genericParameter: remoteValueTypeID != nil ? .string : nil)
            .adding(genericParameter: remoteValueTypeID)
    }
    
    static var uuid: TypeIdentifier {
        return TypeIdentifier(name: "UUID")
    }
    
    static var anyCoreDataRelationshipIdentifier: TypeIdentifier {
        return TypeIdentifier(name: "AnyCoreDataRelationshipIdentifier")
    }

    static var anyCoreDataSubtype: TypeIdentifier {
        return TypeIdentifier(name: "AnyCoreDataSubtype")
    }
    
    static var dualHasher: TypeIdentifier {
        return TypeIdentifier(name: "DualHasher")
    }
    
    static func propertyBox(of typeID: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "PropertyBox")
            .adding(genericParameter: typeID)
    }
    
    static var nsObject: TypeIdentifier {
        return TypeIdentifier(name: "NSObject")
    }
    
    static var nsNumber: TypeIdentifier {
        return TypeIdentifier(name: "NSNumber")
    }
    
    static var remoteSynchronizationState: TypeIdentifier {
        return TypeIdentifier(name: "RemoteSynchronizationState")
    }
    
    static var entityIdentifierCodingKeys: TypeIdentifier {
        return TypeIdentifier(name: "EntityIdentifierCodingKeys")
    }
    
    static var comparableRawRepresentable: TypeIdentifier {
        return TypeIdentifier(name: "ComparableRawRepresentable")
    }
    
    static var arrayConvertable: TypeIdentifier {
        return TypeIdentifier(name: "ArrayConvertable")
    }
    
    static func anySequence(element: TypeIdentifier? = nil) -> TypeIdentifier {
        return TypeIdentifier(name: "AnySequence")
            .adding(genericParameter: element)
    }
    
    static var entityGraph: TypeIdentifier {
        return TypeIdentifier(name: "EntityGraph")
    }
    
    static var mutableGraph: TypeIdentifier {
        return TypeIdentifier(name: "MutableGraph")
    }
    
    static var appAnyEntity: TypeIdentifier {
        return TypeIdentifier(name: "AppAnyEntity")
    }
    
    static var relationshipCoreManaging: TypeIdentifier {
        return TypeIdentifier(name: "RelationshipCoreManaging")
    }

    static var remoteStoreCachePayloadPersistenceManaging: TypeIdentifier {
        return TypeIdentifier(name: "RemoteStoreCachePayloadPersistenceManaging")
    }
    
    static var anyRelationshipIdentifierConvertible: TypeIdentifier {
        return TypeIdentifier(name: "AnyRelationshipIdentifierConvertible")
    }

    static var anyResultPayloadConvertible: TypeIdentifier {
        return TypeIdentifier(name: "AnyResultPayloadConvertible")
    }
    
    static var cacheStrategy: TypeIdentifier {
        return TypeIdentifier(name: "CacheStrategy")
    }
    
    static func signal(of valueType: TypeIdentifier? = nil,
                       error errorType: TypeIdentifier? = nil) -> TypeIdentifier {

        return TypeIdentifier(name: "Signal")
            .adding(genericParameter: valueType)
            .adding(genericParameter: errorType)
    }

    static func anyPublisher(of valueType: TypeIdentifier? = nil,
                             error errorType: TypeIdentifier? = nil) -> TypeIdentifier {

        return TypeIdentifier(name: "AnyPublisher")
            .adding(genericParameter: valueType)
            .adding(genericParameter: errorType)
    }
    
    static var managerError: TypeIdentifier {
        return TypeIdentifier(name: "ManagerError")
    }
    
    static var appAnyEntityIndexName: TypeIdentifier {
        return TypeIdentifier(name: "AppAnyEntityIndexName")
    }

    static var appAnyRelationshipPath: TypeIdentifier {
        return TypeIdentifier(name: "AppAnyRelationshipPath")
    }

    static var entityIndexing: TypeIdentifier {
        return TypeIdentifier(name: "EntityIndexing")
    }
    
    static var entityConvertible: TypeIdentifier {
        return TypeIdentifier(name: "EntityConvertible")
    }
    
    static var subtypeFactory: TypeIdentifier {
        return TypeIdentifier(name: "SubtypeFactory")
    }

    static var userAccessValidating: TypeIdentifier {
        return TypeIdentifier(name: "UserAccessValidating")
    }

    static var queryResultConvertible: TypeIdentifier {
        return TypeIdentifier(name: "QueryResultConvertible")
    }

    static var relationshipPathConvertible: TypeIdentifier {
        return TypeIdentifier(name: "RelationshipPathConvertible")
    }
}

// MARK: - Static References

public extension Reference {
    
    static func array(with values: [VariableValue] = [], ofType typeID: TypeIdentifier? = nil) -> Reference {
        let arrayTypeID: TypeIdentifier
        if let typeID = typeID, values.isEmpty == false {
            arrayTypeID = .array(element: typeID)
        } else {
            arrayTypeID = TypeIdentifier(name: .array)
        }
        return arrayTypeID.reference | .call(Tuple()
            .with(parameters: values.enumerated().map { offset, value in
                return offset > 0 ? TupleParameter(value: value) : TupleParameter(name: "arrayLiteral", value: value)
            })
        )
    }
    
    static func array(withArrayValue value: Reference, ofType typeID: TypeIdentifier? = nil) -> Reference {
        let arrayTypeID: TypeIdentifier
        if let typeID = typeID {
            arrayTypeID = .array(element: typeID)
        } else {
            arrayTypeID = TypeIdentifier(name: .array)
        }
        return arrayTypeID.reference | .call(Tuple()
            .adding(parameter: TupleParameter(value: value))
        )
    }
    
    func container(keyedBy keyType: TypeIdentifier) -> Reference {
        return .try | self + .named("container") | .call(Tuple()
            .adding(parameter: TupleParameter(name: "keyedBy", value: keyType.reference + .named(.`self`)))
        )
    }
    
    static func orderedDualHashDictionary() -> Reference {
        return TypeIdentifier.orderedDualHashDictionary().reference | .call()
    }
    
    static func logError(from typeID: TypeIdentifier, message: String, assert: Bool) -> Reference {
        return TypeIdentifier.logger.reference + .named("log") | .call(Tuple()
            .adding(parameter: TupleParameter(value: +.named("error")))
            .adding(parameter: TupleParameter(value: Value.string("\\(\(typeID.name.string).self): \(message)")))
            .adding(parameter: TupleParameter(name: "domain", value: Value.string("Lucid")))
            .adding(parameter: TupleParameter(name: "assert", value: Value.bool(true)))
        )
    }

    static var lazyValue: Reference {
        return .named("value")
    }
}

// MARK: - Static Functions

public extension Function {
    
    static var initFromDecoder: Function {
        return Function(kind: .`init`)
            .with(throws: true)
            .adding(parameter: FunctionParameter(alias: "from", name: "decoder", type: .decoder))
    }
    
    static var encode: Function {
        return Function(kind: .named("encode"))
            .with(throws: true)
            .adding(parameter: FunctionParameter(alias: "to", name: "encoder", type: .encoder))
    }
}

// MARK: - Entity

public extension Entity {

    var transformedName: String {
        return name.camelCased().suffixedName()
    }
    
    func typeID(objc: Bool = false) -> TypeIdentifier {
        return TypeIdentifier(name: objc ? "SC\(transformedName)Objc" : transformedName)
    }

    func identifierTypeID(objc: Bool = false) -> TypeIdentifier {
        return hasVoidIdentifier ? .voidEntityIdentifier : TypeIdentifier(name: objc ? "SC\(transformedName)IdentifierObjc" : "\(transformedName)Identifier")
    }

    var migrationCheckpoints: [Version] {
        var checkpoints = [Version]()
        for historyItem in versionHistory {
            if checkpoints.isEmpty {
                checkpoints.append(historyItem.version)
            } else if historyItem.ignoreMigrationChecks {
                checkpoints.append(historyItem.version)
            }
        }
        return checkpoints
    }

    func remoteIdentifierValueTypeID(_ descriptions: Descriptions, persist: Bool = false) throws -> TypeIdentifier {
        switch identifier.identifierType {
        case .void:
            return .void
        case .scalarType(let type),
             .relationships(let type, _):
            return type.typeID(persist: persist)
        case .property(let name):
            let property = try self.property(for: name)
            return try property.remoteIdentifierValueTypeID(descriptions, persist: persist)
        }
    }

    func identifierValueTypeID(_ descriptions: Descriptions, persist: Bool = false) throws -> TypeIdentifier {
        return .identifierValueType(of: try remoteIdentifierValueTypeID(descriptions, persist: persist))
    }
    
    var identifiableTypeID: TypeIdentifier {
        return TypeIdentifier(name: "\(transformedName)Identifiable")
    }
    
    var identifierVariable: Variable {
        return Variable(name: "\(transformedName.variableCased())Identifier")
    }
    
    func indexNameTypeID(_ descriptions: Descriptions) throws -> TypeIdentifier {
        let hasIndices = try self.hasIndices(descriptions)
        return hasIndices ? TypeIdentifier(name: "\(transformedName)IndexName") : TypeIdentifier(name: "VoidIndexName")
    }

    func relationshipIndexNameTypeID(_ descriptions: Descriptions) throws -> TypeIdentifier {
        let hasIndices = try self.hasRelationshipIndices(descriptions)
        return hasIndices ?
            TypeIdentifier(name: "\(transformedName)RelationshipIndexName") :
            TypeIdentifier(name: "VoidRelationshipIndexName").adding(genericParameter: .appAnyEntity)
    }

    func coreDataEntityTypeID(for version: Version? = nil) throws -> TypeIdentifier {
        guard let version = version ?? versionHistory.last?.version else {
            throw CodeGenError.entityAddedAtVersionNotFound(name)
        }
        return TypeIdentifier(name: "Managed\(name.camelCased().suffixedName())_\(version.sqlDescription)")
    }

    var hasVoidIdentifier: Bool {
        return identifier.identifierType == .void
    }

    var requiresCustomShouldOverwriteFunction: Bool {
        return inheritenceType.isLocal
            && systemProperties.contains(where: { $0.requiresCustomShouldOverwriteFunction })
    }
}

public extension Entity {

    enum InheritanceType {
        case localAndRemote
        case local
        case remote
        case basic
    }

    var inheritenceType: InheritanceType {
        if persist && remote {
            return .localAndRemote
        } else if persist {
            return .local
        } else if remote {
            return .remote
        } else {
            return .basic
        }
    }
}

public extension Entity.InheritanceType {

    var isLocal: Bool {
        switch self {
        case .localAndRemote, .local: return true
        case .remote, .basic: return false
        }
    }

    var isRemote: Bool {
        switch self {
        case .localAndRemote, .remote: return true
        case .local, .basic: return false
        }
    }

    var isBasic: Bool {
        switch self {
        case .basic: return true
        case .localAndRemote, .local, .remote: return false
        }
    }
}

public extension Entity {
    
    func isIdentifierStoredAsOptional(_ descriptions: Descriptions) throws -> Bool {
        switch identifier.identifierType {
        case .void:
            return false
        case .property(let name):
            let property = try self.property(for: name)
            return try property.propertyType.isStoredAsOptional(descriptions)
        case .relationships(let type, _),
             .scalarType(let type):
            return type.isStoredAsOptional
        }
    }
    
    func indices(_ descriptions: Descriptions) throws -> [EntityProperty] {
        return try usedProperties.filter { try $0.propertyType.isIndexSearchable(descriptions) } + systemProperties.map { $0.property }
    }

    var reference: Reference {
        return .named(transformedName)
    }
}

public extension EntityProperty {

    func transformedName(ignoreLexicon: Bool = true) -> String {
        return name
            .split(separator: ".")
            .map { String($0).camelCased().variableCased(ignoreLexicon: ignoreLexicon) }
            .joined(separator: "_")
    }

    var variable: Variable {
        return Variable(name: transformedName())
    }
    
    var entityVariable: Variable {
        return Variable(name: transformedName())
    }
    
    func remoteIdentifierValueTypeID(_ descriptions: Descriptions, persist: Bool) throws -> TypeIdentifier {
        return try propertyType.remoteIdentifierValueTypeID(descriptions, persist: persist)
    }
    
    func valueTypeID(_ descriptions: Descriptions, objc: Bool = false, includeLazy: Bool = true) throws -> TypeIdentifier {
        var typeID = try propertyType.valueTypeID(descriptions, objc: objc)

        if objc {
            let isEnumSubtype = try propertyType.subtype(descriptions)?.isEnum ?? false
            if isEnumSubtype {
                return typeID
            } else if nullable, let optionalObjcTypeID = propertyType.scalarType?.objcOptionableTypeID {
                typeID = optionalObjcTypeID
            }
        }

        let rootTypeID = nullable ? .optional(wrapped: typeID) : typeID
        return (lazy && includeLazy) ? .lazyValue(of: rootTypeID) : rootTypeID
    }
    
    var reference: Reference {
        return .named(transformedName())
    }

    var referenceValue: Reference {
        return lazy ? reference + .lazyValue | .call() : reference
    }

    var entityReference: Reference {
        return .named(transformedName())
    }

    var entityReferenceValue: Reference {
        return lazy ? entityReference + .lazyValue | .call() : entityReference
    }
}

public extension EntityProperty.PropertyType {
    
    func remoteIdentifierValueTypeID(_ descriptions: Descriptions, persist: Bool) throws -> TypeIdentifier {
        switch self {
        case .subtype(let name):
            return TypeIdentifier(name: name.camelCased().suffixedName())
        case .scalar(let scalarType):
            return scalarType.typeID(persist: persist)
        case .relationship(let relationship):
            return try relationship.remoteIdentifierValueTypeID(descriptions, persist: persist)
        case .array(let propertyType):
            return .anySequence(element: try propertyType.remoteIdentifierValueTypeID(descriptions, persist: persist))
        }
    }
    
    fileprivate func valueTypeID(_ descriptions: Descriptions, objc: Bool) throws -> TypeIdentifier {
        switch self {
        case .scalar(let type):
            return type.typeID(objc: objc)
        case .subtype(let name):
            let subtype = try descriptions.subtype(for: name)
            return subtype.typeID(objc: objc)
        case .relationship(let relationship):
            return try relationship.identifierTypeID(descriptions, objc: objc)
        case .array(let type) where objc == false:
            return .anySequence(element: try type.valueTypeID(descriptions, objc: objc))
        case .array(let type):
            return .array(element: try type.valueTypeID(descriptions, objc: objc))
        }
    }
    
    func isStoredAsOptional(_ descriptions: Descriptions) throws -> Bool {
        switch self {
        case .scalar(let type):
            return type.isStoredAsOptional
        case .relationship(let relationship):
            return try relationship.isStoredAsOptional(descriptions)
        case .array:
            return true
        case .subtype(let name):
            let subtype = try descriptions.subtype(for: name)
            return subtype.isStoredAsOptional
        }
    }
    
    func isIndexSearchable(_ descriptions: Descriptions) throws -> Bool {
        switch self {
        case .subtype(let name):
            let subtype = try descriptions.subtype(for: name)
            return subtype.isStruct == false
        case .array(.subtype):
            return false
        case .relationship,
             .scalar,
             .array:
            return true
        }
    }
}

// MARK: - Relationships

public extension EntityRelationship {
    
    func remoteIdentifierValueTypeID(_ descriptions: Descriptions, persist: Bool) throws -> TypeIdentifier {
        let entity = try descriptions.entity(for: entityName)
        let remoteIdentifierValueTypeID = try entity.remoteIdentifierValueTypeID(descriptions, persist: persist)
        return association == .toMany ? .anySequence(element: remoteIdentifierValueTypeID) : remoteIdentifierValueTypeID
    }
    
    func identifierTypeID(_ descriptions: Descriptions, objc: Bool = false) throws -> TypeIdentifier {
        let entity = try descriptions.entity(for: entityName)
        if objc == false {
            return association == .toMany ? .anySequence(element: entity.identifierTypeID(objc: objc)) : entity.identifierTypeID(objc: objc)
        } else {
            return association == .toMany ? .array(element: entity.identifierTypeID(objc: objc)) : entity.identifierTypeID(objc: objc)
        }
    }
    
    var reference: Reference {
        return entityName.camelCased().suffixedName().reference
    }
    
    func isStoredAsOptional(_ descriptions: Descriptions) throws -> Bool {
        switch association {
        case .toMany:
            return true
        case .toOne:
            let relationshipEntity = try descriptions.entity(for: entityName)
            return try relationshipEntity.isIdentifierStoredAsOptional(descriptions)
        }
    }
}

// MARK: - ScalarType

public extension PropertyScalarType {
    
    func typeID(persist: Bool = false, objc: Bool = false) -> TypeIdentifier {
        if objc {
            switch self {
            case .color:
                return TypeIdentifier(name: "SC\(rawValue)Objc")
            case .seconds,
                 .milliseconds:
                return TypeIdentifier(name: "SCTimeObjc")
            default:
                break
            }
        }
        guard persist else {
            return TypeIdentifier(name: rawValue)
        }
        switch self {
        case .string:
            return .string
        case .color,
             .seconds,
             .milliseconds,
             .double:
            return .double
        case .float:
            return .float
        case .int,
             .date,
             .bool:
            return .int64
        case .url:
            return .string
        }
    }
    
    var objcOptionableTypeID: TypeIdentifier {
        switch self {
        case .string,
             .url,
             .color,
             .date,
             .seconds,
             .milliseconds:
            return self.typeID(objc: true)
        case .bool,
             .double,
             .float,
             .int:
            return .nsNumber
        }
    }
    
    var reference: Reference {
        switch self {
        case .string:
            return .named("string")
        case .int:
            return .named("int")
        case .date:
            return .named("date")
        case .double:
            return .named("double")
        case .float:
            return .named("float")
        case .bool:
            return .named("bool")
        case .seconds:
            return .named("seconds")
        case .milliseconds:
            return .named("milliseconds")
        case .url:
            return .named("url")
        case .color:
            return .named("color")
        }
    }
}

public extension PropertyScalarType {
    
    var usesScalarValueType: Bool {
        switch self {
        case .string,
             .url,
             .color,
             .date:
            return false
        case .int,
             .bool,
             .double,
             .seconds,
             .milliseconds,
             .float:
            return true
        }
    }
    
    var isStoredAsOptional: Bool {
        return usesScalarValueType == false
    }
}

public extension EntityProperty.PropertyType {
    
    var usesScalarValueType: Bool {
        switch self {
        case .subtype,
             .array,
             .relationship:
            return false
        case .scalar(let value):
            return value.usesScalarValueType
        }
    }
}

// MARK: - Subtypes

public extension Subtype {
    
    func typeID(objc: Bool = false) -> TypeIdentifier {
        let name = self.name.camelCased().suffixedName()
        return TypeIdentifier(name: objc ? "SC\(name)Objc" : name)
    }
    
    var isStoredAsOptional: Bool {
        switch items {
        case .cases,
             .properties:
            return true
        case .options:
            return false
        }
    }
    
    func needsObjcNoneCase(_ descriptions: Descriptions) throws -> Bool {
        return try descriptions.entities.contains { entity in
            try entity.usedProperties.contains { property in
                guard try property.propertyType.subtype(descriptions)?.name == name else {
                    return false
                }
                return property.nullable || property.lazy
            }
        }
    }
}

public extension Subtype.Property {
    
    func typeID(objc: Bool = false) -> TypeIdentifier {
        let typeID = propertyType.typeID(objc: objc)
        if nullable {
            return .optional(wrapped: typeID)
        } else {
            return typeID
        }
    }
}

public extension Subtype.Property.PropertyType {
    
    func typeID(objc: Bool = false) -> TypeIdentifier {
        switch self {
        case .scalar(let type):
            return type.typeID(objc: objc)
        case .custom(let name):
            let name = name.camelCased().suffixedName()
            return TypeIdentifier(name: objc ? "SC\(name)Objc" : name)
        }
    }
}

// MARK: - Lazy

public extension Entity {

    func hasIndices(_ descriptions: Descriptions) throws -> Bool {
        return try indices(descriptions).isEmpty == false
    }

    func hasRelationshipIndices(_ descriptions: Descriptions) throws -> Bool {
        return try indices(descriptions).contains { $0.isRelationship }
    }

    func hasRelationshipLoop(_ descriptions: Descriptions) throws -> Bool {
        var visitedEntities = Set<String>()
        func hasLoop(for entityName: String) throws -> Bool {
            guard visitedEntities.contains(entityName) == false else { return true }
            visitedEntities.insert(entityName)
            let entity = try descriptions.entity(for: entityName)
            return try entity.indices(descriptions).contains { property in
                guard let relationship = property.relationship else { return false }
                return try hasLoop(for: relationship.entityName)
            }
        }
        return try hasLoop(for: name)
    }

    func hasAnyLazy(_ descriptions: Descriptions, _ parsedEntities: [String: Bool] = [:]) throws -> Bool {

        if let preparsedResult = parsedEntities[name] {
            return preparsedResult
        }

        let updatedEntities = parsedEntities.merging([name: hasLazyProperties]) { _, new in new }
        let hasLazyRelationships = try properties.contains { try $0.hasLazyRelationships(descriptions, updatedEntities) }

        return hasLazyProperties || hasLazyRelationships
    }

    var hasLazyProperties: Bool {
        return properties.contains { $0.lazy }
    }
}

public extension EntityProperty {

    func hasAnyLazy(_ descriptions: Descriptions, _ parsedEntities: [String: Bool] = [:]) throws -> Bool {
        return try lazy || hasLazyRelationships(descriptions, parsedEntities)
    }

    func hasLazyRelationships(_ descriptions: Descriptions, _ parsedEntities: [String: Bool] = [:]) throws -> Bool {
        if let relationship = self.relationship, relationship.idOnly == false {
            let entity = try descriptions.entity(for: relationship.entityName)
            return try entity.hasAnyLazy(descriptions, parsedEntities)
        } else {
            return false
        }
    }
}

// MARK: - Payloads

public extension Entity {
    
    var payloadTypeID: TypeIdentifier {
        return TypeIdentifier(name: "\(transformedName)Payload")
    }
    
    var requestPayloadTypeID: TypeIdentifier {
        return TypeIdentifier(name: "\(transformedName)RequestPayload")
    }
    
    var defaultEndpointPayloadTypeID: TypeIdentifier {
        return TypeIdentifier(name: "DefaultEndpoint\(transformedName)Payload")
    }
    
    var payloadIdentifierTypeID: TypeIdentifier? {
        switch identifier.identifierType {
        case .scalarType(let type):
            return type.typeID()
        case .void,
             .property,
             .relationships:
            return nil
        }
    }
    
    func payloadIdentifierValueReference() throws -> Reference {
        switch identifier.identifierType {
        case .scalarType:
            return .named("id")
        case .property(let name):
            let property = try self.property(for: name)
            if property.isRelationship {
                return .named("\(property.payloadName)") + .named("identifier") + .named("value")
            } else {
                return .named(name.camelCased().variableCased())
            }
        case .void,
             .relationships:
            throw CodeGenError.unsupportedPayloadIdentifier
        }
    }
    
    func payloadIdentifierReference() throws -> Reference {
        switch identifier.identifierType {
        case .scalarType:
            return +.named("remote") | .call(Tuple()
                .adding(parameter: TupleParameter(value: try payloadIdentifierValueReference()))
                .adding(parameter: TupleParameter(value: Value.nil))
            )
        case .property(let name):
            let property = try self.property(for: name)
            if property.isRelationship {
                return try payloadIdentifierValueReference()
            } else {
                return +.named("remote") | .call(Tuple()
                    .adding(parameter: TupleParameter(value: try payloadIdentifierValueReference()))
                    .adding(parameter: TupleParameter(value: Value.nil))
                )
            }
        case .void,
             .relationships:
            throw CodeGenError.unsupportedPayloadIdentifier
        }
    }
    
    var hasPayloadIdentifier: Bool {
        switch identifier.identifierType {
        case .scalarType:
            return true
        case .property(let name):
            return relationships.contains { $0.name == name } == false
        case .void,
             .relationships:
            return false
        }
    }
        
    var payloadEntityAccessorVariable: Variable {
        return Variable(name: name.camelCased().variableCased().pluralName)
    }
}

public extension EntityIdentifier {
    
    func payloadVariable(ignoreLexicon: Bool = false) throws -> Variable {
        guard let value: Variable = payloadVariable(ignoreLexicon: ignoreLexicon) else {
            throw CodeGenError.unsupportedPayloadIdentifier
        }
        return value
    }
    
    func payloadVariable(ignoreLexicon: Bool = false) -> Variable? {
        switch identifierType {
        case .scalarType:
            return Variable(name: "id")
        case .property(let name):
            return Variable(name: name.camelCased(ignoreLexicon: ignoreLexicon).variableCased(ignoreLexicon: true))
        case .void,
             .relationships:
            return nil
        }
    }
}

public extension EntityProperty {
    
    var payloadName: String {
        switch propertyType {
        case .relationship(let relationship) where relationship.idOnly == false:
            if name.hasSuffix("s") {
                var name = transformedName()
                name.removeLast()
                return "\(name)Payloads"
            } else {
                return "\(transformedName())Payload"
            }
        case .relationship:
            if name.hasSuffix("s") {
                var name = transformedName()
                name.removeLast()
                if name.lowercased().hasSuffix("ids") == false {
                    return "\(name)IDs"
                } else {
                    return transformedName()
                }
            } else if name.lowercased().hasSuffix("id") == false {
                return "\(transformedName())ID"
            } else {
                return transformedName()
            }
        case .array,
             .scalar,
             .subtype:
            return transformedName()
        }
    }
    
    func payloadValueTypeID(_ descriptions: Descriptions) throws -> TypeIdentifier {
        let valueTypeID = try propertyType.payloadValueTypeID(descriptions)
        let isOptional = nullable
        let rootTypeID = isOptional ? .optional(wrapped: valueTypeID) : valueTypeID
        return lazy ? .lazyValue(of: rootTypeID) : rootTypeID
    }
}

public extension EntityProperty.PropertyType {
    
    func payloadValueTypeID(_ descriptions: Descriptions) throws -> TypeIdentifier {
        switch self {
        case .scalar(let type):
            return type.typeID()
        case .subtype(let name):
            return TypeIdentifier(name: name.camelCased().suffixedName())
        case .relationship(let relationship):
            return try relationship.payloadValueTypeID(descriptions)
        case .array(let type):
            return .anySequence(element: try type.payloadValueTypeID(descriptions))
        }
    }
}

public extension EntityRelationship {
    
    func payloadValueTypeID(_ descriptions: Descriptions) throws -> TypeIdentifier {
        let entity = try descriptions.entity(for: entityName)

        var valueTypeID = idOnly ? entity.identifierTypeID() : entity.defaultEndpointPayloadTypeID

        if idOnly == false && entity.identifier.isRelationship == false && !(entity.identifier == .none) {
            valueTypeID = .payloadRelationship(of: valueTypeID)
        }
        
        switch association {
        case .toOne:
            return valueTypeID
        case .toMany:
            return .anySequence(element: valueTypeID)
        }
    }
}

// MARK: - Metadata

public extension Entity {
    
    var metadataTypeID: TypeIdentifier {
        return TypeIdentifier(name: "\(transformedName)Metadata")
    }
    
    func metadataTypeID(_ descriptions: Descriptions) throws -> TypeIdentifier {
        let hasVoidMetadata = try self.hasVoidMetadata(descriptions)
        return TypeIdentifier(name: hasVoidMetadata ? "VoidMetadata" : "\(transformedName)Metadata")
    }

    func metadataIdentifierReference() throws -> Reference? {
        switch identifier.identifierType {
        case .scalarType:
            return +.named("remote") | .call(Tuple()
                .adding(parameter: TupleParameter(value: Reference.named("id")))
                .adding(parameter: TupleParameter(value: Value.nil))
            )
        case .property(let name):
            let property = try self.property(for: name)

            if let relationship = property.relationship {
                guard relationship.idOnly == false else { return nil }
                return .named("\(property.payloadName)") + .named("identifier") + .named("value")
            } else {
                return +.named("remote") | .call(Tuple()
                    .adding(parameter: TupleParameter(value: Reference.named(name.camelCased().variableCased())))
                    .adding(parameter: TupleParameter(value: Value.nil))
                )
            }
        case .relationships(_, let relationships):
            guard relationships.count == 1, let relationship = relationships.first else {
                throw CodeGenError.unsupportedMetadataIdentifier
            }
            return .named("\(relationship.variableName.camelCased().variableCased()).identifier.value")
        case .void:
            return nil
        }
    }
    
    func hasVoidMetadata(_ descritions: Descriptions, history: Set<String> = Set()) throws -> Bool {
        guard metadata == nil else { return false }
        
        let hasPropertiesWithMetadata = try properties.contains { property in
            guard let relationship = property.relationship else { return false }
            let entity = try descritions.entity(for: relationship.entityName)
            guard relationship.idOnly == false else { return false }
            guard history.contains(name) == false else { return true }
            var history = history
            history.insert(name)
            return try entity.hasVoidMetadata(descritions, history: history)
        }
        return hasPropertiesWithMetadata == false
    }
}

public extension MetadataProperty {
    
    func variable(ignoreLexicon: Bool = false) -> Variable {
        return Variable(name: isArray ?
            name.camelCased(ignoreLexicon: ignoreLexicon).variableCased(ignoreLexicon: true).pluralName :
            name.camelCased(ignoreLexicon: ignoreLexicon).variableCased(ignoreLexicon: true)
        )
    }
    
    var typeID: TypeIdentifier {
        return nullable ? .optional(wrapped: propertyType.typeID) : propertyType.typeID
    }
}

public extension MetadataProperty.PropertyType {
    
    var typeID: TypeIdentifier {
        switch self {
        case .scalar(let type):
            return type.typeID()
        case .subtype(let name):
            return TypeIdentifier(name: name.camelCased().arrayElementType().suffixedName())
        case .array(let type):
            return .anySequence(element: type.typeID)
        }
    }
}

public extension EntityProperty {
    
    func metadataTypeID(_ descriptions: Descriptions) throws -> TypeIdentifier? {
        guard let relationship = self.relationship, relationship.idOnly == false else { return nil }
        let relationshipEntity = try descriptions.entity(for: relationship.entityName)
        guard try relationshipEntity.hasVoidMetadata(descriptions) == false else { return nil }
        var typeID = relationshipEntity.metadataTypeID
        if relationship.association == .toMany {
            let identifierTypeID = try relationship.identifierTypeID(descriptions)
                .wrappedOrSelf
                .arrayElementOrSelf
            typeID = .dualHashDictionary(key: identifierTypeID, value: typeID)
            if nullable {
                typeID = .optional(wrapped: typeID)
            }
            return typeID
        } else {
            return .optional(wrapped: typeID)
        }
    }
}

public extension EndpointPayload {

    var metadataVariable: Variable {
        return Variable(name: "endpointMetadata")
    }
    
    func metadataTypeID(for readWritePayload: ReadWriteEndpointPayload) throws -> TypeIdentifier {
        let voidMetadata = "VoidMetadata"

        if readWritePayload == readPayload, readWritePayload == writePayload {
            return TypeIdentifier(name: readWritePayload.metadata == nil ? voidMetadata : "\(transformedName)ReadWriteMetadata")
        } else if readWritePayload == readPayload {
            return TypeIdentifier(name: readWritePayload.metadata == nil ? voidMetadata : "\(transformedName)ReadMetadata")
        } else if readWritePayload == writePayload {
            return TypeIdentifier(name: readWritePayload.metadata == nil ? voidMetadata : "\(transformedName)WriteMetadata")
        } else {
            throw CodeGenError.endpointRequiresAtLeastOnePayload(name)
        }
    }

    var normalizedPathName: String {
        return name.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    var transformedName: String {
        return name.camelCased(separators: "_/")
    }
    
    func typeID(for readWritePayload: ReadWriteEndpointPayload) throws -> TypeIdentifier {
        if readWritePayload == readPayload, readWritePayload == writePayload {
            return TypeIdentifier(name: "\(transformedName)EndpointReadWritePayload")
        } else if readWritePayload == readPayload {
            return TypeIdentifier(name: "\(transformedName)EndpointReadPayload")
        } else if readWritePayload == writePayload {
            return TypeIdentifier(name: "\(transformedName)EndpointWritePayload")
        } else {
            throw CodeGenError.endpointRequiresAtLeastOnePayload(name)
        }
    }
}

public extension ReadWriteEndpointPayload {

    var payloadVariable: Variable {
        return entity.payloadVariable
    }
    
    var payloadTypeID: TypeIdentifier {
        let isVariant = entityVariations?.contains { $0.entityName == entity.entityName } ?? false
        return entity.payloadTypeID(isVariant: isVariant)
    }
}

public extension EndpointPayloadEntity {
    
    var payloadVariable: Variable {
        if structure.isArray {
            return Variable(name: "\(entityName.camelCased())Payload".variableCased().pluralName)
        } else {
            return Variable(name: "\(entityName.camelCased())Payload".variableCased())
        }
    }
    
    fileprivate func payloadTypeID(isVariant: Bool) -> TypeIdentifier {
        var typeID = TypeIdentifier(name: "\(isVariant ? "" : "DefaultEndpoint")\(entityName.camelCased().suffixedName())Payload")
        if structure.isArray {
            typeID = .anySequence(element: typeID)
        }
        if nullable {
            typeID = .optional(wrapped: typeID)
        }
        return typeID
    }
}

// MARK: - Manager

public extension Entity {
    
    var coreManagerProvidingTypeID: TypeIdentifier {
        return TypeIdentifier(name: "\(transformedName)CoreManagerProviding")
    }
    
    var coreManagerVariable: Variable {
        return Variable(name: "\(transformedName.variableCased())Manager")
    }
    
    var privateCoreManagerVariable: Variable {
        return Variable(name: "_\(transformedName.variableCased())Manager")
    }
    
    var privateRelationshipManagerVariable: Variable {
        return Variable(name: "_\(transformedName.variableCased())RelationshipManager")
    }
}

// MARK: - Tests

public extension EndpointPayload {
    
    func testJSONResourceName(for test: EndpointPayloadTest) -> String {
        return test.name.camelCased() + transformedName + "Payload"
    }
}

public extension Entity {
    
    var coreDataStoreVariable: Variable {
        return Variable(name: "\(transformedName.variableCased())CoreDataStore")
    }
}

// MARK: - Factories

public extension Entity {
    
    var factoryTypeID: TypeIdentifier {
        return TypeIdentifier(name: "\(transformedName)Factory")
    }
    
    func identifierDefaultValue(property: EntityProperty,
                                identifier: Reference,
                                descriptions: Descriptions) throws -> VariableValue? {
        switch self.identifier.identifierType {
        case .void:
            return PropertyScalarType.int.defaultValue(propertyName: property.transformedName(), identifier: identifier)
        case .property(let name):
            return try self.property(for: name)
                .defaultValue(property: property,
                              identifier: identifier,
                              useIdentifierRawType: true,
                              descriptions: descriptions)
        case .relationships(let type, _),
             .scalarType(let type):
            return type.defaultValue(propertyName: property.transformedName(), identifier: identifier)
        }
    }
}

public extension Subtype {
    
    var factoryTypeID: TypeIdentifier {
        return TypeIdentifier(name: "\(name.camelCased().suffixedName())Factory")
    }
}

public extension EntityProperty {
    
    func defaultValue(property: EntityProperty? = nil,
                      identifier: Reference,
                      useIdentifierRawType: Bool = false,
                      descriptions: Descriptions) throws -> VariableValue {

        var defaultValue = try propertyType.defaultValue(property: property ?? self,
                                                         identifier: identifier,
                                                         useIdentifierRawType: useIdentifierRawType,
                                                         descriptions: descriptions)
        if propertyType.isArray {
            defaultValue = Reference.array(with: [defaultValue]) + .named("any")
        }
        return defaultValue
    }
}

public extension EntityProperty.PropertyType {
    
    fileprivate func defaultValue(property: EntityProperty,
                                  identifier: Reference,
                                  useIdentifierRawType: Bool,
                                  descriptions: Descriptions) throws -> VariableValue {
        switch self {
        case .subtype(let name):
            let subtype = try descriptions.subtype(for: name)
            switch subtype.items {
            case .cases,
                 .options:
                return +.named("defaultValue")
            case .properties:
                return subtype.factoryTypeID.reference | .call(Tuple()
                    .adding(parameter: TupleParameter(value: identifier))
                )
            }
        case .scalar(let value):
            return value.defaultValue(propertyName: property.transformedName(), identifier: identifier)
        case .relationship(let relationship):
            let relationshipEntity = try descriptions.entity(for: relationship.entityName)

            if useIdentifierRawType {
                return try relationshipEntity.remoteIdentifierValueTypeID(descriptions).reference | .call(Tuple()
                    .adding(parameter: TupleParameter(value: identifier))
                )
            } else {
                guard let identifierDefaultValue = try relationshipEntity.identifierDefaultValue(property: property,
                                                                                                 identifier: identifier,
                                                                                                 descriptions: descriptions) else {
                    return relationshipEntity.identifierTypeID().reference | .call(Tuple())
                }
                return relationshipEntity.identifierTypeID().reference | .call(Tuple()
                    .adding(parameter: TupleParameter(name: "value", value: +.named("remote") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: identifierDefaultValue))
                        .adding(parameter: TupleParameter(value: Value.nil))
                    )))
                )
            }

        case .array(let value):
            return try value.defaultValue(property: property,
                                          identifier: identifier,
                                          useIdentifierRawType: useIdentifierRawType,
                                          descriptions: descriptions)
        }
    }
}

public extension PropertyScalarType {
    
    func defaultValue(propertyName: String, identifier: Reference) -> VariableValue {
        switch self {
        case .bool:
            return Value.bool(false)
        case .color:
            return TypeIdentifier.color.reference | .call(Tuple()
                .adding(parameter: TupleParameter(name: "hex", value: Value.string("#000000")))
            )
        case .date:
            return TypeIdentifier.date.reference | .call(Tuple()
                .adding(parameter: TupleParameter(name: "timeIntervalSince1970", value: Value.double(0)))
            )
        case .double:
            return TypeIdentifier.double.reference | .call(Tuple()
                .adding(parameter: TupleParameter(value: identifier))
            )
        case .float:
            return TypeIdentifier.float.reference | .call(Tuple()
                .adding(parameter: TupleParameter(value: identifier))
            )
        case .int:
            return TypeIdentifier.int.reference | .call(Tuple()
                .adding(parameter: TupleParameter(value: identifier))
            )
        case .url:
            return TypeIdentifier.url.reference | .call(Tuple()
                .adding(parameter: TupleParameter(name: "string", value: Value.string("http://fake_\(propertyName)/\\(\(identifier.swiftString))")))
            ) ?? TypeIdentifier.url.reference | .call(Tuple()
                .adding(parameter: TupleParameter(name: "fileURLWithPath", value: Value.string("")))
            )
        case .string:
            return Value.string("fake_\(propertyName)_\\(\(identifier.swiftString))")
        case .seconds:
            return TypeIdentifier(name: "Seconds").reference | .call(Tuple()
                .adding(parameter: TupleParameter(name: "seconds", value: TypeIdentifier.double.reference | .call(Tuple()
                    .adding(parameter: TupleParameter(value: identifier))
                )))
                .adding(parameter: TupleParameter(name: "preferredTimescale", value: Value.int(1000)))
            )
        case .milliseconds:
            return TypeIdentifier(name: "Milliseconds").reference | .call(Tuple()
                .adding(parameter: TupleParameter(name: "seconds", value: TypeIdentifier.double.reference | .call(Tuple()
                    .adding(parameter: TupleParameter(value: identifier | .named(" / 1000")))
                )))
                .adding(parameter: TupleParameter(name: "preferredTimescale", value: Value.int(1000)))
            )
        }
    }
}

// MARK: - DefaultValue

public extension DefaultValue {
    
    var variableValue: VariableValue {
        switch self {
        case .bool(let value):
            return Value.bool(value)
        case .int(let value):
            return Value.int(value)
        case .float(let value):
            return Value.float(value)
        case .string(let value):
            return Value.string(value)
        case .date(let value):
            return TypeIdentifier.date.reference | .call(Tuple()
                .adding(parameter: TupleParameter(name: "timeIntervalSince1970", value: Value.double(value.timeIntervalSince1970)))
            )
        case .currentDate:
            return TypeIdentifier.date.reference | .call()
        case .enumCase(let value):
            return +Reference.named(value.camelCased().variableCased())
        case .`nil`:
            return Value.nil
        case .seconds(let seconds):
            return .named("Seconds") | .call(Tuple()
                .adding(parameter: TupleParameter(name: "seconds", value: Value.float(seconds)))
            )
        case .milliseconds(let milliseconds):
            return .named("Milliseconds") | .call(Tuple()
                .adding(parameter: TupleParameter(name: "seconds", value: Value.float(milliseconds / 1000)))
            )
        }
    }
}
