//
//  Async.swift
//  Lucid
//
//  Created by Ezequiel Munz on 14/04/2023.
//  Copyright © 2023 Scribd. All rights reserved.
//

import Foundation
import Combine

// MARK: - Async Tasks Storage

public final actor AsyncTasks {

    private var tasks: [Task<Void, any Error>] = []

    deinit {
        for task in tasks {
            task.cancel()
        }
    }

    public init() { }

    public func cancel() {
        for task in tasks {
            task.cancel()
        }
    }
}

fileprivate extension AsyncTasks {

    func append(_ task: Task<Void, any Error>) {
        tasks.append(task)
    }
}

public extension Task where Success == Void, Failure == any Error {

    @discardableResult
    func storeAsync(in asyncTasks: AsyncTasks) async -> Self {
        await asyncTasks.append(self)
        return self
    }

    @discardableResult
    func store(in asyncTasks: AsyncTasks) -> Self {
        Task {
            await asyncTasks.append(self)
        }
        return self
    }
}

// MARK: - Type Erasure

struct AnyAsyncSequence<Element>: AsyncSequence {
    typealias AsyncIterator = AnyAsyncIterator<Element>
    typealias Element = Element

    let _makeAsyncIterator: () -> AnyAsyncIterator<Element>

    init<S: AsyncSequence>(seq: S) where S.Element == Element {
        _makeAsyncIterator = {
            AnyAsyncIterator(iterator: seq.makeAsyncIterator())
        }
    }

    func makeAsyncIterator() -> AnyAsyncIterator<Element> {
        return _makeAsyncIterator()
    }
}

extension AnyAsyncSequence {

    struct AnyAsyncIterator<Element>: AsyncIteratorProtocol {
        typealias Element = Element

        private let _next: () async throws -> Element?

        init<I: AsyncIteratorProtocol>(iterator: I) where I.Element == Element {
            var iterator = iterator
            self._next = {
                try await iterator.next()
            }
        }

        mutating func next() async throws -> Element? {
            return try await _next()
        }
    }
}

extension AsyncSequence {

    func eraseToAnyAsyncSequence() -> AnyAsyncSequence<Element> {
        AnyAsyncSequence(seq: self)
    }

}

// MARK: - AsyncTasksQueue

public actor AsyncTaskQueue {

    private let maxConcurrentTasks: Int
    private(set) var runningTasks: Int = 0
    private var queue = [CheckedContinuation<Void, Error>]()

    public init(maxConcurrentTasks: Int = 1) {
        self.maxConcurrentTasks = maxConcurrentTasks
    }

    deinit {
        for continuation in queue {
            continuation.resume(throwing: CancellationError())
        }
    }

    public func enqueue<T>(operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try Task.checkCancellation()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.append(continuation)
            tryRunEnqueued()
        }

        defer {
            runningTasks -= 1
            tryRunEnqueued()
        }
        try Task.checkCancellation()
        return try await operation()
    }

    private func tryRunEnqueued() {
        guard queue.isEmpty == false else { return }
        guard runningTasks < maxConcurrentTasks else { return }

        runningTasks += 1
        let continuation = queue.removeFirst()
        continuation.resume()
    }
}

// MARK: - Sequence

public extension Sequence {

    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }

    func concurrentMap<T>(_ transform: @escaping (Element) async throws -> T) async throws -> [T] {
        let tasks = map { element in
            Task {
                try await transform(element)
            }
        }

        return try await tasks.asyncMap { task in
            try await task.value
        }
    }
}

public extension Sequence {

    func asyncForEach(_ operation: (Element) async throws -> Void) async rethrows {
        for element in self {
            try await operation(element)
        }
    }

    func concurrentForEach(_ operation: @escaping (Element) async -> Void) async {
        // A task group automatically waits for all of its
        // sub-tasks to complete, while also performing those
        // tasks in parallel:
        await withTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask {
                    await operation(element)
                }
            }
        }
    }
}

public extension AsyncSequence {

    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()

        for try await element in self {
            try await values.append(transform(element))
        }

        return values
    }

    func concurrentMap<T>(_ transform: @escaping (Element) async throws -> T) async throws -> [T] {
        let tasks = map { element in
            Task {
                try await transform(element)
            }
        }

        return try await tasks.asyncMap { task in
            try await task.value
        }
    }
}


// MARK: - Combine Bridge

/// `AsyncSequence` implementation that bridges an Upstream Publisher into an async sequence
/// The outcome is an `AsyncThrowingStream` instance that manages the Publisher values and errors
///
/// This is useful if we want to use Swift Concurrency when the inputs are coming as Combine publishers
public class AsyncStreamPublisherBridge<Upstream: Publisher>: AsyncSequence {
    public typealias Element = Upstream.Output
    public typealias AsyncIterator = AsyncStreamPublisherBridge<Upstream>

    private let stream: AsyncThrowingStream<Upstream.Output, Error>
    private lazy var iterator = stream.makeAsyncIterator()

    fileprivate let originalUpstream: Upstream
    private var cancellable: AnyCancellable?

    public init(_ upstream: Upstream) {
        self.originalUpstream = upstream

        var subscription: AnyCancellable?

        stream = AsyncThrowingStream<Upstream.Output, Error>(Upstream.Output.self) { continuation in
            subscription = upstream.handleEvents(receiveCancel: {
                continuation.finish(throwing: nil)
            })
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    continuation.finish(throwing: error)
                case .finished:
                    continuation.finish(throwing: nil)
                }
            }, receiveValue: { value in
                continuation.yield(value)
            })
        }

        cancellable = subscription
    }

    deinit {
        cancel()
    }

    public func makeAsyncIterator() -> Self {
        return self
    }

    public func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}

/// `AsyncSequence` implementation that bridges an Upstream Publisher with Failure type = `Never` into an async sequence
/// The outcome sequence is an `AsyncStream` type that won't throw any error in the way
///
/// This is useful if we want to use Swift Concurrency when the inputs are coming as Combine publishers
public class AsyncSafeStreamPublisherBridge<Upstream: Publisher>: AsyncSequence where Upstream.Failure == Never {

    public typealias Element = Upstream.Output
    public typealias AsyncIterator = AsyncSafeStreamPublisherBridge<Upstream>

    public let stream: AsyncStream<Upstream.Output>
    private lazy var iterator = stream.makeAsyncIterator()

    private var cancellable: AnyCancellable?

    public init(_ upstream: Upstream) {
        var subscription: AnyCancellable?

        stream = AsyncStream<Upstream.Output>(Upstream.Output.self) { continuation in
            subscription = upstream.handleEvents(receiveCancel: {
                continuation.finish()
            })
            .sink(receiveValue: { value in
                continuation.yield(value)
            })
        }

        cancellable = subscription
    }

    deinit {
        cancel()
    }

    public func makeAsyncIterator() -> Self {
        return self
    }

    public func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}

// - MARK: - Conformance to `AsyncIteratorProtocol`

extension AsyncStreamPublisherBridge: AsyncIteratorProtocol {
    public func next() async throws -> Upstream.Output? {
        return try await iterator.next()
    }
}

extension AsyncSafeStreamPublisherBridge: AsyncIteratorProtocol {
    public func next() async -> Upstream.Output? {
        return await iterator.next()
    }
}

// MARK: - Publisher Extensions

public extension Publisher {
    func asyncStream() -> AsyncStreamPublisherBridge<Self> {
        return AsyncStreamPublisherBridge(self)
    }
}

public extension Publisher where Failure == Never {
    func asyncStream() -> AsyncSafeStreamPublisherBridge<Self> {
        return AsyncSafeStreamPublisherBridge(self)
    }
}
