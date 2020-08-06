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
                            return Value.reference(Reference.named("eraseLocalStore") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Reference.named("coreManagerProvider.\(entity.coreManagerVariable.name)")))
                            ))
                        })
                ))\(reactiveKit ? "," : "")
            \(reactiveKit ? """
                        combine: { (signals) -> EraseResult in return signals.reduce(.success) { $0.merged(with: $1) } })
                        .tryMap { erasedResults -> Result<Void, [LocalStoreCleanupError]> in
                            switch erasedResults {
                            case .success:
                                return .success(())
                            case .error(let cleanupErrors):
                                return .failure(cleanupErrors)
                            }
                        }
                        .first()
            """ : """
                        .publisher
                        .flatMap { $0 }
                        .collect()
                        .map { $0.reduce(EraseResult.success) { $0.merged(with: $1) } }
                        .setFailureType(to: [LocalStoreCleanupError].self)
                        .flatMap { erasedResults -> AnyPublisher<Void, [LocalStoreCleanupError]> in
                            switch erasedResults {
                            case .success:
                                return Just(()).setFailureType(to: [LocalStoreCleanupError].self).eraseToAnyPublisher()
                            case .error(let cleanupErrors):
                                return Fail(outputType: Void.self, failure: cleanupErrors).eraseToAnyPublisher()
                            }
                        }
                        .first()
                        .eraseToAnyPublisher()
            """)
                }
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
                
                private func eraseLocalStore<E>(_ manager: CoreManaging<E, AppAnyEntity>) -> \(streamType)<EraseResult, Never> {
                    return manager
                        .removeAll(withQuery: .all, in: WriteContext<E>(dataTarget: .local))
                        .map { _ in EraseResult.success }
            \(reactiveKit ? """
                        .flatMapError { managerError -> SafeSignal<EraseResult> in
                            let cleanupError = LocalStoreCleanupError.manager(name: "\\(manager.self)", error: managerError)
                            return SafeSignal(just: EraseResult.error([cleanupError]))
                        }
            """ : """
                        .catch { managerError -> Just<EraseResult> in
                            let cleanupError = LocalStoreCleanupError.manager(name: "\\(manager.self)", error: managerError)
                            return Just(EraseResult.error([cleanupError]))
                        }
                        .eraseToAnyPublisher()
            """)

                }
            }
            """
        )
    }
}
