//
//  CoreManagerProperty.swift
//  Lucid
//
//  Created by Stephane Magne on 3/15/22.
//  Copyright © 2022 Scribd. All rights reserved.
//

import Combine
import Foundation

final actor CoreManagerProperty<Output: Equatable> {

    let stream = AsyncCurrentValue<Output?>(nil)

    init() async {
        await stream.setDelegate(self)
    }

    // CoreManager

    private var didRemoveLastObserver: (() async -> Void)?

    func setDidRemoveLastObserver(_ block: @escaping () async -> Void) async {
        didRemoveLastObserver = block
    }

    func update(with value: Output) async {
        guard await self.stream.value != value else { return }
        await stream.update(with: value)
    }

    func value() async -> Output? {
        return await stream.value
    }
}

// MARK: - AsyncCurrentValueDelegate

extension CoreManagerProperty: AsyncCurrentValueDelegate {

    func didRemoveFinalIterator() async {
        await didRemoveLastObserver?()
    }
}

// MARK: - Combine helper to transpose async signals to Publishers

final class CoreManagerAsyncToCombineProperty<Output: Equatable, Failure: Error> {

    private let currentValue = CurrentValueSubject<Output?, Failure>(nil)

    private let continuousCurrentValue = CurrentValueSubject<Output?, Failure>(nil)

    private let cancellable = CancellableBox()

    // Swift Concurrency

    private let signals: Task<(once: Output, continuous: AsyncStream<Output>), Error>

    var once: CoreManagerCombineProperty<Output, Failure> {
        return CoreManagerCombineProperty<Output, Failure>(signals, type: .once)
    }

    var continuous: AnySafePublisher<Output> {
        return CoreManagerCombineProperty<Output, Failure>(signals, type: .continuous).suppressError()
    }

    init(_ signalFunction: @escaping () async throws -> (once: Output, continuous: AsyncStream<Output>)) {
        self.signals = Task {
            return try await signalFunction()
        }
    }
}

final class CoreManagerCombineProperty<Output: Equatable, Failure: Error>: Publisher {

    enum PublisherType {
        case once
        case continuous
    }

    private let currentValue = CurrentValueSubject<Output?, Failure>(nil)

    private let isFirstSubscriber = PropertyBox<Bool>(false, atomic: true)

    // Swift Concurrency

    private let signals: Task<(once: Output, continuous: AsyncStream<Output>), Error>

    private let type: PublisherType

    private let asyncTasks = AsyncTasks()

    init(_ signals: Task<(once: Output, continuous: AsyncStream<Output>), Error>, type: PublisherType) {
        self.signals = signals
        self.type = type
    }

    // MARK: Publisher

    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {

        let subscription = CoreManagerSubscription<S>(subscriber) { [weak self] in
            guard let self = self else { return }
            Task {
                await self.asyncTasks.cancel()
            }
        }

        subscriber.receive(subscription: subscription)

        subscription.cancellable = currentValue
            .compactMap { $0 }
            .sink(receiveCompletion: { [weak self] terminal in
                guard self != nil else { return }
                subscriber.receive(completion: terminal)
            }, receiveValue: { [weak self] value in
                guard let self = self else { return }
                _ = subscriber.receive(value)
                switch self.type {
                case .once:
                    subscriber.receive(completion: .finished)
                case .continuous:
                    return
                }
            })

        if isFirstSubscriber.value == false {
            isFirstSubscriber.value = true

            Task {
                do {
                    switch self.type {
                    case .once:
                        let result = try await signals.value.once
                        self.currentValue.send(result)
                        self.currentValue.send(completion: .finished)

                    case .continuous:
                        Task {
                            for await value in try await signals.value.continuous where Task.isCancelled == false {
                                self.currentValue.send(value)
                            }
                        }.store(in: self.asyncTasks)
                    }
                } catch let error as Failure {
                    self.currentValue.send(completion: .failure(error))
                }
            }.store(in: asyncTasks)
        }
    }
}

// MARK: - Subscription

private extension CoreManagerCombineProperty {

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
