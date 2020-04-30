//
//  MetaCoreManagerContainer.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/11/19.
//

import Meta

struct MetaCoreManagerContainer {
    
    let descriptions: Descriptions
    
    func meta() -> [FileBodyMember] {
        return [
            [
                Comment.mark("Response Handler"),
                EmptyLine(),
                responseHandlerProtocol,
                Comment.mark("Resolvers"),
                EmptyLine(),
                resolverTypealias,
                EmptyLine()
            ],
            providingProtocols,
            [
                EmptyLine(),
                Comment.mark("Container"),
                EmptyLine(),
                coreManagerType(),
                EmptyLine(),
                Extension(type: .coreManagerContainer)
                    .adding(inheritedType: .coreManagerResolver),
                EmptyLine(),
                Comment.mark("Relationship Manager"),
                EmptyLine(),
                relationshipCoreManagerExtension(),
                EmptyLine(),
                Comment.mark("Default Entity Stores"),
                EmptyLine(),
                defaultImplementationsExtensions
            ]
        ].flatMap { $0 }
    }
    
    private var resolverTypealias: TypeAlias {
        return TypeAlias(identifier: TypeAliasIdentifier(name: TypeIdentifier.coreManagerResolver.name), values: descriptions.entities.map {
            $0.coreManagerProvidingTypeID
        })
    }
    
    private var responseHandlerProtocol: PlainCode {
        return PlainCode(code: """
        protocol CoreManagerContainerClientQueueResponseHandler: APIClientQueueResponseHandler {
            var managers: CoreManagerContainer? { get set } // Should be declared weak in order to avoid a retain cycle
        }
        """)
    }
    
    private var providingProtocols: [FileBodyMember] {
        return descriptions.entities.flatMap { entity -> [FileBodyMember] in
            [
                Type(identifier: entity.coreManagerProvidingTypeID)
                    .with(kind: .protocol)
                    .adding(member: ProtocolProperty(name: entity.coreManagerVariable.name, type: .coreManaging(of: entity.typeID()))),
                EmptyLine()
            ]
        }
    }
    
    private func coreManagerType() -> Type {
        return Type(identifier: .coreManagerContainer)
            .with(kind: .class(final: true))
            .with(accessLevel: .public)
            .adding(member: PlainCode(code: """
            
            private let _responseHandler: CoreManagerContainerClientQueueResponseHandler? = makeResponseHandler()
            public var responseHandler: APIClientQueueResponseHandler? {
                return _responseHandler
            }

            public let mainClientQueue: APIClientQueue
            public let clientQueues: Set<APIClientQueue>
            
            public let coreDataManager: CoreDataManager
            """))
            .adding(members: descriptions.entities.flatMap { entity -> [TypeBodyMember] in
                [
                    EmptyLine(),
                    Property(variable: entity.privateCoreManagerVariable
                        .with(type: .coreManager(of: entity.typeID())))
                        .with(accessLevel: .private),
                    Property(variable: entity.privateRelationshipManagerVariable
                        .with(kind: .lazy)
                        .with(immutable: false))
                        .with(accessLevel: .private)
                        .with(value: TypeIdentifier.coreManaging(of: entity.typeID()).reference + .named("RelationshipManager") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Reference.named(.`self`)))
                        )),
                    ComputedProperty(variable: entity.coreManagerVariable
                        .with(type: .coreManaging(of: entity.typeID())))
                        .adding(member: Return(value: entity.privateCoreManagerVariable.reference + .named("managing") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: entity.privateRelationshipManagerVariable.reference))
                        )))
                ]
            })
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .`init`)
                .with(accessLevel: .public)
                .adding(parameter: FunctionParameter(name: "cacheLimit", type: .int))
                .adding(parameter: FunctionParameter(name: "client", type: .apiClient))
                .adding(parameter: FunctionParameter(name: "coreDataManager", type: .coreDataManager)
                    .with(defaultValue: TypeIdentifier.coreDataManager.reference | .call(Tuple()
                        .adding(parameter: TupleParameter(name: "modelName", value: Value.string(descriptions.targets.app.moduleName)))
                        .adding(parameter: TupleParameter(name: "in", value: Reference.named("Bundle") | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "for", value: Reference.named("CoreManagerContainer.self")))
                        )))
                        .adding(parameter: TupleParameter(name: "migrations", value: Reference.named("CoreDataManager.migrations")))
                    ))
                )
                .adding(member: EmptyLine())
                .adding(member: PlainCode(code: """
                let mainClientQueue = APIClientQueue.clientQueue(
                    for: "\\(CoreManagerContainer.self)_api_client_queue",
                    client: client,
                    scheduler: APIClientQueueDefaultScheduler()
                )
                if let responseHandler = _responseHandler {
                    mainClientQueue.register(responseHandler)
                }
                self.mainClientQueue = mainClientQueue
                self.coreDataManager = coreDataManager

                var clientQueues = Set([mainClientQueue])
                var clientQueue = mainClientQueue

                """))
                .adding(members: descriptions.entities.flatMap { entity -> [FunctionBodyMember] in
                    [
                        Assignment(
                            variable: entity.privateCoreManagerVariable.reference,
                            value: TypeIdentifier.coreManager().reference | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "stores", value: entity.typeID().reference + .named("stores") | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "with", value: Reference.named("client")))
                                .adding(parameter: TupleParameter(name: "clientQueue", value: Reference.named("&clientQueue")))
                                .adding(parameter: TupleParameter(name: "coreDataManager", value: Reference.named("coreDataManager")))
                                .adding(parameter: TupleParameter(name: "cacheLimit", value: Reference.named("cacheLimit")))
                            ))))
                        ),
                        PlainCode(code: """
                        if clientQueues.contains(clientQueue) == false, let responseHandler = _responseHandler {
                            clientQueue.register(responseHandler)
                        }
                        clientQueues.insert(clientQueue)
                        clientQueue = mainClientQueue

                        """)
                    ]
                })
                .adding(member: PlainCode(code: """
                self.clientQueues = clientQueues
                """))
                .adding(member: EmptyLine())
                .adding(member: Comment.comment("Init of lazy vars for thread-safety."))
                .adding(members: descriptions.entities.map { entity in
                    Assignment(
                        variable: Reference.named("_"),
                        value: entity.privateRelationshipManagerVariable.reference
                    )
                })
                .adding(member: EmptyLine())
                .adding(member: PlainCode(code: """
                _responseHandler?.managers = self
                """))
            )
    }
    
    private func relationshipCoreManagerExtension() -> Extension {
        return Extension(type: .coreManagerContainer)
            .adding(inheritedType: .relationshipCoreManaging)
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .named("get"))
                .with(accessLevel: .public)
                .adding(parameter: FunctionParameter(
                    alias: "byIDs",
                    name: "identifiers",
                    type: .anySequence(element: .anyRelationshipIdentifierConvertible))
                )
                .adding(parameter: FunctionParameter(name: "entityType", type: .string))
                .adding(parameter: FunctionParameter(alias: "in", name: "context", type: TypeIdentifier(name: "AppReadContext")))
                .with(resultType: .signal(of: .anySequence(element: .appAnyEntity), error: .managerError))
                .adding(member: Switch(reference: .named("entityType"))
                    .adding(cases: descriptions.entities.map { entity in
                        SwitchCase()
                            .adding(value: entity.identifierTypeID().reference + .named("entityTypeUID"))
                            .adding(member: Return(value: entity.coreManagerVariable.reference + .named("get") | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "byIDs", value: TypeIdentifier.dualHashSet().reference | .call(Tuple()
                                    .adding(parameter: TupleParameter(value: .named("identifiers") + .named("lazy") + .named(.compactMap) | .block(FunctionBody()
                                        .adding(member: .named("$0") + .named("toRelationshipID") | .call())
                                    )))
                                )))
                                .adding(parameter: TupleParameter(name: "in", value: Reference.named("context")))
                            ) + .named("once") + .named(.map) | .block(FunctionBody()
                                .adding(member: .named("$0") + .named("lazy") + .named(.map) | .block(FunctionBody()
                                    .adding(member: +.named(entity.name.unversionedName.variableCased) | .call(Tuple()
                                        .adding(parameter: TupleParameter(value: Reference.named("$0")))
                                    ))
                                ) + .named("any"))
                            )))
                    })
                    .adding(case: SwitchCase(name: .default)
                        .adding(member: Return(value: TypeIdentifier.signal().reference | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "result", value: +.named("failure") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: +.named("notSupported")))
                            ))
                        ))))
                    )
                )
            )
    }
    
    private var defaultImplementationsExtensions: PlainCode {
        return PlainCode(code: """
        // Manually add the function:
        // static func stores(with client: APIClient) -> [Storing<E>]
        // to an individual class adopting the Entity protocol to provide custom functionality

        extension Entity {
            static func stores(with client: APIClient,
                               clientQueue: inout APIClientQueue,
                               coreDataManager: CoreDataManager,
                               cacheLimit: Int) -> Array<Storing<Self>> {
                let localStore = LRUStore<Self>(store: InMemoryStore().storing, limit: cacheLimit)
                return Array(arrayLiteral: localStore.storing)
            }
        }

        extension CoreDataEntity {
            static func stores(with client: APIClient,
                               clientQueue: inout APIClientQueue,
                               coreDataManager: CoreDataManager,
                               cacheLimit: Int) -> Array<Storing<Self>> {
                let localStore = CacheStore<Self>(
                    keyValueStore: LRUStore(store: InMemoryStore().storing, limit: cacheLimit).storing,
                    persistentStore: CoreDataStore(coreDataManager: coreDataManager).storing
                )
                return Array(arrayLiteral: localStore.storing)
            }
        }

        extension RemoteEntity {
            static func stores(with client: APIClient,
                               clientQueue: inout APIClientQueue,
                               coreDataManager: CoreDataManager,
                               cacheLimit: Int) -> Array<Storing<Self>> {
                let remoteStore = RemoteStore<Self>(client: client, clientQueue: clientQueue)
                return Array(arrayLiteral: remoteStore.storing)
            }
        }

        extension RemoteEntity where Self : CoreDataEntity {
            static func stores(with client: APIClient,
                               clientQueue: inout APIClientQueue,
                               coreDataManager: CoreDataManager,
                               cacheLimit: Int) -> Array<Storing<Self>> {
                let remoteStore = RemoteStore<Self>(client: client, clientQueue: clientQueue)
                let localStore = CacheStore<Self>(
                    keyValueStore: LRUStore(store: InMemoryStore().storing, limit: cacheLimit).storing,
                    persistentStore: CoreDataStore(coreDataManager: coreDataManager).storing
                )
                return Array(arrayLiteral: remoteStore.storing, localStore.storing)
            }
        }
        """)
    }
}
