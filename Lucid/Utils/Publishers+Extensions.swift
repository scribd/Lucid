//
//  Publishers+Extensions.swift
//  Lucid
//
//  Created by Stephane Magne on 3/09/22.
//  Copyright © 2022 Scribd. All rights reserved.
//

#if !LUCID_REACTIVE_KIT
import Combine
import Foundation

// MARK: - AMB

public extension Publishers {

    struct AMB<Output, Failure: Error>: Publisher {

        private var future: Future<Output, Failure>?

        private let publishers: [AnyPublisher<Output, Failure>]

        private let allowAllToFinish: Bool

        private let queue: DispatchQueue

        init<P>(_ publishers: [P], allowAllToFinish: Bool = true, queue: DispatchQueue = DispatchQueue(label: "amb_queue")) where P: Publisher, P.Output == Output, P.Failure == Failure {
            self.publishers = publishers.map { ($0 as? AnyPublisher<Output, Failure>) ?? $0.eraseToAnyPublisher() }
            self.allowAllToFinish = allowAllToFinish
            self.queue = queue
        }

        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {

            let subscription = AMBSubscription(self, subscriber, count: publishers.count)

            let cancellable = Future<Output, Failure> { promise in

                var hasBeenChosen: Bool = false

                let attemptChoice: (Result<Output, Failure>, @escaping () -> Void) -> Void = { result, completion in
                    self.queue.async(flags: .barrier) {
                        defer { completion() }
                        if hasBeenChosen {
                            return
                        }
                        hasBeenChosen = true
                        promise(result)
                    }
                }

                self.queue.sync {

                    self.publishers.enumerated().forEach { index, publisher in

                        let completion = {
                            if self.allowAllToFinish {
                                subscription.cancellableSets[index].forEach { $0.cancel() }
                            } else {
                                subscription.cancellableSets.forEach { $0.forEach { $0.cancel() } }
                            }
                        }

                        publisher
                            .sink(receiveCompletion: { terminal in
                                switch terminal {
                                case .failure(let error):
                                    attemptChoice(.failure(error), completion)
                                case .finished:
                                    subscription.cancellableSets[index].forEach { $0.cancel() }
                                }
                            }, receiveValue: { value in
                                attemptChoice(.success(value), completion)
                            })
                            .store(in: &subscription.cancellableSets[index])
                    }
                }
            }
            .sink(receiveCompletion: { terminal in
                subscriber.receive(completion: terminal)
            }, receiveValue: { value in
                _ = subscriber.receive(value)
            })

            subscription.cancellable = cancellable
            subscriber.receive(subscription: subscription)
        }
    }
}
// MARK: - Subscription

private extension Publishers.AMB {

    final class AMBSubscription<S: Subscriber>: Subscription where S.Input == Output, S.Failure == Failure {

        private var reference: Any?

        private var subscriber: S?

        fileprivate var cancellableSets: [Set<AnyCancellable>]

        fileprivate var cancellable: Cancellable?

        init(_ reference: Any,  _ subscriber: S, count: Int) {
            self.reference = reference
            self.subscriber = subscriber
            self.cancellableSets = [Set<AnyCancellable>](repeating: [], count: count)
        }

        func cancel() {
            reference = nil
            cancellable = nil
            subscriber = nil
            cancellableSets = []
        }

        func request(_ demand: Subscribers.Demand) { }
    }
}

#endif
