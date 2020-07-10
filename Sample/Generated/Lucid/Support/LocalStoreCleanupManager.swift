//
// LocalStoreCleanupManager.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid
import Combine

public enum LocalStoreCleanupError: Error {
    case manager(name: String, error: ManagerError)
}

public protocol LocalStoreCleanupManaging {
    func removeAllLocalData() -> AnyPublisher<Void, [LocalStoreCleanupError]>
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

    public func removeAllLocalData() -> AnyPublisher<Void, [LocalStoreCleanupError]> {
        return [eraseLocalStore(coreManagerProvider.genreManager), eraseLocalStore(coreManagerProvider.movieManager)]
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

    private func eraseLocalStore<E>(_ manager: CoreManaging<E, AppAnyEntity>) -> AnyPublisher<EraseResult, Never> {
        return manager
            .removeAll(withQuery: .all, in: WriteContext<E>(dataTarget: .local))
            .map { _ in EraseResult.success }
            .catch { managerError -> Just<EraseResult> in
                let cleanupError = LocalStoreCleanupError.manager(name: "\(manager.self)", error: managerError)
                return Just(EraseResult.error([cleanupError]))
            }
            .eraseToAnyPublisher()

    }
}
