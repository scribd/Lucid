//
//  Signal.swift
//  Lucid
//
//  Created by Théophane Rupin on 8/19/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import ReactiveKit
import Foundation

// MARK: - Error Substitutions

public extension Signal where Error == ManagerError {

    func substituteValueForNonCriticalFailure(_ value: Element) -> ReactiveKit.Signal<Element, ManagerError> {
        return self
            .substituteValueForInternetConnectionFailure(value)
            .substituteValueForUserAccessFailure(value)
    }

    func substituteValueForInternetConnectionFailure(_ value: Element) -> ReactiveKit.Signal<Element, ManagerError> {
        return flatMapError { managerError -> Signal<Element, ManagerError> in
            if managerError.isNetworkConnectionFailure {
                return Signal(just: value)
            } else {
                return .failed(managerError)
            }
        }
    }

    func substituteValueForUserAccessFailure(_ value: Element) -> ReactiveKit.Signal<Element, ManagerError> {
        return flatMapError { managerError -> Signal<Element, ManagerError> in
            if managerError.isUserAccessFailure {
                return Signal(just: value)
            } else {
                return .failed(managerError)
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

public extension Signal where Element: Sequence, Element.Element: Entity, Error == Never {

    var whenUpdatingAnything: SafeSignal<[(old: Element.Element?, new: Element.Element?)]> {
        return when(updatingOneOf: nil, entityRules: .all)
    }

    func when(updatingOneOf indices: [Element.Element.IndexName]?, entityRules: EntityMutationRule = .dataChangesOnly) -> SafeSignal<[(old: Element.Element?, new: Element.Element?)]> {
        var _lastElements: DualHashDictionary<Element.Element.Identifier, Element.Element>?
        let dispatchQueue = DispatchQueue(label: "\(Self.self):updates")

        return receive(on: dispatchQueue).compactMap { elements in
            defer { _lastElements = DualHashDictionary(elements.lazy.map { ($0.identifier, $0) }) }
            guard let lastElements = _lastElements else { return nil }

            var update: [(old: Element.Element?, new: Element.Element?)] = elements.compactMap { element in
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
        }
    }
}

public extension Signal where Element: Entity, Error == Never {

    var whenUpdatingAnything: SafeSignal<(old: Element?, new: Element?)> {
        return when(updatingOneOf: nil, entityRules: .all)
    }

    func when(updatingOneOf indices: [Element.IndexName]?, entityRules: EntityMutationRule = .dataChangesOnly) -> SafeSignal<(old: Element?, new: Element?)> {
        return map { [$0] }.when(updatingOneOf: indices, entityRules: entityRules).compactMap { $0.first }
    }
}

public extension Signal where Element: OptionalProtocol, Element.Wrapped: Entity, Error == Never {

    var whenUpdatingAnything: SafeSignal<(old: Element.Wrapped?, new: Element.Wrapped?)> {
        return when(updatingOneOf: nil, entityRules: .all)
    }

    func when(updatingOneOf indices: [Element.Wrapped.IndexName]?, entityRules: EntityMutationRule = .dataChangesOnly) -> SafeSignal<(old: Element.Wrapped?, new: Element.Wrapped?)> {
        return map { $0._unbox.flatMap { [$0] } ?? [] }.when(updatingOneOf: indices, entityRules: entityRules).compactMap { $0.first }
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
