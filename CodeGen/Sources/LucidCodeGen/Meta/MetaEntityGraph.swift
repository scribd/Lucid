//
//  MetaEntityGraph.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 2/5/20.
//

import Meta
import LucidCodeGenCore

struct MetaEntityGraph {
    
    let descriptions: Descriptions

    let reactiveKit: Bool

    let useCoreDataLegacyNaming: Bool
    
    func meta() -> [FileBodyMember] {
        return [
            relationshipControllerTypealias(),
            EmptyLine(),
            appAnyEntity(),
            EmptyLine(),
            appAnyEntityUtils(),
            EmptyLine(),
            appAnyEntityIndexName(),
            EmptyLine(),
            entityGraph(),
            EmptyLine(),
            relationshipQueryUtils(),
        ]
    }
    
    private func appAnyEntity() -> Type {
        return Type(identifier: .appAnyEntity)
            .with(accessLevel: .public)
            .with(kind: .enum(indirect: false))
            .adding(inheritedType: .entityIndexing)
            .adding(inheritedType: .entityConvertible)
            .adding(members: descriptions.entities.map { entity in
                Case(name: entity.name.camelCased().variableCased())
                    .adding(parameter: CaseParameter(type: entity.typeID()))
            })
            .adding(member: EmptyLine())
            .adding(member: entityRelationshipIndicesComputedProperty())
            .adding(member: EmptyLine())
            .adding(member: entityRelationshipEntityTypeUIDsComputedProperty())
            .adding(member: EmptyLine())
            .adding(member: entityIndexValueFunction())
            .adding(member: EmptyLine())
            .adding(member: initWithEntityFunction())
            .adding(member: EmptyLine())
            .adding(member: appAnyEntityDescriptionComputedProperty())
    }
    
    private func appAnyEntityUtils() -> PlainCode {
        return PlainCode(code: """
        extension Sequence where Element: Entity {
            var anyEntities: Array<AppAnyEntity> {
                return compactMap(AppAnyEntity.init)
            }
        }
        """)
    }
        
    private func relationshipControllerTypealias() -> PlainCode {
        return PlainCode(code: """
        typealias AppRelationshipController = RelationshipController<CoreManagerContainer, EntityGraph>
        """)
    }
    
    private func relationshipQueryUtils() -> PlainCode {
        let streamType = reactiveKit ? "Signal" : "AnyPublisher"
        let streamsName = reactiveKit ? "signals" : "publishers"
        let eraseToAnyPublisher = reactiveKit ? "" : ".eraseToAnyPublisher()"
        return PlainCode(code: """
        extension RelationshipController.RelationshipQuery where Graph == EntityGraph {
            func perform() -> (once: \(streamType)<EntityGraph, ManagerError>, continuous: \(streamType)<EntityGraph, ManagerError>) {
                let \(streamsName) = perform(EntityGraph.self)
                return (
                    \(streamsName).once.map { $0 as EntityGraph }\(eraseToAnyPublisher),
                    \(streamsName).continuous.map { $0 as EntityGraph }\(eraseToAnyPublisher)
                )
            }
        }
        """)
    }
    
    private func entityRelationshipIndicesComputedProperty() -> ComputedProperty {
        return ComputedProperty(variable: Variable(name: "entityRelationshipIndices")
            .with(type: .array(element: .appAnyEntityIndexName)))
            .with(accessLevel: .public)
            .adding(member: Switch(reference: .named(.`self`))
                .adding(cases: descriptions.entities.map { entity in
                    SwitchCase(name: entity.name.camelCased().variableCased())
                        .adding(value: Reference.named("let entity"))
                        .adding(member: Return(value: .named("entity") + .named("entityRelationshipIndices") + .named(.map) | .block(FunctionBody()
                            .adding(member: +.named(entity.name.camelCased().variableCased()) | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Reference.named("$0")))
                            ))
                        )))
                })
            )
    }
    
    private func entityRelationshipEntityTypeUIDsComputedProperty() -> ComputedProperty {
        return ComputedProperty(variable: Variable(name: "entityRelationshipEntityTypeUIDs")
            .with(type: .array(element: .string)))
            .with(accessLevel: .public)
            .adding(member: Switch(reference: .named(.`self`))
                .adding(cases: descriptions.entities.map { entity in
                    SwitchCase(name: entity.name.camelCased().variableCased())
                        .adding(value: Reference.named("let entity"))
                        .adding(member: Return(value: .named("entity") + .named("entityRelationshipEntityTypeUIDs")))
                })
            )
    }
    
    private func entityIndexValueFunction() -> Function {
        return Function(kind: .named("entityIndexValue"))
            .adding(parameter: FunctionParameter(alias: "for", name: "indexName", type: .appAnyEntityIndexName))
            .with(accessLevel: .public)
            .with(resultType: .entityIndexValue)
            .adding(member: PlainCode(code: """
            switch (self, indexName) {
            \(descriptions.entities.map { entity in
                return """
                case (.\(entity.name.camelCased().variableCased())(let entity), .\(entity.name.camelCased().variableCased())(let indexName)):
                    return entity.entityIndexValue(for: indexName)
                """
            }.joined(separator: "\n"))
            default:
                return .none
            }
            """))
    }
    
    private func initWithEntityFunction() -> Function {
        return Function(kind: .`init`(convenience: false, optional: true))
            .with(accessLevel: .public)
            .adding(genericParameter: GenericParameter(name: "E"))
            .adding(parameter: FunctionParameter(alias: "_", name: "entity", type: TypeIdentifier(name: "E")))
            .adding(constraint: .value(Reference.named("E: Entity")))
            .adding(member: PlainCode(code: """
            switch entity {
            \(descriptions.entities.map { entity in
                return """
                case let entity as \(entity.typeID().swiftString):
                    self = .\(entity.name.camelCased().variableCased())(entity)
                """
            }.joined(separator: "\n"))
            default:
                return nil
            }
            """)
            )
    }
    
    private func appAnyEntityDescriptionComputedProperty() -> ComputedProperty {
        return ComputedProperty(variable: Variable(name: "description")
            .with(type: .string))
            .with(accessLevel: .public)
            .adding(member: PlainCode(code: """
            switch self {
            \(descriptions.entities.map { entity in
                return """
                case .\(entity.name.camelCased().variableCased())(let entity):
                    return entity.identifier.description
                """
            }.joined(separator: "\n"))
            }
            """))
    }
    
    private func appAnyEntityIndexName() -> Type {
        return Type(identifier: .appAnyEntityIndexName)
            .with(kind: .enum(indirect: false))
            .with(accessLevel: .public)
            .adding(inheritedType: .hashable)
            .adding(members: descriptions.entities.map { entity in
                Case(name: entity.name.camelCased().variableCased())
                    .adding(parameter: CaseParameter(type: TypeIdentifier(name: "\(entity.transformedName).IndexName")))
            })
    }
    
    private func entityGraph() -> Type {
        return Type(identifier: .entityGraph)
            .with(kind: .class(final: true))
            .adding(inheritedType: .mutableGraph)
            .adding(member: EmptyLine())
            .adding(member: TypeAlias(identifier: TypeAliasIdentifier(name: "AnyEntity"), value: .appAnyEntity))
            .adding(member: EmptyLine())
            .adding(members: entityGraphProperties())
            .adding(member: EmptyLine())
            .adding(member: initFunction())
            .adding(member: EmptyLine())
            .adding(member: setRootFunction())
            .adding(member: EmptyLine())
            .adding(member: insertFunction())
            .adding(member: EmptyLine())
            .adding(member: containsFunction())
            .adding(member: EmptyLine())
            .adding(member: entitiesComputedProperty())
            .adding(member: EmptyLine())
            .adding(member: appendFunction())
    }
    
    private func entityGraphProperties() -> [TypeBodyMember] {
        return [
            Property(variable: Variable(name: "rootEntities")
                .with(type: .array(element: .appAnyEntity))
                .with(immutable: false))
                .with(accessLevel: .privateSet)
        ] + descriptions.entities.map { entity in
            
            let type: TypeIdentifier
            switch entity.identifier.identifierType {
            case .void:
                type = TypeIdentifier.array(element: entity.typeID())
            case .property,
                 .relationships,
                 .scalarType:
                type = TypeIdentifier.dualHashDictionary(key: entity.identifierTypeID(), value: entity.typeID())
            }
            
            return Property(variable: Variable(name: entity.name.camelCased().variableCased().pluralName)
                .with(immutable: false))
                .with(accessLevel: .privateSet)
                .with(value: type.reference | .call())
        }
    }
    
    private func initFunction() -> Function {
        return Function(kind: .`init`(convenience: false, optional: false))
            .adding(member: Assignment(
                variable: .named(.`self`) + .named("rootEntities"),
                value: Value.array([])
            ))
    }
    
    private func insertFunction() -> Function {
        return Function(kind: .named("insert"))
            .adding(genericParameter: GenericParameter(name: "S"))
            .adding(parameter: FunctionParameter(alias: "_", name: "entities", type: TypeIdentifier(name: "S")))
            .adding(constraint: .value(Reference.named("S: Sequence")))
            .adding(constraint: (.named("S") + .named("Element")) == TypeIdentifier.appAnyEntity.reference)
            .adding(member: .named("entities") + .named("forEach") | .block(FunctionBody()
                .adding(member: Switch(reference: .named("$0"))
                    .adding(cases: descriptions.entities.map { entity in
                        SwitchCase(name: entity.name.camelCased().variableCased())
                            .adding(value: Reference.named("let entity"))
                            .adding(member: PlainCode(code: assignment(for: entity)))
                    })
                )
            ))
    }
    
    private func setRootFunction() -> Function {
        return Function(kind: .named("setRoot"))
            .adding(genericParameter: GenericParameter(name: "S"))
            .adding(parameter: FunctionParameter(alias: "_", name: "entities", type: TypeIdentifier(name: "S")))
            .adding(constraint: .value(Reference.named("S: Sequence")))
            .adding(constraint: (.named("S") + .named("Element")) == TypeIdentifier.appAnyEntity.reference)
            .adding(member: Assignment(
                variable: Reference.named("rootEntities"),
                value: .named("entities") + .named("array")
            ))
    }

    private func assignment(for entity: Entity) -> String {
        switch entity.identifier.identifierType {
        case .void:
            return "\(entity.name.camelCased().variableCased().pluralName).append(entity)"
        case .property,
             .relationships,
             .scalarType:
            return "\(entity.name.camelCased().variableCased().pluralName)[entity.identifier] = entity"
        }
    }
    
    private func containsFunction() -> Function {
        return Function(kind: .named("contains"))
            .adding(parameter: FunctionParameter(alias: "_", name: "identifier", type: .anyRelationshipIdentifierConvertible))
            .with(resultType: .bool)
            .adding(member: Switch(reference: .named("identifier") | .named(" as? ") | TypeIdentifier.entityRelationshipIdentifier.reference)
                .adding(cases: descriptions.entities.map { entity in
                    switch entity.identifier.identifierType {
                    case .void:
                        return SwitchCase(name: entity.transformedName.variableCased())
                            .adding(member: Return(value: .value(.named(entity.name.camelCased().variableCased().pluralName) + .named("isEmpty")) == .value(Value.bool(false))))

                    case .property,
                         .relationships,
                         .scalarType:
                        return SwitchCase(name: entity.transformedName.variableCased())
                            .adding(value: Reference.named("let identifier"))
                            .adding(member: PlainCode(code: "return \(entity.name.camelCased().variableCased().pluralName)[identifier] != nil"))
                    }
                })
                .adding(case: SwitchCase(name: "none")
                    .adding(member: Return(value: Value.bool(false)))
                )
            )
    }

    private func entitiesComputedProperty() -> ComputedProperty {
        return ComputedProperty(variable: Variable(name: "entities")
            .with(type: .anySequence(element: .appAnyEntity)))
            .adding(members: descriptions.entities.map { entity in

                var value: Reference = .named(.`self`) + .named(entity.name.camelCased().pluralName.variableCased()) + .named("lazy")
                switch entity.identifier.identifierType {
                case .void:
                    value = value + .named(.map) | .block(FunctionBody()
                        .adding(member: TypeIdentifier.appAnyEntity.reference + .named(entity.name.camelCased().variableCased()) | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Reference.named("$0")))
                        ))
                    )
                case .property,
                     .relationships,
                     .scalarType:
                    value = value + .named("elements") + .named(.map) | .block(FunctionBody()
                        .adding(member: TypeIdentifier.appAnyEntity.reference + .named(entity.name.camelCased().variableCased()) | .call(Tuple()
                            .adding(parameter: TupleParameter(value: .named("$0") + .named("1")))
                        ))
                    )
                }

                return Assignment(
                    variable: Variable(name: entity.name.camelCased().pluralName.variableCased()),
                    value: value + .named("any")
                )
            })
            .adding(member: Return(value: Reference.array(with: descriptions.entities.map { entity in
                Reference.named(entity.name.camelCased().pluralName.variableCased())
            }) + .named("joined") | .call() + .named("any")))
    }

    private func appendFunction() -> Function {
        return Function(kind: .named("append"))
            .adding(parameter: FunctionParameter(alias: "_", name: "otherGraph", type: .entityGraph))
            .adding(member: .named("rootEntities") + .named("append") | .call(Tuple()
                .adding(parameter: TupleParameter(name: "contentsOf", value: .named("otherGraph") + .named("rootEntities")))
            ))
            .adding(member: .named("insert") | .call(Tuple()
                .adding(parameter: TupleParameter(value: Reference.named("otherGraph") + .named("entities")))
            ))
    }
}
