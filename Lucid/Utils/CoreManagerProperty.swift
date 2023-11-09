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
        return await stream.value ?? nil
    }
}

// MARK: - AsyncCurrentValueDelegate

extension CoreManagerProperty: AsyncCurrentValueDelegate {

    func didRemoveFinalIterator() async {
        await didRemoveLastObserver?()
    }
}

// MARK: - Combine helper to transpose async signals to Publishers

final class CoreManagerAsyncToCombineProperty<E: Entity, Failure: Error> {

    private let currentValue = CurrentValueSubject<QueryResult<E>?, Failure>(nil)

    private let continuousCurrentValue = CurrentValueSubject<QueryResult<E>?, Failure>(nil)

    private let cancellable = CancellableBox()

    // Swift Concurrency

    private let operationQueue: AsyncOperationQueue

    private let wrappedSignals: () async throws -> (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>)

    var once: CoreManagerCombineProperty<E, Failure> {
        return CoreManagerCombineProperty<E, Failure>(operationQueue, wrappedSignals, type: .once)
    }

    var continuous: AnySafePublisher<QueryResult<E>> {
        return CoreManagerCombineProperty<E, Failure>(operationQueue, wrappedSignals, type: .continuous).suppressError()
    }

    init(_ operationQueue: AsyncOperationQueue, _ signals: @escaping () async throws -> (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>)) {
        self.operationQueue = operationQueue

        var unwrappedSignals: (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>)?
        self.wrappedSignals = { @MainActor in
            if let unwrappedSignals = unwrappedSignals {
                return unwrappedSignals
            }
            let unwrapped = try await signals()
            unwrappedSignals = unwrapped
            return unwrapped
        }
    }
}

final class CoreManagerCombineProperty<E: Entity, Failure: Error>: Publisher {

    typealias Output = QueryResult<E>

    enum PublisherType {
        case once
        case continuous
    }

    private let currentValue = CurrentValueSubject<QueryResult<E>?, Failure>(nil)

    private let isFirstSubscriber = PropertyBox<Bool>(false, atomic: true)

    // Swift Concurrency

    private let operationQueue: AsyncOperationQueue

    private let signals: () async throws -> (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>)

    private let type: PublisherType

    private let asyncTasks = AsyncTasks()

    init(_ operationQueue: AsyncOperationQueue, _ signals: @escaping () async throws -> (once: QueryResult<E>, continuous: AsyncStream<QueryResult<E>>), type: PublisherType) {
        self.operationQueue = operationQueue
        self.signals = signals
        self.type = type
    }

    // MARK: Publisher

    public func receive<S: Subscriber>(subscriber: S) where S.Input == QueryResult<E>, S.Failure == Failure {

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
                guard self != nil else { return }
                _ = subscriber.receive(value)
            })

        if isFirstSubscriber.value == false {
            isFirstSubscriber.value = true

            operationQueue.run(title: "\(CoreManagerCombineProperty.self):perform_task") { completion in
                guard Task.isCancelled == false else {
                    completion()
                    return
                }

                guard subscription.didCancel != nil else {
                    completion()
                    return
                }

                switch self.type {
                case .once:
                    Task {
                        do {
                            let result = try await self.signals().once
                            completion()
                            self.currentValue.send(result)
                            self.currentValue.send(completion: .finished)
                        } catch let error as Failure {
                            completion()
                            self.currentValue.send(completion: .failure(error))
                        }
                    }.store(in: self.asyncTasks)

                case .continuous:
                    Task(priority: .high) {
                        for await value in try await self.signals().continuous where Task.isCancelled == false {
                            self.currentValue.send(value)
                        }
                    }.store(in: self.asyncTasks)
                    Task(priority: .low) {
                        completion()
                    }.store(in: self.asyncTasks)
                }
            }
        }
    }
}

// MARK: - Subscription

private extension CoreManagerCombineProperty {

    final class CoreManagerSubscription<S: Subscriber>: Subscription where S.Input == QueryResult<E>, S.Failure == Failure {

        private var subscriber: S?

        fileprivate var cancellable: AnyCancellable?

        private(set) var didCancel: (() -> Void)?

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
