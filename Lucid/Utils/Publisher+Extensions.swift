//
//  Publisher+Extensions.swift
//  Lucid
//
//  Created by Stephane Magne on 1/28/22.
//  Copyright © 2022 Scribd. All rights reserved.
//

#if !LUCID_REACTIVE_KIT
import Combine

// MARK: - Typealiases

public typealias SafePublisher<Output> = AnyPublisher<Output, Never>

// MARK: - Flat Map Errors

public extension Publisher {

    /// Transform an error into a result with a new error type. This allows the call-site to transform an error into successful output, or into a new error value.
    /// - Note: The original Publisher will still be completed, so this can only be used on 'once' signals.
    func flatMapError<F>(_ transform: @escaping (Failure) -> Result<Output, F>) -> AnyPublisher<Output, F> where F: Error {
        return ErrorTransformSubject<Output, Failure, F>(observing: eraseToAnyPublisher(), transform: transform).eraseToAnyPublisher()
    }

    /// Transform an error into a new error type.
    /// - Note: The original Publisher will still be completed, so this can only be used on 'once' signals.
    func flatMapError<F>(_ transform: @escaping (Failure) -> F) -> AnyPublisher<Output, F> where F: Error {
        return flatMapError { error -> Result<Output, F> in
            return .failure(transform(error))
        }
    }

    /// Transform an error into successful output.
    /// - Note: The original Publisher will still be completed, so this can only be used on 'once' signals.
    func flatMapError(_ transform: @escaping (Failure) -> Output) -> AnyPublisher<Output, Failure> {
        return flatMapError { error -> Result<Output, Failure> in
            return .success(transform(error))
        }
    }
}

// MARK: - Error Substitutions

public extension AnyPublisher where Failure == ManagerError {

    func substituteValueForNonCriticalFailure(_ value: Output) -> AnyPublisher<Output, ManagerError> {
        return self
            .substituteValueForInternetConnectionFailure(value)
            .substituteValueForUserAccessFailure(value)
    }

    func substituteValueForInternetConnectionFailure(_ value: Output) -> AnyPublisher<Output, ManagerError> {

        return flatMapError { managerError -> Result<Output, ManagerError> in
            if managerError.isNetworkConnectionFailure {
                return .success(value)
            } else {
                return .failure(managerError)
            }
        }
    }

    func substituteValueForUserAccessFailure(_ value: Output) -> AnyPublisher<Output, ManagerError> {
        return flatMapError { managerError -> Result<Output, ManagerError> in
            if managerError.isUserAccessFailure {
                return .success(value)
            } else {
                return .failure(managerError)
            }
        }
    }
}

// MARK: - Mutation Filtering

public struct EntityMutationRule: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let insertions = EntityMutationRule(rawValue: 1 << 0)
    public static let deletions = EntityMutationRule(rawValue: 1 << 1)

    public static let dataChangesOnly: EntityMutationRule = []
    public static let all: EntityMutationRule = [.insertions, .deletions]
}

public extension Publisher where Output: Sequence, Output.Element: Entity, Failure == Never {

    var whenUpdatingAnything: SafePublisher<[(old: Output.Element?, new: Output.Element?)]> {
        return when(updatingOneOf: nil, entityRules: .all)
    }

    func when(updatingOneOf indices: [Output.Element.IndexName]?, entityRules: EntityMutationRule = .dataChangesOnly) -> SafePublisher<[(old: Output.Element?, new: Output.Element?)]> {
        var _lastElements: DualHashDictionary<Output.Element.Identifier, Output.Element>?
        let dispatchQueue = DispatchQueue(label: "\(Self.self):updates")

        return receive(on: dispatchQueue).compactMap { elements -> [(old: Output.Element?, new: Output.Element?)]? in
            defer { _lastElements = DualHashDictionary(elements.lazy.map { ($0.identifier, $0) }) }
            guard let lastElements = _lastElements else { return nil }

            var update: [(old: Output.Element?, new: Output.Element?)] = elements.compactMap { element in
                guard let lastElement = lastElements[element.identifier] else {
                    if entityRules.contains(.insertions) {
                        return (nil, element)
                    } else {
                        return nil
                    }
                }

                let shouldUpdate = indices?.contains { index in
                    element.entityIndexValue(for: index) != lastElement.entityIndexValue(for: index)
                } ?? true

                return shouldUpdate ? (lastElement, element) : nil
            }

            if entityRules.contains(.deletions) {
                let deletedIndices = lastElements.subtractingKeys(elements.lazy.map { $0.identifier }.compactMap { $0})
                update.append(contentsOf: deletedIndices.map { (old: lastElements[$0], new: nil) })
            }

            return update.isEmpty ? nil : update
        }.eraseToAnyPublisher()
    }
}

public extension Publisher where Output: Entity, Failure == Never {

    var whenUpdatingAnything: SafePublisher<(old: Output?, new: Output?)> {
        return when(updatingOneOf: nil, entityRules: .all)
    }

    func when(updatingOneOf indices: [Output.IndexName]?, entityRules: EntityMutationRule = .dataChangesOnly) -> SafePublisher<(old: Output?, new: Output?)> {
        return map { [$0] }.when(updatingOneOf: indices, entityRules: entityRules).compactMap { $0.first }.eraseToAnyPublisher()
    }
}

public extension Publisher where Output: OptionalProtocol, Output.Wrapped: Entity, Failure == Never {

    var whenUpdatingAnything: SafePublisher<(old: Output.Wrapped?, new: Output.Wrapped?)> {
        return when(updatingOneOf: nil, entityRules: .all)
    }

    func when(updatingOneOf indices: [Output.Wrapped.IndexName]?, entityRules: EntityMutationRule = .dataChangesOnly) -> SafePublisher<(old: Output.Wrapped?, new: Output.Wrapped?)> {
        return map { $0._unbox.flatMap { [$0] } ?? [] }.when(updatingOneOf: indices, entityRules: entityRules).compactMap { $0.first }.eraseToAnyPublisher()
    }
}

// MARK: - OptionalProtocol

public protocol OptionalProtocol {
    associatedtype Wrapped
    var _unbox: Optional<Wrapped> { get }
    init(nilLiteral: ())
    init(_ some: Wrapped)
}

extension Optional: OptionalProtocol {

    public var _unbox: Optional<Wrapped> {
        return self
    }
}

// MARK: - Error Helpers

public extension ManagerError {

    var isNetworkConnectionFailure: Bool {

        switch self {
        case .notSupported,
             .conflict,
             .logicalError,
             .userAccessInvalid:
            return false
        case .store(let storeError):
            return storeError.isNetworkConnectionFailure
        }
    }

    var isUserAccessFailure: Bool {

        switch self {
        case .notSupported,
             .conflict,
             .logicalError,
             .store:
            return false
        case .userAccessInvalid:
            return true
        }
    }

    var shouldFallBackToLocalStore: Bool {
        switch self {
        case .notSupported,
             .conflict,
             .logicalError,
             .userAccessInvalid:
            return false
        case .store(let storeError):
            return storeError.shouldFallBackToLocalStore
        }
    }
}

public extension StoreError {

    var isNetworkConnectionFailure: Bool {
        switch self {
        case .api(let apiError):
            return apiError.isNetworkConnectionFailure
        case .composite,
             .unknown,
             .notSupported,
             .notFoundInPayload,
             .emptyStack,
             .invalidCoreDataState,
             .invalidCoreDataEntity,
             .coreData,
             .invalidContext,
             .identifierNotSynced,
             .identifierNotFound,
             .emptyResponse:
            return false
        }
    }

    var isEmptyResponse: Bool {
        switch self {
        case .emptyResponse:
            return true
        case .api,
             .composite,
             .unknown,
             .notSupported,
             .notFoundInPayload,
             .emptyStack,
             .invalidCoreDataState,
             .invalidCoreDataEntity,
             .coreData,
             .invalidContext,
             .identifierNotSynced,
             .identifierNotFound:
            return false
        }
    }

    var shouldFallBackToLocalStore: Bool {
        return isNetworkConnectionFailure || isEmptyResponse
    }
}

public extension APIError {

    var isNetworkConnectionFailure: Bool {
        switch self {
        case .network(.networkConnectionFailure):
            return true
        case .api,
             .deserialization,
             .network,
             .networkingProtocolIsNotHTTP,
             .url,
             .other:
            return false
        }
    }
}

extension Array: Error where Element: Error {}

// MARK: - ErrorTransformSubject

private final class ErrorTransformSubject<Output, OriginalFailure, Failure>: Publisher where OriginalFailure: Error, Failure: Error {

    private var publisher: AnyPublisher<Output, OriginalFailure>?

    private var transform: ((OriginalFailure) -> Result<Output, Failure>)?

    public init(observing publisher: AnyPublisher<Output, OriginalFailure>, transform: @escaping (OriginalFailure) -> Result<Output, Failure>) {
        self.publisher = publisher
        self.transform = transform
    }

    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        guard let publisher = publisher, let transform = transform else { return }

        let cancellable = publisher
            .sink(receiveCompletion: { error in
                switch error {
                case .failure(let originalError):
                    let transformedError = transform(originalError)
                    switch transformedError {
                    case .success(let value):
                        _ = subscriber.receive(value)
                    case .failure(let errorValue):
                        subscriber.receive(completion: .failure(errorValue))
                    }
                case .finished:
                    subscriber.receive(completion: .finished)
                }
            }, receiveValue: { value in
                  _ = subscriber.receive(value)
            })

        let subscription = ErrorTransformSubject(subscriber, cancellable)
        subscriber.receive(subscription: subscription)

        self.publisher = nil
        self.transform = nil
    }
}

// MARK: - Subscription

private extension ErrorTransformSubject {

    final class ErrorTransformSubject<S: Subscriber>: Subscription where S.Input == Output, S.Failure == Failure {

        private var subscriber: S?

        private var cancellable: Cancellable?

        init(_ subscriber: S, _ cancellable: Cancellable) {
            self.subscriber = subscriber
            self.cancellable = cancellable
        }

        func cancel() {
            cancellable = nil
            subscriber = nil
        }

        func request(_ demand: Subscribers.Demand) { }
    }
}
#endif
