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
