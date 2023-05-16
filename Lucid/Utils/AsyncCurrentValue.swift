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
public final class AsyncCurrentValue<Element>: AsyncSequence {

    private(set) var value: Element

    private var repository = AsyncCurrentValueRepository<Element>()

    public init(_ initialValue: Element) {
        self.value = initialValue
    }

    public func makeAsyncIterator() -> AsyncCurrentValueIterator<Element> {
        let iterator = AsyncCurrentValueIterator<Element>(value: value)
        Task {
            await repository.addIterator(iterator)
        }
        return iterator
    }

    public func update(with updatedValue: Element) {
        value = updatedValue
        Task {
            await repository.update(with: updatedValue)
        }
    }

    public func setDelegate(_ delegate: AsyncCurrentValueDelegate) {
        Task {
            await repository.setDelegate(delegate)
        }
    }
}

public final actor AsyncCurrentValueIterator<Element>: AsyncIteratorProtocol {

    private var value: Element?

    private var valueContinuation: CheckedContinuation<Element, Never>?

    init(value: Element) {
        self.value = value
    }

    public func next() async throws -> Element? {
        if Task.isCancelled {
            return nil
        } else if let storedValue = value {
            value = nil
            return storedValue
        } else {
            return await withCheckedContinuation { continuation in
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

// MARK: - Private

private final actor AsyncCurrentValueRepository<Element> {

    private var iterators: [WeakItem<AsyncCurrentValueIterator<Element>>] = []

    private weak var delegate: AsyncCurrentValueDelegate?

    func setDelegate(_ delegate: AsyncCurrentValueDelegate) async {
        self.delegate = delegate
    }

    func addIterator(_ iterator: AsyncCurrentValueIterator<Element>) async {
        iterators.append(WeakItem(iterator))
    }

    func update(with updatedValue: Element) async {
        let wasPopulated = iterators.isEmpty == false
        let validIterators = iterators.filter { $0.item != nil }
        for iterator in iterators {
            await iterator.item?.update(with: updatedValue)
        }
        iterators = validIterators
        if iterators.isEmpty && wasPopulated {
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
