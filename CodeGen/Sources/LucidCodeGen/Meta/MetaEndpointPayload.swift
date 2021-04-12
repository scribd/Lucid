//
//  MetaEndpointPayload.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/29/19.
//

import Meta
import LucidCodeGenCore

struct MetaEndpointPayload {

    enum PayloadType {
        case read
        case write
    }

    let descriptions: Descriptions

    let payloadType: PayloadType

    let endpoint: EndpointPayload

    let readWritePayload: ReadWriteEndpointPayload

    public init?(endpointName: String,
                 payloadType: PayloadType,
                 descriptions: Descriptions) throws {

        let endpointValue = try descriptions.endpoint(for: endpointName)

        guard let readWritePayloadValue: ReadWriteEndpointPayload = {
            switch payloadType {
            case .read:
                return endpointValue.readPayload
            case .write:
                guard endpointValue.writePayload != endpointValue.readPayload else { return nil }
                return endpointValue.writePayload
            }
        }() else {
            return nil
        }

        self.descriptions = descriptions
        self.payloadType = payloadType
        self.endpoint = endpointValue
        self.readWritePayload = readWritePayloadValue
    }

    func meta() throws -> [FileBodyMember] {

        return [
            [
                Comment.mark(commentMarkString()),
                EmptyLine(),
                try endpointPayload(),
                EmptyLine(),
                Comment.mark("Decodable"),
                EmptyLine(),
                try decodableExtension()
            ],
            try metadata().flatMap {
                [
                    EmptyLine(),
                    Comment.mark("Metadata"),
                    EmptyLine(),
                    $0
                ]
            } ?? [], [
                EmptyLine(),
                Comment.mark("Accessors"),
                EmptyLine(),
                try accessors()
            ]
        ].flatMap { member -> [FileBodyMember] in member }
    }
    
    private func endpointPayload() throws -> Type {
        return Type(identifier: try endpoint.typeID(for: readWritePayload))
            .with(kind: .struct)
            .with(accessLevel: .public)
            .adding(member: EmptyLine())
            .adding(member: Property(variable: readWritePayload.payloadVariable.with(type: readWritePayload.payloadTypeID)))
            .adding(member: EmptyLine())
            .adding(member: Property(variable: endpoint.metadataVariable.with(type: try endpoint.metadataTypeID(for: readWritePayload))))
            .adding(member: EmptyLine())
            .adding(member: try entityMetadataComputedProperty())
            .adding(member: EmptyLine())
            .adding(member:
                ComputedProperty(variable: Variable(name: "excludedPaths")
                    .with(type: .array(element: .string))
                )
                .with(static: true)
                .with(accessLevel: .public)
                    .adding(member: Return(value: Value.array(readWritePayload.allExcludedPaths.map { Value.string($0) })))
            )
    }

    private func commentMarkString() -> String {
        switch payloadType {
        case .read:
            if endpoint.readPayload == endpoint.writePayload {
                return "Endpoint ReadWrite Payload"
            } else {
                return "Endpoint Read Payload"
            }
        case .write:
            return "Endpoint Write Payload"
        }
    }

    private func entityMetadataComputedProperty() throws -> ComputedProperty {
        let rootEntity = try descriptions.entity(for: readWritePayload.entity.entityName)

        let returnReference: Reference
        if readWritePayload.payloadTypeID.isArray == false {
            returnReference = .array(with: [
                readWritePayload.payloadVariable.reference | (readWritePayload.payloadTypeID.isOptional ? .unwrap : .none) + .named("entityMetadata")
            ]) + .named("lazy") + .named(.map) | .block(FunctionBody()
                .adding(member: Reference.named("$0"))
            ) + .named("any")
        } else {
            returnReference = readWritePayload.payloadVariable.reference |
                (readWritePayload.payloadTypeID.isOptional ? .unwrap : .none) +
                .named("lazy") + .named(.map) | .block(FunctionBody()
                    .adding(member: .named("$0") + .named("entityMetadata"))
                ) + .named("any")
        }
        
        return ComputedProperty(variable: Variable(name: "entityMetadata")
            .with(type: .anySequence(element: .optional(wrapped: try rootEntity.metadataTypeID(descriptions)))))
            .adding(member: Return(value: returnReference))
    }
    
    private func decodableExtension() throws -> Extension {

        let keys = try decodableKeys()
        let subkeys = try decodableSubkeys()
        
        return Extension(type: try endpoint.typeID(for: readWritePayload))
            .adding(inheritedType: .decodable)
            .adding(member: EmptyLine())
            .adding(member: keys)
            .adding(member: keys != nil ? EmptyLine() : nil)
            .adding(member: subkeys)
            .adding(member: subkeys != nil ? EmptyLine() : nil)
            .adding(member: try initFromDecoder())
    }
    
    private func decodableKeys() throws -> Type? {

        switch readWritePayload.initializerType {
        case .initFromKey(let key),
             .initFromSubkey(let key, _),
             .mapFromSubstruct(let key, _),
             .initFromRoot(.some(let key)):
            return Type(identifier: TypeIdentifier(name: "Keys"))
                .with(kind: .enum(indirect: false))
                .with(accessLevel: .private)
                .adding(inheritedType: .string)
                .adding(inheritedType: .codingKey)
                .adding(member: Case(name: key))
            
        case .initFromRoot:
            return nil
        }
    }
    
    private func decodableSubkeys() throws -> Type? {

        switch readWritePayload.initializerType {
        case .initFromSubkey(_ , let subkey):
            return Type(identifier: TypeIdentifier(name: "Subkeys"))
                .with(kind: .enum(indirect: false))
                .with(accessLevel: .private)
                .adding(inheritedType: .string)
                .adding(inheritedType: .codingKey)
                .adding(member: Case(name: subkey.camelCased(ignoreLexicon: true).variableCased()))
            
        case .mapFromSubstruct(_, let subkey):
            return Type(identifier: TypeIdentifier(name: "NestedValue"))
                .with(kind: .struct)
                .with(accessLevel: .private)
                .adding(inheritedType: .decodable)
                .adding(member: Property(variable: Variable(name: subkey.camelCased(ignoreLexicon: true).variableCased())
                    .with(type: readWritePayload.payloadTypeID.arrayElementOrSelf.wrappedOrSelf)
                ))
            
        case .initFromKey,
             .initFromRoot:
            return nil
        }
    }
    
    private func initFromDecoder() throws -> Function {

        var function = Function.initFromDecoder.with(accessLevel: .public)
        let decodeMethod: Reference = readWritePayload.entity.nullable ? .named("decodeIfPresent") : .named("decode")
        
        let container = Assignment(
            variable: Variable(name: "container"),
            value: Reference.named("decoder").container(keyedBy: TypeIdentifier(name: "Keys"))
        )

        var payloadPropertyTypeID = readWritePayload.payloadTypeID.wrappedOrSelf
        if let arrayElementTypeID = payloadPropertyTypeID.arrayElement {
            payloadPropertyTypeID = .array(element: .failableValue(of: arrayElementTypeID))
        }
        
        let unwrappedValues: Reference = payloadPropertyTypeID.isArray ?
            +.named("lazy") + .named(.compactMap) | .block(FunctionBody()
                .adding(member: .named("$0") + .named("value") | .call())
            ) + .named("any") : .none
        
        let metadataKey: String?
        switch readWritePayload.initializerType {
        case .initFromRoot(nil):
            metadataKey = nil
            function = function
                .adding(member: Assignment(
                    variable: Reference.named(.`self`) + readWritePayload.payloadVariable.reference,
                    value: .try | payloadPropertyTypeID.reference | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "from", value: Reference.named("decoder")))
                    ) | unwrappedValues
                ))
            
        case .initFromRoot(.some(let key)):
            metadataKey = nil
            function = function
                .adding(member: container)
                .adding(member: Assignment(
                    variable: .named(.`self`) + readWritePayload.payloadVariable.reference,
                    value: .try | .named("container") + decodeMethod | .call(Tuple()
                        .adding(parameter: TupleParameter(value: payloadPropertyTypeID.reference + .named(.`self`)))
                        .adding(parameter: TupleParameter(name: "forKey", value: +.named(key)))
                    ) | unwrappedValues
                ))
            
        case .initFromKey(let key):
            metadataKey = key
            function = function
                .adding(member: container)
                .adding(member: Assignment(
                    variable: .named(.`self`) + readWritePayload.payloadVariable.reference,
                    value: .try | .named("container") + decodeMethod | .call(Tuple()
                        .adding(parameter: TupleParameter(value: payloadPropertyTypeID.reference + .named(.`self`)))
                        .adding(parameter: TupleParameter(name: "forKey", value: +.named(key)))
                    ) | unwrappedValues
                ))
            
        case .initFromSubkey(let key, let subkey):
            metadataKey = key
            function = function
                .adding(member: container)
                .adding(member: Assignment(
                    variable: Variable(name: "nestedContainer"),
                    value: .try | .named("container") + .named("nestedContainer") | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "keyedBy", value: .named("Subkeys") + .named(.`self`)))
                        .adding(parameter: TupleParameter(name: "forKey", value: +.named(key)))
                    )
                ))
                .adding(member: Assignment(
                    variable: .named(.`self`) + readWritePayload.payloadVariable.reference,
                    value: .try | .named("nestedContainer") + decodeMethod | .call(Tuple()
                        .adding(parameter: TupleParameter(value: payloadPropertyTypeID.reference + .named(.`self`)))
                        .adding(parameter: TupleParameter(name: "forKey", value: +.named(subkey.camelCased().variableCased())))
                    ) | unwrappedValues
                ))
            
        case .mapFromSubstruct(let key, let subkey):
            metadataKey = key
            var nestedDecodingType = TypeIdentifier(name: "NestedValue")
            if readWritePayload.entity.structure.isArray {
                nestedDecodingType = .array(element: .failableValue(of: nestedDecodingType))
            }
            function = function
                .adding(member: container)
                .adding(member: Assignment(
                    variable: .named(.`self`) + readWritePayload.payloadVariable.reference,
                    value: .try | .named("container") + decodeMethod | .call(Tuple()
                        .adding(parameter: TupleParameter(value: nestedDecodingType.reference + .named(.`self`)))
                        .adding(parameter: TupleParameter(name: "forKey", value: +.named(key)))
                    ) + .named("lazy") + .named(readWritePayload.entity.structure.isArray ? .compactMap : .map) | .block(FunctionBody()
                        .adding(member: Reference.named("$0") | (+.named("value") | .call() | .unwrap) + .named(subkey.camelCased().variableCased()))
                    ) + .named("any")
                ))
        }
        
        if readWritePayload.metadata == nil {
            return function
                .adding(member: Assignment(
                    variable: .named(.`self`) + .named("endpointMetadata"),
                    value: TypeIdentifier.voidMetadata.reference | .call()
                ))
        } else if let metadataKeyName = metadataKey {
            return function
                .adding(member: Assignment(
                    variable: .named(.`self`) + .named("endpointMetadata"),
                    value: .try | .named("container") + decodeMethod | .call(Tuple()
                        .adding(parameter: TupleParameter(value: try endpoint.metadataTypeID(for: readWritePayload).reference + .named(.`self`)))
                        .adding(parameter: TupleParameter(name: "forKey", value: +.named(metadataKeyName)))
                    )
                ))
        } else {
            return function
                .adding(member: Assignment(
                    variable: Variable(name: "singleValueContainer"),
                    value: .try | Reference.named("decoder") + .named("singleValueContainer") | .call()
                ))
                .adding(member: Assignment(
                    variable: .named(.`self`) + .named("endpointMetadata"),
                    value: .try | .named("singleValueContainer") + decodeMethod | .call(Tuple()
                        .adding(parameter: TupleParameter(value: try endpoint.metadataTypeID(for: readWritePayload).reference + .named(.`self`)))
                    )
                ))
        }
    }
    
    private func metadata() throws -> Type? {
        guard let metadata = readWritePayload.metadata else { return nil }
        
        return Type(identifier: try endpoint.metadataTypeID(for: readWritePayload))
            .with(kind: .struct)
            .with(accessLevel: .public)
            .adding(inheritedType: .decodable)
            .adding(inheritedType: .endpointMetadata)
            .adding(members: metadata.map {
                Property(variable: $0.variable().with(type: $0.typeID))
                    .with(accessLevel: .public)
            })
            .adding(member: EmptyLine())
            .adding(member: Type(identifier: TypeIdentifier(name: "Keys"))
                .with(kind: .enum(indirect: false))
                .with(accessLevel: .private)
                .adding(inheritedType: .string)
                .adding(inheritedType: .codingKey)
                .adding(members: metadata.map { property in
                    Case(name: property.name.camelCased(ignoreLexicon: true).variableCased())
                })
            )
            .adding(member: EmptyLine())
            .adding(member: Function.initFromDecoder
                .with(accessLevel: .public)
                .adding(member: Assignment(
                    variable: Variable(name: "container"),
                    value: .try | .named("decoder") + .named("container") | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "keyedBy", value: TypeIdentifier(name: "Keys").reference + .named(.`self`)))
                    )
                ))
                .adding(members: metadata.map { property in
                    Assignment(
                        variable: Reference.named(property.name.camelCased().variableCased()),
                        value: .try | .named("container") + .named("decode") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: property.typeID.reference + .named(.`self`)))
                            .adding(parameter: TupleParameter(name: "forKey", value: +.named(property.name.camelCased(ignoreLexicon: true).variableCased())))
                        )
                    )
                })
            )
    }
    
    private func accessors() throws -> Extension {
        let entity = try descriptions.entity(for: readWritePayload.entity.entityName)

        switch payloadType {
        case .write:
            return Extension(type: try endpoint.typeID(for: readWritePayload))
                .adding(members: [
                    EmptyLine(),
                    try accessor(for: entity, isExtractable: false)
                ])
        case .read:
            let extractableEntities = try entity.extractablePropertyEntities(descriptions)

            var accessors = try extractableEntities.flatMap { entity -> [TypeBodyMember] in
                return [
                    EmptyLine(),
                    try accessor(for: entity, isExtractable: true)
                ]
            }

            let isSelfExtractable = extractableEntities.contains { $0.name == entity.name }
            if isSelfExtractable == false {
                accessors.append(EmptyLine())
                accessors.append(try accessor(for: entity, isExtractable: false))
            }

            let extractableEntitiesAndSelf = extractableEntities + (isSelfExtractable == false ? [entity] : [])

            return Extension(type: try endpoint.typeID(for: readWritePayload))
                .adding(members: accessors)
                .adding(member: EmptyLine())
                .adding(member: ComputedProperty(variable: Variable(name: "allEntities")
                    .with(type: .anySequence(element: .appAnyEntity)))
                    .adding(members: extractableEntitiesAndSelf.map { entity in
                        Assignment(
                            variable: entity.payloadEntityAccessorVariable,
                            value: .named(.`self`) + entity.payloadEntityAccessorVariable.reference + .named(.map) | .block(FunctionBody()
                                .adding(member: TypeIdentifier.appAnyEntity.reference + .named(entity.name.camelCased().variableCased()) | .call(Tuple()
                                    .adding(parameter: TupleParameter(value: Reference.named("$0")))
                                ))
                            ) + .named("any")
                        )
                    })
                    .adding(member: Return(value: Reference.array(with: extractableEntitiesAndSelf.map { entity in
                        entity.payloadEntityAccessorVariable.reference
                    }) + .named("joined") | .call() + .named("any")))
                )
        }
    }
    
    private func accessor(for entity: Entity, isExtractable: Bool) throws -> ComputedProperty {

        let selfMapping: Reference? = entity.name == readWritePayload.entity.entityName ?
            readWritePayload.payloadVariable.reference | (readWritePayload.entity.structure.isArray == false ? +.named("values") | .call() : .none) + .named("lazy") + .named(.map) | .block(FunctionBody()
                .adding(member: entity.typeID().reference | .call(Tuple()
                    .adding(parameter: TupleParameter(name: "payload", value: .named("$0") + .named("rootPayload")))
                ))
            ) + .named("any") : nil
        
        let extractionMapping: Reference? = isExtractable ?
            readWritePayload.payloadVariable.reference | (readWritePayload.entity.structure.isArray == false ? +.named("values") | .call() : .none) + .named("lazy") + .named(.flatMap) | .block(FunctionBody()
                .adding(member: .named("$0") + .named("rootPayload") + entity.payloadEntityAccessorVariable.reference)
            ) + .named("any") : nil
        
        let mappingReferences = [selfMapping, extractionMapping].compactMap { $0 }

        return ComputedProperty(variable: entity.payloadEntityAccessorVariable
            .with(type: .anySequence(element: entity.typeID())))
            .adding(member: Return(value: (mappingReferences.isEmpty == false ?
                .array(with: mappingReferences) + .named("joined") | .call() :
                .array()) + .named("any")
            ))
    }
}
