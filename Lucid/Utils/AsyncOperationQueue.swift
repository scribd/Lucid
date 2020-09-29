//
//  AsyncOperationQueue.swift
//  Lucid
//
//  Created by Théophane Rupin on 8/29/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

/// Minimalistic queue which ensures serial/parallel execution of asynchronous operations.
public final class AsyncOperationQueue: CustomDebugStringConvertible {

    private let dispatchQueue: DispatchQueue

    private var _operations = [AsyncOperation]()

    public init(dispatchQueue: DispatchQueue = DispatchQueue(label: "\(AsyncOperationQueue.self):operations")) {
        self.dispatchQueue = dispatchQueue
    }

    // MARK: API

    public var isRunning: Bool {
        return dispatchQueue.sync { _isRunning }
    }

    public var first: AsyncOperation? {
        return dispatchQueue.sync { _operations.first }
    }

    public var last: AsyncOperation? {
        return dispatchQueue.sync { _operations.last }
    }

    public func run(operation: AsyncOperation) {
        dispatchQueue.async(flags: .barrier) {

            let isRunning = self._isRunning
            let containsBarrier = self._nextBarrier != nil

            self._operations.append(operation)

            if (operation.barrier && isRunning) || containsBarrier {
                return
            }

            self._runOperation(operation)
        }
    }

    public func run(on queue: DispatchQueue? = nil,
                    title: String,
                    barrier: Bool = true,
                    _ operation: @escaping AsyncOperation.Run) {

        let operation = AsyncOperation(on: queue,
                                       title: title,
                                       barrier: barrier,
                                       operation)
        run(operation: operation)
    }

    public var debugDescription: String {
        return dispatchQueue.sync {
            """
            Operations:
            \(_operations.map { $0.debugDescription }.joined(separator: "\n"))
            """
        }
    }
}

// MARK: - DispatchQueue bound functions

private extension AsyncOperationQueue {

    var _isRunning: Bool {
        return _operations.isEmpty == false
    }

    var _nextBarrier: AsyncOperation? {
        return _operations.first { $0.barrier }
    }

    func _runOperation(_ operation: AsyncOperation) {
        operation.run {
            self.dispatchQueue.async(flags: .barrier) {
                guard self._operations.isEmpty == false else { return }
                self._operations.removeFirst()
                // always run the next operation if it's a barrier
                if let nextOperation = self._operations.first, nextOperation.barrier {
                    self._runOperation(nextOperation)
                }
                // otherwise, when a barrier operation completes, run all of the concurrent operations until the next barrier/end-of-queue
                else if operation.barrier {
                    let nextBarrier = self._nextBarrier
                    for nextOperation in self._operations.prefix(while: { $0 != nextBarrier }) {
                        self._runOperation(nextOperation)
                    }
                }
            }
        }
    }
}

// MARK: - AsyncOperation

public struct AsyncOperation: CustomDebugStringConvertible {

    public typealias Run = (_ completion: @escaping () -> Void) -> Void
    private let _run: Run

    public let title: String

    public let debugDescription: String

    public let barrier: Bool

    public let timeout: TimeInterval?

    internal let uuid = UUID()

    public init(on dispatchQueue: DispatchQueue? = nil,
                title: String,
                barrier: Bool = true,
                timeout: TimeInterval? = nil,
                _ run: @escaping Run) {

        if let dispatchQueue = dispatchQueue {
            _run = { completion in
                dispatchQueue.async(flags: .barrier) {
                    run(completion)
                }
            }
        } else {
            _run = run
        }

        debugDescription = "\(AsyncOperation.self): '\(title)'"
        self.title = title
        self.barrier = barrier
        self.timeout = timeout
    }

    fileprivate func run(_ completion: @escaping () -> Void) {
        let cancellationToken: CancellationToken?
        if let timeout = timeout {
            cancellationToken = .cancelling(after: timeout, onCancel: completion)
        } else {
            cancellationToken = nil
        }

        _run {
            if let cancellationToken = cancellationToken, cancellationToken.cancel() { return }
            completion()
        }
    }
}

// MARK: Equatable

extension AsyncOperation: Equatable {

    public static func == (lhs: AsyncOperation, rhs: AsyncOperation) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
