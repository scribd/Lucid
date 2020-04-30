//
//  AsyncOperationQueue.swift
//  Lucid
//
//  Created by Théophane Rupin on 8/29/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

/// Minimalistic asynchronous operation queue which ensures serial execution on a singe background queue.
public final class AsyncOperationQueue: CustomDebugStringConvertible {
    
    public init() {
        // no-op
    }
    
    private let dispatchQueue = DispatchQueue(label: "\(AsyncOperationQueue.self):operations")
    
    private var _operations = [AsyncOperation]()
    
    private var _isRunning = false
    public var isRunning: Bool {
        return dispatchQueue.sync { _isRunning }
    }
    
    public func run(operation: AsyncOperation) {
        dispatchQueue.async {
            self._operations.append(operation)
            if self._operations.count == 1 && self._isRunning == false {
                self._runNextOperation()
            }
        }
    }
    
    public func run(on dispatchQueue: DispatchQueue? = nil,
                    title: String,
                    barrier: Bool = true,
                    _ operation: @escaping AsyncOperation.Run) {
        
        let operation = AsyncOperation(on: dispatchQueue,
                                       title: title,
                                       barrier: barrier,
                                       operation)
        run(operation: operation)
    }

    private func _runNextOperation() {
        guard let operation = _operations.first else {
            _isRunning = false
            return
        }
        
        let _nextBarrier = _operations.enumerated().first { index, operation in
            operation.barrier || index == _operations.count - 1
        }
        
        if operation.barrier {
            _isRunning = true
            operation.run {
                self.dispatchQueue.async {
                    self._operations.removeFirst()
                    self._runNextOperation()
                }
            }
        } else if let nextBarrier = _nextBarrier {
            let operations = _operations[0...nextBarrier.offset]

            let dispatchGroup = DispatchGroup()
            for _ in operations {
                dispatchGroup.enter()
            }
            
            _isRunning = true
            for operation in operations {
                operation.run {
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: dispatchQueue) {
                self._operations.removeSubrange(0...nextBarrier.offset)
                self._runNextOperation()
            }
        } else {
            Logger.log(.error, "\(AsyncOperationQueue.self): The queue is broken. Please fix asap.", assert: true)
            _isRunning = false
        }
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

public struct AsyncOperation: CustomDebugStringConvertible {
    
    public typealias Run = (_ completion: @escaping () -> Void) -> Void
    private let _run: Run
    
    public let title: String
    
    public let debugDescription: String
    
    public let barrier: Bool
    
    public let timeout: TimeInterval?
    
    public init(on dispatchQueue: DispatchQueue? = nil,
                title: String,
                barrier: Bool = true,
                timeout: TimeInterval? = nil,
                _ run: @escaping Run) {

        if let dispatchQueue = dispatchQueue {
            _run = { completion in
                dispatchQueue.async {
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
