//
//  ReactiveKit.swift
//  Lucid
//
//  Created by Théophane Rupin on 12/20/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import ReactiveKit

/// A wrapper which acts like a future.
///
/// - Note: This is a purely for declaration practicality and shouldn't include any custom logic.
struct FutureSubject<Element, Error> where Error: Swift.Error {

    private let subject: ReplayOneSubject<Element, Error>
    
    init(_ attemptToFulfill: @escaping (@escaping (Result<Element, Error>) -> Void) -> Void) {
        let subject = ReplayOneSubject<Element, Error>()
        self.subject = subject

        attemptToFulfill { result in
            switch result {
            case .failure(let error):
                subject.send(completion: .failure(error))
            case .success(let element):
                subject.send(element)
                subject.send(completion: .finished)
            }
        }
    }
    
    func toSignal() -> Signal<Element, Error> {
        return subject.toSignal()
    }
}

/// A custom Subject which notifies when its first observer is added and its last observer is removed.
final class CoreManagerSubject<Element, Error>: ReactiveKit.Subject<Element, Error> where Error: Swift.Error {

    var willAddFirstObserver: (() -> Void)?
    var willRemoveLastObserver: (() -> Void)?
    
    private let superLock = NSRecursiveLock(name: "\(CoreManagerSubject.self):super_lock")
    private let observerCountDispatchQueue = DispatchQueue(label: "\(CoreManagerSubject.self):observer_count")
    private var _observerCount = 0

    override func observe(with observer: @escaping (ReactiveKit.Signal<Element, Error>.Event) -> Void) -> Disposable {
        
        // `willAddFirstObserver` is expected to be called synchronously by `preparePropertiesForSearchUpdate`.
        observerCountDispatchQueue.sync {
            self._observerCount += 1
            if self._observerCount == 1 {
                self.willAddFirstObserver?()
            }
        }
        
        let disposeBag = DisposeBag()
        disposeBag.add(disposable: superObserve(with: observer))
        
        disposeBag.add(disposable: BlockDisposable {
            self.observerCountDispatchQueue.async(flags: .barrier) {
                self._observerCount -= 1
                if self._observerCount == 0 {
                    self.willRemoveLastObserver?()
                }
            }
        })
        
        return disposeBag
    }
        
    override func on(_ event: ReactiveKit.Signal<Element, Error>.Event) {
        superOn(event)
    }
    
    private func superObserve(with observer: @escaping (ReactiveKit.Signal<Element, Error>.Event) -> Void) -> Disposable {
        superLock.lock()
        defer { superLock.unlock() }
        return super.observe(with: observer)
    }
    
    private func superOn(_ event: ReactiveKit.Signal<Element, Error>.Event) {
        superLock.lock()
        defer { superLock.unlock() }
        super.on(event)
    }
}
