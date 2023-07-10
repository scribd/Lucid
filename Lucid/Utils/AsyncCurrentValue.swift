//
//  AsyncCurrentValue.swift
//  Lucid
//
//  Created by Stephane Magne on 2023-05-15.
//  Copyright © 2023 Scribd. All rights reserved.
//

import Foundation

public protocol AsyncCurrentValueDelegate: AnyObject {

    func didRemoveFinalIterator() async
}

/**
    This class is meant to replicate Combine.CurrentValueSubject.

    The use case looks like this...

    In the calling class:

        Task {
            let currentValue = manager.currentValue
            for await value in currentValue where Task.isCancelled == false {
                // perform some action
            }
        }

     In the class owning AsyncCurrentValue:

        currentValue.update(newValue)
*/
public final actor AsyncCurrentValue<T> {

    public typealias Element = T?

    private(set) var value: Element

    private var repository = AsyncCurrentValueRepository<T>()

    public init(_ initialValue: Element) {
        self.value = initialValue
    }

    public nonisolated func makeAsyncIterator() -> AsyncCurrentValueIterator<T> {
        let iterator = AsyncCurrentValueIterator<T>(value: nil)
        Task {
            await repository.addIterator(iterator)
            await iterator.update(with: value)
        }
        return iterator
    }

    public func update(with updatedValue: Element) async {
        value = updatedValue
        await repository.update(with: updatedValue)
    }

    public func setDelegate(_ delegate: AsyncCurrentValueDelegate) async {
        await repository.setDelegate(delegate)
    }

    public func cancelIterator(_ iterator: AsyncCurrentValueIterator<T>) async {
        await iterator.update(with: nil)
        await repository.removeIterator(iterator)
    }
}

private enum IteratorCancelledError: Error {
    case continuousCancelled
}

public final actor AsyncCurrentValueIterator<T>: AsyncIteratorProtocol, AsyncSequence {

    public typealias Element = T?

    private var value: T?

    private var valueContinuation: CheckedContinuation<Element, any Error>?

    init(value: T?) {
        self.value = value
    }

    public nonisolated func makeAsyncIterator() -> AsyncCurrentValueIterator<T> {
        return self
    }

    public func next() async throws -> Element? {

        if Task.isCancelled {
            return nil
        } else if let storedValue = value {
            value = nil
            return storedValue
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                valueContinuation = continuation
            }
        }
    }

    func update(with updatedValue: Element) async {
        if Task.isCancelled {
            return
        } else if let continuation = valueContinuation {
            valueContinuation = nil
            continuation.resume(returning: updatedValue)
        } else {
            value = updatedValue
        }
    }
}

// MARK: - Repository

final actor AsyncCurrentValueRepository<T> {

    private var iterators: [WeakItem<AsyncCurrentValueIterator<T>>] = []

    private weak var delegate: AsyncCurrentValueDelegate?

    func setDelegate(_ delegate: AsyncCurrentValueDelegate) async {
        self.delegate = delegate
    }

    func addIterator(_ iterator: AsyncCurrentValueIterator<T>) async {
        iterators.append(WeakItem(iterator))
    }

    func removeIterator(_ iterator: AsyncCurrentValueIterator<T>) async {
        iterators = iterators.filter { $0.item !== iterator }
        await checkObservers()
    }

    func update(with updatedValue: T?) async {
        guard iterators.isEmpty == false else { return }

        iterators = iterators.filter { $0.item != nil }
        await checkObservers()

        for iterator in iterators {
            await iterator.item?.update(with: updatedValue)
        }
    }

    private func checkObservers() async {
        if iterators.isEmpty {
            await delegate?.didRemoveFinalIterator()
        }
    }
}

private class WeakItem<T: AnyObject> {

    weak var item: T?

    init(_ item: T) {
        self.item = item
    }
}
