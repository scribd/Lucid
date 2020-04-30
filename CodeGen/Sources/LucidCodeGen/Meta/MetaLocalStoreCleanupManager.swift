//
//  MetaLocalStoreCleanupManager.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 9/18/19.
//

import Meta

struct MetaLocalStoreCleanupManager {
    
    let descriptions: Descriptions
    
    func meta() throws -> FileBodyMember {
        return PlainCode(code: """
            public enum LocalStoreCleanupError: Error {
                case manager(name: String, error: ManagerError)
            }
            
            public protocol LocalStoreCleanupManaging {
                func removeAllLocalData() -> Provider<Void, [LocalStoreCleanupError]>
            }
            
            public final class LocalStoreCleanupManager: LocalStoreCleanupManaging {
            
                private let coreManagerProvider: CoreManagerResolver
            
                // MARK: Initializers
            
                init(coreManagerProvider: CoreManagerResolver) {
                    self.coreManagerProvider = coreManagerProvider
                }
            
                public convenience init(coreManagers: CoreManagerContainer) {
                    self.init(coreManagerProvider: coreManagers)
                }
            
                // MARK: API

            \(MetaCode(indentation: 1, meta:
                Function(kind: .named("removeAllLocalData"))
                .with(accessLevel: .public)
                .with(resultType: .named("Provider<Void, [LocalStoreCleanupError]>"))
                .adding(member: Return(value: .named("Provider") | .block(
                    FunctionBody()
                        .adding(member: Return(value: .named("Signal") | .call(Tuple()
                            .adding(parameter: TupleParameter(name: "combiningLatest", value: Value.array(
                                descriptions.entities.filter({ $0.persist }).map { entity in
                                    return Value.reference(Reference.named("eraseLocalStore") | .call(Tuple()
                                        .adding(parameter: TupleParameter(value: Reference.named("coreManagerProvider.\(entity.coreManagerVariable.name)")))
                                    ))
                                })
                            ))
                            .adding(parameter: TupleParameter(name: "combine", value:
                                FunctionBody()
                                    .with(resultType: TypeIdentifier(name: "EraseResult"))
                                    .adding(parameter: FunctionBodyParameter(name: "signals"))
                                    .adding(member: Return(value: Value.reference(Reference.named("signals") | +.named("reduce") | .call(Tuple()
                                        .adding(parameter: TupleParameter(value: Value.reference(Reference.named(".success"))))) | .block(
                                            FunctionBody()
                                                .adding(member: Reference.named("$0") | +.named("merged") | .call(Tuple()
                                                    .adding(parameter: TupleParameter(name: "with", value: Reference.named("$1")))
                                                ))
                                        )
                                    )))
                            ))
                        )))
                        .adding(member: PlainCode(code:
                        """
                        .tryMap { erasedResults -> Result<Void, [LocalStoreCleanupError]> in
                            switch erasedResults {
                            case .success:
                                return .success(())
                            case .error(let cleanupErrors):
                                return .failure(cleanupErrors)
                            }
                        }
                        .first()
                        """))
                )))
            ))
            }

            // MARK: - Private

            private extension LocalStoreCleanupManager {
                
                enum EraseResult {
                    case success
                    case error([LocalStoreCleanupError])
                    
                    func merged(with result: EraseResult) -> EraseResult {
                        switch (self, result) {
                        case (.success, .error(let error)),
                             (.error(let error), .success):
                            return .error(error)
                        case (.error(let lhsError), .error(let rhsError)):
                            return .error(lhsError + rhsError)
                        case (.success, .success):
                            return .success
                        }
                    }
                }
                
                private func eraseLocalStore<E>(_ manager: CoreManaging<E, AppAnyEntity>) -> SafeSignal<EraseResult> {
                    return manager
                        .removeAll(withQuery: .all, in: WriteContext<E>(dataTarget: .local))
                        .flatMapLatest { _ in
                            return Signal(just: EraseResult.success)
                        }
                        .flatMapError { managerError -> SafeSignal<EraseResult> in
                            let cleanupError = LocalStoreCleanupError.manager(name: "\\(manager.self)", error: managerError)
                            return SafeSignal(just: EraseResult.error([cleanupError]))
                        }
                }
            }
            """
        )
    }
}
