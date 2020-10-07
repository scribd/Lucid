//
// SupportUtils.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid
import Combine


// MARK: - Logger

enum Logger {

    static var shared: Logging? {
        get { return LucidConfiguration.logger }
        set { LucidConfiguration.logger = newValue }
    }

    static func log(_ type: LogType,
                    _ message: @autoclosure () -> String,
                    domain: String = "Sample",
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
        return [Genre.eraseLocalStore(coreManagerProvider.genreManager), Movie.eraseLocalStore(coreManagerProvider.movieManager)]
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

    static func eraseLocalStore(_ manager: CoreManaging<Self, AppAnyEntity>) -> AnyPublisher<LocalStoreCleanupResult, Never> {
        return manager
            .removeAll(withQuery: .all, in: WriteContext<Self>(dataTarget: .local))
            .map { _ in LocalStoreCleanupResult.success }
            .catch { managerError -> Just<LocalStoreCleanupResult> in
                let cleanupError = LocalStoreCleanupError.manager(name: "\(manager.self)", error: managerError)
                return Just(.failure([cleanupError]))
            }
            .eraseToAnyPublisher()
    }
}
