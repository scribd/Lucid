//
//  CoreManagerProperty.swift
//  Lucid
//
//  Created by Stephane Magne on 3/15/22.
//  Copyright © 2022 Scribd. All rights reserved.
//

import Combine
import Foundation

final class CoreManagerProperty<Output: Equatable>: Publisher {

    typealias Failure = Never

    private let currentValue = CurrentValueSubject<Output?, Failure>(nil)

    // CoreManager

    var willAddFirstObserver: (() -> Void)?

    var willRemoveLastObserver: (() -> Void)?

    private let observerCountDispatchQueue = DispatchQueue(label: "\(CoreManagerProperty.self):observer_count")

    private let dataLock = NSRecursiveLock(name: "\(CoreManagerProperty.self):data_lock")

    private var observerCount = 0

    // Init

    var value: Output? {
        dataLock.lock()
        defer { dataLock.unlock() }

        return currentValue.value
    }

    func update(with value: Output) {
        dataLock.lock()
        defer { dataLock.unlock() }

        guard self.currentValue.value != value else { return }
        self.currentValue.value = value
    }

    // MARK: Publisher

    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        dataLock.lock()
        defer { dataLock.unlock() }

        observerCountDispatchQueue.async {
            self.observerCount += 1
            if self.observerCount == 1 {
                self.willAddFirstObserver?()
            }
        }

        let cancellable = currentValue
            .compactMap { $0 }
            .sink(receiveValue: { value in
                _ = subscriber.receive(value)
            })

        let subscription = CoreManagerSubscription<S>(subscriber, cancellable) {
            self.observerCountDispatchQueue.async {
                self.observerCount -= 1
                if self.observerCount == 0 {
                    self.willRemoveLastObserver?()
                }
            }
        }

        subscriber.receive(subscription: subscription)
    }
}

// MARK: - Subscription

private extension CoreManagerProperty {

    final class CoreManagerSubscription<S: Subscriber>: Subscription where S.Input == Output, S.Failure == Failure {

        private var subscriber: S?

        private var cancellable: AnyCancellable?

        private var didCancel: (() -> Void)?

        init(_ subscriber: S, _ cancellable: AnyCancellable, didCancel: @escaping () -> Void) {
            self.subscriber = subscriber
            self.cancellable = cancellable
            self.didCancel = didCancel
        }

        func cancel() {
            subscriber = nil
            didCancel?()
            didCancel = nil
        }

        func request(_ demand: Subscribers.Demand) { }
    }
}
