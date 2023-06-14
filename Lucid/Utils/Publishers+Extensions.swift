//
//  Publishers+Extensions.swift
//  Lucid
//
//  Created by Stephane Magne on 3/09/22.
//  Copyright © 2022 Scribd. All rights reserved.
//

import Combine
import Foundation

// MARK: - AMB

public extension Publishers {

    final class AMB<Output, Failure: Error>: Publisher {

        private let publishers: [AnyPublisher<Output, Failure>]

        private let allowAllToFinish: Bool

        public init<P>(_ publishers: [P], allowAllToFinish: Bool = true) where P: Publisher, P.Output == Output, P.Failure == Failure {
            self.publishers = publishers.map { ($0 as? AnyPublisher<Output, Failure>) ?? $0.eraseToAnyPublisher() }
            self.allowAllToFinish = allowAllToFinish
        }

        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {

            let subscription = AMBSubscription(self, subscriber, count: publishers.count)

            subscriber.receive(subscription: subscription)

            subscription.cancellable = ReplayOnce<Output, Failure> { promise in

                var hasBeenChosen: Bool = false

                let attemptChoice: (Result<Output, Failure>, @escaping () -> Void) -> Void = { result, completion in
                    defer { completion() }
                    if hasBeenChosen {
                        return
                    }
                    hasBeenChosen = true
                    promise(result)
                }

                self.publishers.enumerated().forEach { index, publisher in

                    let completion = {
                        if self.allowAllToFinish {
                            subscription.cancellableBoxes[index].cancel()
                        } else {
                            subscription.cancellableBoxes.forEach { $0.cancel() }
                        }
                    }

                    publisher
                        .sink(receiveCompletion: { [weak self] terminal in
                            guard self != nil else { return }
                            switch terminal {
                            case .failure(let error):
                                attemptChoice(.failure(error), completion)
                            case .finished:
                                subscription.cancellableBoxes[index].cancel()
                            }
                        }, receiveValue: { [weak self] value in
                            guard self != nil else { return }
                            attemptChoice(.success(value), completion)
                        })
                        .store(in: subscription.cancellableBoxes[index])
                }
            }
            .sink(receiveCompletion: { terminal in
                subscriber.receive(completion: terminal)
            }, receiveValue: { value in
                _ = subscriber.receive(value)
            })
        }
    }
}

// MARK: Subscription

private extension Publishers.AMB {

    final class AMBSubscription<S: Subscriber>: Subscription where S.Input == Output, S.Failure == Failure {

        private var reference: Any?

        private var subscriber: S?

        private var _cancellableBoxes: [CancellableBox]

        fileprivate var cancellable: Cancellable?

        private let dataLock = NSRecursiveLock(name: "\(AMBSubscription.self):data_lock")

        init(_ reference: Any,  _ subscriber: S, count: Int) {
            self.reference = reference
            self.subscriber = subscriber
            self._cancellableBoxes = (0..<count).map { _ in CancellableBox() }
        }

        var cancellableBoxes: [CancellableBox] {
            dataLock.lock()
            defer { dataLock.unlock() }
            return _cancellableBoxes
        }

        func cancel() {
            dataLock.lock()
            defer { dataLock.unlock() }
            reference = nil
            cancellable = nil
            subscriber = nil
            _cancellableBoxes = []
        }

        func request(_ demand: Subscribers.Demand) { }
    }
}

// MARK: - ReplayOnce

public extension Publishers {

    typealias ReplayPromise<Output, Failure: Error> = (Result<Output, Failure>) -> Void

    final class ReplayOnce<Output, Failure: Error>: Publisher {

        private let currentValue = CurrentValueSubject<Output?, Failure>(nil)

        private let outputValue: AnyPublisher<Output, Failure>

        private let dataLock = NSRecursiveLock(name: "\(ReplayOnce.self):data_lock")

        public init(_ handler: @escaping ((@escaping ReplayPromise<Output, Failure>) -> Void)) {

            let current = currentValue
            let lock = dataLock

            let promise: ReplayPromise<Output, Failure> = { result in
                lock.lock()
                defer { lock.unlock() }

                switch result {
                case .success(let value):
                    current.send(value)
                    current.send(completion: .finished)
                case .failure(let error):
                    current.send(completion: .failure(error))
                }
            }

            defer {
                handler(promise)
            }

            self.outputValue = currentValue
                .compactMap { $0 }
                .eraseToAnyPublisher()
        }

        // MARK: Publisher

        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            dataLock.lock()
            defer { dataLock.unlock() }

            if let value = currentValue.value {
                let just = Just(value).setFailureType(to: Failure.self)
                just.receive(subscriber: subscriber)
            } else {
                outputValue.receive(subscriber: subscriber)
            }
        }
    }
}

// MARK: - QueuedReplayOnce

public extension Publishers {

    final class QueuedReplayOnce<Output, Failure: Error>: Publisher {

        private var replayOnce: ReplayOnce<Output, Failure>?

        private let operationQueue: AsyncOperationQueue

        public init(_ operationQueue: AsyncOperationQueue,
                    _ handler: @escaping ((@escaping ReplayPromise<Output, Failure>, @escaping () -> Void) -> Void)) {

            self.operationQueue = operationQueue

            operationQueue.run(title: "\(QueuedReplayOnce.self):create_replay_once") { completion in
                self.replayOnce = ReplayOnce<Output, Failure> { promise in
                    let dispatchQueue = DispatchQueue(label: "\(QueuedReplayOnce.self):dispatch_queue")
                    let wrappedCompletion = {
                        dispatchQueue.async {
                            completion()
                        }
                    }
                    handler(promise, wrappedCompletion)
                }
            }
        }

        // MARK: Publisher

        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            let preQueueSubscription = QueuedReplayOnceSubscription(self, subscriber)
            subscriber.receive(subscription: preQueueSubscription)
            operationQueue.run(title: "\(QueuedReplayOnce.self):receive_subscriber") { completion in
                defer {
                    completion()
                }
                guard preQueueSubscription.isCancelled == false else { return }
                guard let publisher = self.replayOnce else {
                    Logger.log(.error, "\(QueuedReplayOnce.self) attempting to set a subscriber before the publisher is built", assert: true)
                    return
                }

                let cancellable = publisher
                    .sink(receiveCompletion: { terminal in
                        guard preQueueSubscription.isCancelled == false else { return }
                        subscriber.receive(completion: terminal)
                    }, receiveValue: { value in
                        guard preQueueSubscription.isCancelled == false else { return }
                        _ = subscriber.receive(value)
                    })

                preQueueSubscription.cancellable = cancellable
            }
        }
    }
}

// MARK: - Subscription

private extension Publishers.QueuedReplayOnce {

    final class QueuedReplayOnceSubscription<S: Subscriber>: Subscription where S.Input == Output, S.Failure == Failure {

        private var reference: Any?

        private var subscriber: S?

        fileprivate var cancellable: Cancellable?

        private(set) var isCancelled: Bool = false

        init(_ reference: Any?, _ subscriber: S) {
            self.reference = reference
            self.subscriber = subscriber
        }

        func cancel() {
            reference = nil
            subscriber = nil
            cancellable = nil
            isCancelled = true
        }

        func request(_ demand: Subscribers.Demand) { }
    }
}


