//
//  MetaEndpointResultPayload.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/9/19.
//

import Meta
import LucidCodeGenCore

struct MetaEndpointResultPayload {

    let descriptions: Descriptions
    
    func meta() throws -> Type {
        return Type(identifier: .endpointResultPayload)
            .with(accessLevel: .public)
            .adding(inheritedType: .resultPayloadConvertible)
            .adding(member: EmptyLine())
            .adding(member: Comment.mark("Content"))
            .adding(member: EmptyLine())
            .adding(member: endpointEnum)
            .adding(member: EmptyLine())
            .adding(member: Comment.mark("Precached Entities"))
            .adding(member: EmptyLine())
            .adding(members: precachedEntityProperties)
            .adding(member: EmptyLine())
            .adding(member: Comment.mark("Metadata"))
            .adding(member: EmptyLine())
            .adding(member: metadataProperty)
            .adding(member: EmptyLine())
            .adding(member: Comment.mark("Init"))
            .adding(member: EmptyLine())
            .adding(member: try initFunction())
            .adding(member: EmptyLine())
            .adding(member: try getEntityFunction())
            .adding(member: EmptyLine())
            .adding(member: try allEntitiesFunction())
    }
    
    private var endpointEnum: Type {
        return Type(identifier: .endpoint)
            .with(accessLevel: .public)
            .with(kind: .enum(indirect: false))
            .adding(members: descriptions.endpoints.map { endpoint in
                Case(name: endpoint.transformedName.variableCased())
            })
    }
    
    private var precachedEntityProperties: [Property] {
        return descriptions.entities.map { entity in
            let type: TypeIdentifier
            if entity.hasVoidIdentifier {
                type = .anySequence(element: entity.typeID())
            } else {
                type = .orderedDualHashDictionary(key: entity.identifierTypeID(), value: entity.typeID())
            }
            return Property(variable: entity.payloadEntityAccessorVariable
                .with(type: type))
                .with(accessLevel: .public)
        }
    }
    
    private var metadataProperty: Property {
        return Property(variable: Variable(name: "metadata")
            .with(type: .endpointResultMetadata))
            .with(accessLevel: .public)
    }
    
    private func initFunction() throws -> Function {

        return Function(kind: .`init`)
            .with(accessLevel: .public)
            .adding(parameter: FunctionParameter(alias: "from", name: "data", type: .data))
            .adding(parameter: FunctionParameter(name: "endpoint", type: .endpoint))
            .adding(parameter: FunctionParameter(name: "decoder", type: .jsonDecoder))
            .with(throws: true)
            .adding(member: EmptyLine())
            .adding(members: descriptions.entities.map { entity in
                Assignment(
                    variable: entity.payloadEntityAccessorVariable.with(immutable: false),
                    value: entity.hasVoidIdentifier ?
                        TypeIdentifier.array(element: entity.typeID()).reference | .call() :
                        TypeIdentifier.orderedDualHashDictionary(key: entity.identifierTypeID(), value: entity.typeID()).reference | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "optimizeWriteOperation", value: Value.bool(true)))
                        )
                )
            })
            .adding(member: Variable(name: "entities").with(type: .anySequence(element: .appAnyEntity)))
            .adding(member: EmptyLine())
            .adding(member: Switch(reference: .named("endpoint")).with(cases: try descriptions.endpoints.compactMap { endpoint in
                guard let readPayload = endpoint.readPayload else { return nil }
                return SwitchCase(name: endpoint.transformedName.variableCased())
                    .adding(member: Reference.named("decoder") + .named("setExcludedPaths") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: try endpoint.typeID(for: readPayload).reference + .named("excludedPaths")))
                    ))
                    .adding(member: Assignment(
                        variable: Variable(name: "payload"),
                        value: .try | .named("decoder") + .named("decode") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: try endpoint.typeID(for: readPayload).reference + .named(.`self`)))
                            .adding(parameter: TupleParameter(name: "from", value: Reference.named("data")))
                        ))
                    )
                    .adding(member: Assignment(
                        variable: Reference.named("entities"),
                        value: .named("payload") + .named("allEntities")
                    ))
                    .adding(member: Assignment(
                        variable: Reference.named("metadata"),
                        value: TypeIdentifier.endpointResultMetadata.reference | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "endpoint", value: .named("payload") + .named("endpointMetadata")))
                            .adding(parameter: TupleParameter(name: "entity", value: .named("payload") + .named("entityMetadata") + .named("lazy") + .named(.map) | .block(FunctionBody()
                                .adding(member: .named("$0") | .as | TypeIdentifier.optional(wrapped: .entityMetadata).reference)
                            ) + .named("any")))
                        )
                    ))
            }))
            .adding(member: EmptyLine())
            .adding(member: PlainCode(code: """
            for entity in entities {
                switch entity {
                \(descriptions.entities.map { entity in
                    """
                    case .\(entity.name.camelCased().variableCased())(let value):
                        \({ () -> String in
                            if entity.hasVoidIdentifier {
                                return "    \(entity.payloadEntityAccessorVariable.name).append(value)"
                            } else if entity.hasLazyProperties {
                                return "    \(entity.payloadEntityAccessorVariable.name)[value.identifier] = \(entity.payloadEntityAccessorVariable.name)[value.identifier].flatMap { $0.merging(value) } ?? value"
                            } else {
                                return "    \(entity.payloadEntityAccessorVariable.name)[value.identifier] = value"
                            }
                        }())
                    """
                }.joined(separator: "\n    "))
                }
            }
            """))
            .adding(member: EmptyLine())
            .adding(members: descriptions.entities.map { entity in
                Assignment(
                    variable: Reference.named(.`self`) + entity.payloadEntityAccessorVariable.reference,
                    value: entity.payloadEntityAccessorVariable.reference | (entity.hasVoidIdentifier ? +.named("any") : .none)
                )
            })
    }

    private func getEntityFunction() throws -> Function {
        let e = TypeIdentifierName.custom("E")
        return Function(kind: .named("getEntity"))
            .with(accessLevel: .public)
            .adding(genericParameter: GenericParameter(name: e.string))
            .adding(parameter: FunctionParameter(alias: "for", name: "identifier", type: TypeIdentifier(name: e + "Identifier")))
            .with(resultType: .optional(wrapped: TypeIdentifier(name: e)))
            .adding(constraint:
                .assemble(
                    .value(TypeIdentifier(name: e).reference),
                    .constraintImplement,
                    .value(TypeIdentifier.entity.reference)
                )
            )
            .adding(member: EmptyLine())
            .adding(member: PlainCode(code: """
            switch identifier {
            \(descriptions.entities.map { entity in
                if entity.hasVoidIdentifier {
                    return """
                    case _ where E.self == \(entity.typeID().swiftString).self:
                        return \(entity.name.camelCased().variableCased().pluralName).first as? E
                    """
                } else {
                    return """
                    case let entityIdentifier as \(entity.identifierTypeID().swiftString):
                        return \(entity.name.camelCased().variableCased().pluralName)[entityIdentifier] as? E
                    """
                }
            }.joined(separator: "\n"))
            default:
                return nil
            }
            """))
    }

    private func allEntitiesFunction() throws -> Function {
        let e = TypeIdentifierName.custom("E")
        return Function(kind: .named("allEntities"))
            .with(accessLevel: .public)
            .adding(genericParameter: GenericParameter(name: e.string))
            .with(resultType: .anySequence(element: TypeIdentifier(name: e)))
            .adding(constraint:
                .assemble(
                    .value(TypeIdentifier(name: e).reference),
                    .constraintImplement,
                    .value(TypeIdentifier.entity.reference)
                )
            )
            .adding(member: EmptyLine())
            .adding(member: PlainCode(code: """
            switch E.self {
            \(descriptions.entities.map { entity in
                if entity.hasVoidIdentifier {
                    return """
                    case is \(entity.typeID().swiftString).Type:
                        return \(entity.name.camelCased().variableCased().pluralName) as? AnySequence<E> ?? [].any
                    """
                } else {
                    return """
                    case is \(entity.typeID().swiftString).Type:
                        return \(entity.name.camelCased().variableCased().pluralName).orderedValues.any as? AnySequence<E> ?? [].any
                    """
                }
            }.joined(separator: "\n"))
            default:
                return [].any
            }
            """))
    }
}
