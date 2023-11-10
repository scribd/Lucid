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
    typealias AsyncIterator = AnyAsyncIterator
    typealias Element = Element

    let _makeAsyncIterator: () -> AnyAsyncIterator

    init<S: AsyncSequence>(seq: S) where S.Element == Element {
        _makeAsyncIterator = {
            AnyAsyncIterator(iterator: seq.makeAsyncIterator())
        }
    }

    func makeAsyncIterator() -> AnyAsyncIterator {
        return _makeAsyncIterator()
    }
}

extension AnyAsyncSequence {

    struct AnyAsyncIterator: AsyncIteratorProtocol {

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

    public typealias OperationCompletion = () -> Void

    class AsyncOperation {
        private let barrier: Bool
        private var continuation: CheckedContinuation<Void, Error>?

        init(barrier: Bool) {
            self.barrier = barrier
        }

        func setContinuation(continuation: CheckedContinuation<Void, Error>) {
            self.continuation = continuation
        }

        func getContinuation() -> CheckedContinuation<Void, Error>? {
            return continuation
        }

        func isBarrier() -> Bool {
            return barrier
        }

        func isSetup() -> Bool {
            return continuation != nil
        }
    }

    private let maxConcurrentTasks: Int
    private(set) var runningTasks: Int = 0
    private var queue = [AsyncOperation]()

    public var isLastBarrier: Bool {
        return queue.last?.isBarrier() ?? false
    }

    private var current: AsyncOperation?

    private var isCurrentBarrier: Bool {
        return current?.isBarrier() ?? false
    }

    private var isNextBarrier: Bool {
        return queue.first?.isBarrier() ?? false
    }

    public init(maxConcurrentTasks: Int = 5) {
        self.maxConcurrentTasks = maxConcurrentTasks
    }

    deinit {
        for continuation in queue.map({ $0.getContinuation() }) {
            continuation?.resume(throwing: CancellationError())
        }
    }

    public func enqueue<T>(operation: @escaping @Sendable () async throws -> T) async throws -> T {
        do {
            try Task.checkCancellation()

            let asyncOperation = AsyncOperation(barrier: false)
            self.queue.append(asyncOperation)

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                asyncOperation.setContinuation(continuation: continuation)
                await self.tryRunEnqueued()
            }

            try Task.checkCancellation()
            let result = try await operation()
            await self.endOperation()

            return result
        } catch {
            await self.endOperation()
            throw error
        }
    }

    public func enqueueBarrier<T>(operation: @escaping @Sendable (OperationCompletion) async throws -> T) async throws -> T {
        try Task.checkCancellation()

        let completion: OperationCompletion = {
            Task {
                await self.endOperation()
            }
        }

        let asyncOperation = AsyncOperation(barrier: true)
        self.queue.append(asyncOperation)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            asyncOperation.setContinuation(continuation: continuation)
            await self.tryRunEnqueued()
        }

        try Task.checkCancellation()
        return try await operation(completion)
    }

    private func endOperation() async {
        runningTasks -= 1
        current = nil
        await self.tryRunEnqueued()
    }

    private func tryRunEnqueued() async {
        guard queue.isEmpty == false else { return }
        guard runningTasks < maxConcurrentTasks else { return }

        if runningTasks > 0 {
            if isCurrentBarrier || isNextBarrier { return }
        }

        guard queue[0].isSetup() else { return }

        runningTasks += 1

        let operation = queue.removeFirst()
        current = operation

        guard let continuation = operation.getContinuation() else { return }
        continuation.resume()

        // Try to run as many operations in parallel as possible
        if isCurrentBarrier == false && isNextBarrier == false {
            await tryRunEnqueued()
        }
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

    func asyncCompactMap<T>(_ transform: (Element) async throws -> T?) async throws -> [T] {
        var values = [T]()

        for element in self {
            guard let value = try await transform(element) else { continue }
            values.append(value)
        }

        return values
    }

    func concurrentCompactMap<T>(_ transform: @escaping (Element) async throws -> T?) async throws -> [T] {
        let tasks = map { element in
            Task {
                try await transform(element)
            }
        }

        return try await tasks.asyncCompactMap { task in
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

// MARK: - Global Functions

public func withCheckedThrowingContinuation<T>(_ body: @escaping (CheckedContinuation<T, Error>) async throws -> Void) async throws -> T {
    return try await withCheckedThrowingContinuation { continuation in
        Task {
            try await body(continuation)
        }
    }
}

public func withCheckedContinuation<T>(_ body: @escaping (CheckedContinuation<T, Never>) async -> Void) async -> T {
    return await withCheckedContinuation { continuation in
        Task {
            await body(continuation)
        }
    }
}
