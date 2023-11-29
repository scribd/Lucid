//
//  MetaSupportUtils.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 9/18/19.
//

import Meta
import LucidCodeGenCore

struct MetaSupportUtils {
    
    let descriptions: Descriptions

    let moduleName: String
    
    func meta() throws -> FileBodyMember {
        return PlainCode(code: """
            // MARK: - Logger

            enum Logger {

                static var shared: Logging? {
                    get { return LucidConfiguration.logger }
                    set { LucidConfiguration.logger = newValue }
                }

                static func log(_ type: LogType,
                                _ message: @autoclosure () -> String,
                                domain: String = "\(moduleName)",
                                assert: Bool = false,
                                file: String = #file,
                                function: String = #function,
                                line: UInt = #line) {

                    shared?.log(type,
                                message(),
                                domain: domain,
                                assert: assert,
                                file: file,
                                function: function,
                                line: line)
                }
            }

            // MARK: - LocalStoreCleanupManager

            public enum LocalStoreCleanupError: Error {
                case manager(name: String, error: ManagerError)
            }

            public protocol LocalStoreCleanupManaging {
                func removeAllLocalData() async -> [LocalStoreCleanupError]
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

                public func removeAllLocalData() async -> [LocalStoreCleanupError] {
                    return await withTaskGroup(of: LocalStoreCleanupResult.self, returning: [LocalStoreCleanupError].self) { group in
            \(groupTasks().joined(separator: "\n"))

                        var errors: [LocalStoreCleanupError] = []
                        for await result in group {
                            switch result {
                            case .success:
                                break
                            case .failure(let resultErrors):
                                errors.append(contentsOf: resultErrors)
                            }
                        }

                        return errors
                    }
                }
            }

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
                /// `static func eraseLocalStore(_ manager: CoreManaging<Self, AppAnyEntity>) -> AnyPublisher<LocalStoreCleanupResult, Never>`
                /// to an individual class adopting the Entity protocol to provide custom functionality

                static func eraseLocalStore(_ manager: CoreManaging<Self, AppAnyEntity>) async -> LocalStoreCleanupResult {
                    do {
                        try await manager.removeAll(withQuery: .all, in: WriteContext<Self>(dataTarget: .local))
                        return .success
                    } catch let error as ManagerError {
                        return .failure([LocalStoreCleanupError.manager(name: "\\(manager.self)", error: error)])
                    } catch {
                        return .failure([])
                    }
                }
            }
            """
        )
    }

    private func groupTasks() -> [String] {
        var functionBody: [String] = []

        for entity in descriptions.entities.filter({ $0.persist }) {
            let member = """
                        group.addTask {
                            return await \(entity.typeID().swiftString).eraseLocalStore(\("self.coreManagerProvider.\(entity.coreManagerVariable.name))")
                        }
            """

            functionBody.append(member)
        }
        return functionBody
    }
}
