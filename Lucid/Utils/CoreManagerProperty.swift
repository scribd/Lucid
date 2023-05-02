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

        self.observerCount += 1
        if self.observerCount == 1 {
            self.willAddFirstObserver?()
        }

        let subscription = CoreManagerSubscription<S>(subscriber) {
            self.dataLock.lock()
            defer { self.dataLock.unlock() }

            self.observerCount -= 1
            if self.observerCount == 0 {
                self.willRemoveLastObserver?()
            }
        }

        subscriber.receive(subscription: subscription)

        let lock = dataLock
        subscription.cancellable = currentValue
            .compactMap { $0 }
            .sink(receiveValue: { [weak self] value in
                guard self != nil else { return }
                lock.lock()
                defer { lock.unlock() }
                _ = subscriber.receive(value)
            })
    }
}

// MARK: - Subscription

private extension CoreManagerProperty {

    final class CoreManagerSubscription<S: Subscriber>: Subscription where S.Input == Output, S.Failure == Failure {

        private var subscriber: S?

        fileprivate var cancellable: AnyCancellable?

        private var didCancel: (() -> Void)?

        init(_ subscriber: S, didCancel: @escaping () -> Void) {
            self.subscriber = subscriber
            self.didCancel = didCancel
        }

        func cancel() {
            subscriber = nil
            cancellable = nil
            didCancel?()
            didCancel = nil
        }

        func request(_ demand: Subscribers.Demand) { }
    }
}
