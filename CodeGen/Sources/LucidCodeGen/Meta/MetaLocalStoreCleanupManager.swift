//
//  MetaLocalStoreCleanupManager.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 9/18/19.
//

import Meta
import LucidCodeGenCore

struct MetaLocalStoreCleanupManager {
    
    let descriptions: Descriptions

    let reactiveKit: Bool
    
    func meta() throws -> FileBodyMember {
        let streamType = reactiveKit ? "Signal" : "AnyPublisher"

        return PlainCode(code: """
            public enum LocalStoreCleanupError: Error {
                case manager(name: String, error: ManagerError)
            }

            public protocol LocalStoreCleanupManaging {
                func removeAllLocalData() -> \(streamType)<Void, [LocalStoreCleanupError]>
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

                public func removeAllLocalData() -> \(streamType)<Void, [LocalStoreCleanupError]> {
                    return \(reactiveKit ? "Signal(combiningLatest: " : "")\(MetaCode(meta: Value.array(
                        descriptions.entities.filter({ $0.persist }).map { entity in
                            return Value.reference(entity.typeID().reference + .named("eraseLocalStore") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Reference.named("coreManagerProvider.\(entity.coreManagerVariable.name)")))
                            ))
                        })
                ))\(reactiveKit ? "," : "")
            \(reactiveKit ? """
                        combine: { (signals) -> LocalStoreCleanupResult in return signals.reduce(.success) { $0.merged(with: $1) } })
                        .tryMap { erasedResults -> Result<Void, [LocalStoreCleanupError]> in
                            switch erasedResults {
                            case .success:
                                return .success(())
                            case .failure(let cleanupErrors):
                                return .failure(cleanupErrors)
                            }
                        }
                        .first()
            """ : """
                        .publisher
                        .flatMap { $0 }
                        .collect()
                        .map { $0.reduce(LocalStoreCleanupResult.success) { $0.merged(with: $1) } }
                        .setFailureType(to: [LocalStoreCleanupError].self)
                        .flatMap { erasedResults -> AnyPublisher<Void, [LocalStoreCleanupError]> in
                            switch erasedResults {
                            case .success:
                                return Just(()).setFailureType(to: [LocalStoreCleanupError].self).eraseToAnyPublisher()
                            case .failure(let cleanupErrors):
                                return Fail(outputType: Void.self, failure: cleanupErrors).eraseToAnyPublisher()
                            }
                        }
                        .first()
                        .eraseToAnyPublisher()
            """)
                }
            }

            // MARK: - Utils

            enum LocalStoreCleanupResult {
                case success
                case failure([LocalStoreCleanupError])

                func merged(with result: LocalStoreCleanupResult) -> LocalStoreCleanupResult {
                    switch (self, result) {
                    case (.success, .failure(let error)),
                         (.failure(let error), .success):
                        return .failure(error)
                    case (.failure(let lhsError), .failure(let rhsError)):
                        return .failure(lhsError + rhsError)
                    case (.success, .success):
                        return .success
                    }
                }
            }

            extension LocalEntity {

                /// Manually add the function:
                /// `static func eraseLocalStore(_ manager: CoreManaging<Self, AppAnyEntity>) -> \(streamType)<LocalStoreCleanupResult, Never>`
                /// to an individual class adopting the Entity protocol to provide custom functionality

                static func eraseLocalStore(_ manager: CoreManaging<Self, AppAnyEntity>) -> \(streamType)<LocalStoreCleanupResult, Never> {
                    return manager
                        .removeAll(withQuery: .all, in: WriteContext<Self>(dataTarget: .local))
                        .map { _ in LocalStoreCleanupResult.success }
            \(reactiveKit ? """
                        .flatMapError { managerError -> SafeSignal<LocalStoreCleanupResult> in
                            let cleanupError = LocalStoreCleanupError.manager(name: "\\(manager.self)", error: managerError)
                            return SafeSignal(just: .failure([cleanupError]))
                        }
            """ : """
                        .catch { managerError -> Just<LocalStoreCleanupResult> in
                            let cleanupError = LocalStoreCleanupError.manager(name: "\\(manager.self)", error: managerError)
                            return Just(.failure([cleanupError]))
                        }
                        .eraseToAnyPublisher()
            """)
                }
            }
            """
        )
    }
}
