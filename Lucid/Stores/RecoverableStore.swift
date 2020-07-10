//
//  RecoverableStore.swift
//  Lucid
//
//  Created by Ibrahim Sha'ath on 2/4/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

public final class RecoverableStore<E: Entity> {

    private let mainStore: Storing<E>
    private let recoveryStore: Storing<E>

    public let level: StoreLevel

    private let operationQueue = AsyncOperationQueue()

    public init(mainStore: Storing<E>,
                recoveryStore: Storing<E>) {

        if mainStore.level != .disk {
            Logger.log(.error, "\(RecoverableStore.self) mainStore must be a disk store", assert: true)
        }

        if recoveryStore.level != .disk {
            Logger.log(.error, "\(RecoverableStore.self) recoveryStore must be a disk store", assert: true)
        }

        self.mainStore = mainStore
        self.recoveryStore = recoveryStore
        self.level = mainStore.level

        recover()
    }
}

extension RecoverableStore: StoringConvertible {

    public func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        operationQueue.run(title: "\(RecoverableStore.self):get") { operationCompletion in
            self.mainStore.get(withQuery: query, in: context) { result in
                completion(result)
                operationCompletion()
            }
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        operationQueue.run(title: "\(RecoverableStore.self):search") { operationCompletion in
            self.mainStore.search(withQuery: query, in: context) { result in
                completion(result)
                operationCompletion()
            }
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {

        operationQueue.run(title: "\(RecoverableStore.self):set") { operationCompletion in
            self.mainStore.set(entities, in: context) { mainStoreResult in
                self.recoveryStore.set(entities, in: context) { recoveryStoreResult in
                    if recoveryStoreResult == nil {
                        Logger.log(.error, "\(RecoverableStore.self) could not set entities \(entities.map { $0.identifier }) in recovery store. Unexpectedly received nil.", assert: true)
                    } else if let error = recoveryStoreResult?.error {
                        Logger.log(.error, "\(RecoverableStore.self) could not set entities \(entities.map { $0.identifier }) in recovery store: \(error)", assert: true)
                    }
                    completion(mainStoreResult)
                    operationCompletion()
                }
            }
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {

        operationQueue.run(title: "\(RecoverableStore.self):remove_all") { operationCompletion in
            self.mainStore.removeAll(withQuery: query, in: context) { mainStoreResult in
                self.recoveryStore.removeAll(withQuery: query, in: context) { recoveryStoreResult in
                    if recoveryStoreResult == nil {
                        Logger.log(.error, "\(RecoverableStore.self) could not remove entities matching query: \(query) from recovery store. Unexpectedly received nil.", assert: true)
                    } else if let error = recoveryStoreResult?.error {
                        Logger.log(.error, "\(RecoverableStore.self) could not remove entities matching query: \(query) from recovery store: \(error)", assert: true)
                    }
                    completion(mainStoreResult)
                    operationCompletion()
                }
            }
        }
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {

        operationQueue.run(title: "\(RecoverableStore.self):remove") { operationCompletion in
            self.mainStore.remove(identifiers, in: context) { mainStoreResult in
                self.recoveryStore.remove(identifiers, in: context) { (recoveryStoreResult) in
                    if recoveryStoreResult == nil {
                        Logger.log(.error, "\(RecoverableStore.self) could not remove entities \(identifiers) from recovery store. Unexpectedly received nil.", assert: true)
                    } else if let error = recoveryStoreResult?.error {
                        Logger.log(.error, "\(RecoverableStore.self) could not remove entities \(identifiers) from recovery store: \(error)", assert: true)
                    }
                    completion(mainStoreResult)
                    operationCompletion()
                }
            }
        }
    }
}

private extension RecoverableStore {

    func recover() {

        let query = Query<E>.all

        operationQueue.run(title: "\(RecoverableStore.self):recover") { operationCompletion in
            self.mainStore.search(withQuery: query, in: ReadContext<E>()) { result in
                switch result {
                case .success(let entities):
                    if entities.isEmpty {
                        Logger.log(.warning, "\(RecoverableStore.self) will employ recovery store: main store has no data.")
                        self.writeRecoveryStoreToMainStore(withQuery: query) { operationCompletion() }
                    } else {
                        Logger.log(.info, "\(RecoverableStore.self) will overwrite recovery store: main store has data.")
                        self.recoveryStore.removeAll(withQuery: .all, in: WriteContext(dataTarget: .local)) { result in
                            if result == nil {
                                Logger.log(.error, "\(RecoverableStore.self) could not clear recovery store. Unexpectedly received nil.", assert: true)
                            } else if let error = result?.error {
                                Logger.log(.error, "\(RecoverableStore.self) could not clear recovery store: \(error)", assert: true)
                            }
                            self.recoveryStore.set(entities, in: WriteContext(dataTarget: .local)) { result in
                                if result == nil {
                                    Logger.log(.error, "\(RecoverableStore.self) could not overwrite recovery store. Unexpectedly received nil.", assert: true)
                                } else if let error = result?.error {
                                    Logger.log(.error, "\(RecoverableStore.self) could not overwrite recovery store: \(error)", assert: true)
                                } else {
                                    Logger.log(.info, "\(RecoverableStore.self) successfully overwrote recovery store.")
                                }
                                operationCompletion()
                            }
                        }
                    }
                case .failure(let error):
                    Logger.log(.error, "\(RecoverableStore.self) will employ recovery store: main store encountered error: \(error)", assert: true)
                    self.writeRecoveryStoreToMainStore(withQuery: query) { operationCompletion() }
                }
            }
        }
    }

    private func writeRecoveryStoreToMainStore(withQuery query: Query<E>, completion: @escaping () -> Void) {
        recoveryStore.search(withQuery: query, in: ReadContext<E>()) { result in
            switch result {
            case .success(let entities):
                guard entities.isEmpty == false else {
                    Logger.log(.info, "\(RecoverableStore.self) will not overwrite main store: recovery store has no data.")
                    completion()
                    return
                }
                self.mainStore.set(entities, in: WriteContext(dataTarget: .local)) { result in
                    if result == nil {
                        Logger.log(.error, "\(RecoverableStore.self) could not set entities: \(entities.map { $0.identifier }) in main store. Unexpectedly received nil.", assert: true)
                    } else if let error = result?.error {
                        Logger.log(.error, "\(RecoverableStore.self) could not set entities: \(entities.map { $0.identifier }) in main store: \(error)", assert: true)
                    } else {
                        Logger.log(.info, "\(RecoverableStore.self) successfully overwrote main store.")
                    }
                    completion()
                }
            case .failure(let error):
                Logger.log(.error, "\(RecoverableStore.self): recovery store encountered error: \(error)", assert: true)
                completion()
            }
        }
    }
}
