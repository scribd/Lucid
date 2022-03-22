//
//  MetaCoreManagerContainer.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/11/19.
//

import Meta
import LucidCodeGenCore

struct MetaCoreManagerContainer {
    
    let descriptions: Descriptions
    
    let coreDataMigrationsFunction: String?

    func meta() throws -> [FileBodyMember] {
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
                try coreManagerType(),
                EmptyLine(),
                Extension(type: .coreManagerContainer)
                    .adding(inheritedType: .coreManagerResolver),
                EmptyLine(),
                Comment.mark("Relationship Manager"),
                EmptyLine(),
                relationshipCoreManagerExtension(),
                EmptyLine(),
                Comment.mark("Persistence Manager"),
                EmptyLine(),
                payloadPersistenceManagerExtension(),
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
        public protocol CoreManagerContainerClientQueueResponseHandler: APIClientQueueResponseHandler {
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
    
    private func coreManagerType() throws -> Type {
        return Type(identifier: .coreManagerContainer)
            .with(kind: .class(final: true))
            .with(accessLevel: .public)
            .adding(member:
                PlainCode(code: """

                public struct DiskStoreConfig {
                    public var coreDataManager: CoreDataManager?
                    public var custom: Any?

                    public static var coreData: DiskStoreConfig {
                \(MetaCode(indentation: 2, meta: Assignment(
                    variable: Variable(name: "coreDataManager"),
                    value: TypeIdentifier.coreDataManager.reference | .call(
                        Tuple()
                            .adding(parameter: TupleParameter(name: "modelName", value: Value.string(descriptions.targets.app.moduleName)))
                            .adding(parameter: TupleParameter(name: "in", value: Reference.named("Bundle") | .call(
                                Tuple().adding(parameter: TupleParameter(name: "for", value: Reference.named("CoreManagerContainer.self")))
                            )))
                            .adding(parameter: TupleParameter(
                                name: "migrations",
                                value: coreDataMigrationsFunction.flatMap { Reference.named($0) | .call() } ?? Value.array([])
                            ))
                    ))
                ))
                        return DiskStoreConfig(coreDataManager: coreDataManager, custom: nil)
                    }
                }

                public struct CacheSize {
                    let small: Int
                    let medium: Int
                    let large: Int

                    public static var `default`: CacheSize { return CacheSize(small: 100, medium: 500, large: 2000) }
                }

                private let _responseHandler: CoreManagerContainerClientQueueResponseHandler?
                public var responseHandler: APIClientQueueResponseHandler? {
                    return _responseHandler
                }

                public let clientQueues: Set<APIClientQueue>
                public let mainClientQueue: APIClientQueue

                private var cancellableStore = Set<AnyCancellable>()
                """)
            )
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
                .adding(parameter: FunctionParameter(name: "cacheSize", type: TypeIdentifier(name: "CacheSize"))
                    .with(defaultValue: Value.reference(+Reference.named("default")))
                )
                .adding(parameter: FunctionParameter(name: "client", type: .apiClient))
                .adding(parameter: FunctionParameter(name: "diskStoreConfig", type: TypeIdentifier(name: "DiskStoreConfig"))
                    .with(defaultValue: +.named("coreData"))
                )
                .adding(parameter: FunctionParameter(name: "responseHandler", type: .optional(wrapped: .named("CoreManagerContainerClientQueueResponseHandler")))
                    .with(defaultValue:
                        try descriptions.endpointsWithMergeableIdentifiers().isEmpty ?
                            Value.nil :
                            .named("RootClientQueueResponseHandler") | .call(Tuple())
                    )
                )
                .adding(member:
                    PlainCode(code: """

                    _responseHandler = responseHandler
                    var clientQueues = Set<APIClientQueue>()
                    var clientQueue: APIClientQueue

                    """)
                )
                .adding(members: descriptions.clientQueueNames.map { clientQueueName -> FunctionBodyMember in
                    PlainCode(code: """
                    let \(clientQueueName)ClientQueue = APIClientQueue.clientQueue(
                        for: "\\(CoreManagerContainer.self)_\(clientQueueName == Entity.mainClientQueueName ? "" : "\(clientQueueName)_")api_client_queue",
                        client: client,
                        scheduler: APIClientQueueDefaultScheduler()
                    )

                    """)
                })
                .adding(members: descriptions.entities.flatMap { entity -> [FunctionBodyMember] in
                    [
                        PlainCode(code: """
                        clientQueue = \(entity.clientQueueName)ClientQueue
                        """),
                        Assignment(
                            variable: entity.privateCoreManagerVariable.reference,
                            value: TypeIdentifier.coreManager().reference | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "stores", value: entity.typeID().reference + .named("stores") | .call(
                                    Tuple()
                                        .adding(parameter: TupleParameter(name: "with", value: Reference.named("client")))
                                        .adding(parameter: TupleParameter(name: "clientQueue", value: Reference.named("&clientQueue")))
                                        .adding(parameter: TupleParameter(name: "cacheLimit", value: entity.cacheSize.value))
                                        .adding(parameter: TupleParameter(name: "diskStoreConfig", value: Reference.named("diskStoreConfig")))
                                ))))
                        ),
                        PlainCode(code: """
                        clientQueues.insert(clientQueue)

                        """)
                    ]
                })
                .adding(member:
                    PlainCode(code: """
                    if let responseHandler = _responseHandler {
                        clientQueues.forEach { $0.register(responseHandler) }
                    }
                    self.clientQueues = clientQueues
                    self.mainClientQueue = mainClientQueue
                    """)
                )
                .adding(member: EmptyLine())
                .adding(member: Comment.comment("Init of lazy vars for thread-safety."))
                .adding(members: descriptions.entities.map { entity in
                    Assignment(
                        variable: Reference.named("_"),
                        value: entity.privateRelationshipManagerVariable.reference
                    )
                })
                .adding(member: EmptyLine())
                .adding(member:
                    PlainCode(code: """
                    _responseHandler?.managers = self
                    """)
                )
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
                .adding(parameter: FunctionParameter(
                    alias: "in",
                    name: "context",
                    type: TypeIdentifier(name: "_ReadContext").adding(genericParameter: .endpointResultPayload)
                ))
                .with(resultType:
                    .anyPublisher(of: .anySequence(element: .appAnyEntity), error: .managerError)
                )
                .adding(member: Switch(reference: .named("entityType"))
                    .adding(cases: descriptions.entities.map { entity in
                        SwitchCase()
                            .adding(value: entity.identifierTypeID().reference + .named("entityTypeUID"))
                            .adding(member: Return(value: entity.coreManagerVariable.reference + .named("get") | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "byIDs", value: .named("identifiers") + .named("lazy") + .named(.compactMap) | .block(FunctionBody()
                                        .adding(member: .named("$0") + .named("toRelationshipID") | .call())
                                    ) + .named("uniquified") | .call())
                                )
                                .adding(parameter: TupleParameter(name: "in", value: Reference.named("context")))
                            ) + .named("once") + .named(.map) | .block(FunctionBody()
                                .adding(member: .named("$0") + .named("lazy") + .named(.map) | .block(FunctionBody()
                                    .adding(member: +.named(entity.name.camelCased().variableCased()) | .call(Tuple()
                                        .adding(parameter: TupleParameter(value: Reference.named("$0")))
                                    ))
                                ) + .named("any"))
                            ) | +.named("eraseToAnyPublisher") | .call()))
                    })
                    .adding(case: SwitchCase(name: .default)
                        .adding(member:
                            Return(value: TypeIdentifier(name: "Fail").reference | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "error", value: +.named("notSupported")))
                            ) + .named("eraseToAnyPublisher") | .call())
                        )
                    )
                )
            )
    }

    private func payloadPersistenceManagerExtension() -> Extension {
        return Extension(type: .coreManagerContainer)
            .adding(inheritedType: .remoteStoreCachePayloadPersistenceManaging)
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .named("persistEntities"))
                .with(accessLevel: .public)
                .adding(parameter: FunctionParameter(alias: "from", name: "payload", type: .anyResultPayloadConvertible))
                .adding(parameter: FunctionParameter(name: "accessValidator", type: .optional(wrapped: .userAccessValidating)))
                .adding(members: descriptions
                    .entities
                    .filter { $0.persist }
                    .map { entity in
                        PlainCode(code: """

                        \(entity.coreManagerVariable.reference.swiftString)
                            .set(payload.allEntities(), in: WriteContext(dataTarget: .local, accessValidator: accessValidator))
                            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                            .store(in: &cancellableStore)
                        """)
                    }
                )
            )
    }
    
    private var defaultImplementationsExtensions: PlainCode {
        return PlainCode(code: """
        /// Manually add the function:
        /// ```
        /// static func stores(with client: APIClient,
        ///                    clientQueue: inout APIClientQueue,
        ///                    cacheLimit: Int,
        ///                    diskStoreConfig: CoreManagerContainer.DiskStoreConfig) -> Array<Storing<Self>>
        /// ```
        /// to an individual class adopting the Entity protocol to provide custom functionality

        extension LocalEntity {
            static func stores(with client: APIClient,
                               clientQueue: inout APIClientQueue,
                               cacheLimit: Int,
                               diskStoreConfig: CoreManagerContainer.DiskStoreConfig) -> Array<Storing<Self>> {
                let localStore = LRUStore<Self>(store: InMemoryStore().storing, limit: cacheLimit)
                return Array(arrayLiteral: localStore.storing)
            }
        }

        extension CoreDataEntity {
            static func stores(with client: APIClient,
                               clientQueue: inout APIClientQueue,
                               cacheLimit: Int,
                               diskStoreConfig: CoreManagerContainer.DiskStoreConfig) -> Array<Storing<Self>> {

                guard let coreDataManager = diskStoreConfig.coreDataManager else {
                    Logger.log(.error, "\\(Self.self): Cannot build \\(CoreDataStore<Self>.self) without a \\(CoreDataManager.self) instance.", assert: true)
                    return Array()
                }

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
                               cacheLimit: Int,
                               diskStoreConfig: CoreManagerContainer.DiskStoreConfig) -> Array<Storing<Self>> {
                let remoteStore = RemoteStore<Self>(clientQueue: clientQueue)
                return Array(arrayLiteral: remoteStore.storing)
            }
        }

        extension RemoteEntity where Self : CoreDataEntity {
            static func stores(with client: APIClient,
                               clientQueue: inout APIClientQueue,
                               cacheLimit: Int,
                               diskStoreConfig: CoreManagerContainer.DiskStoreConfig) -> Array<Storing<Self>> {

                guard let coreDataManager = diskStoreConfig.coreDataManager else {
                    Logger.log(.error, "\\(Self.self): Cannot build \\(CoreDataStore<Self>.self) without a \\(CoreDataManager.self) instance.", assert: true)
                    return Array()
                }

                let remoteStore = RemoteStore<Self>(clientQueue: clientQueue)
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
