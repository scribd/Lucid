//
//  CancellationToken.swift
//  Lucid
//
//  Created by Théophane Rupin on 10/18/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

public final class CancellationToken {

    private var _isCancelled = false
    private let cancelQueue = DispatchQueue(label: "\(CancellationToken.self)_cancel_queue")

    public init() { }

    public var isCancelled: Bool {
        return cancelQueue.sync { _isCancelled }
    }

    @discardableResult
    public func cancel() -> Bool {
        return cancelQueue.sync {
            let result = self._isCancelled
            self._isCancelled = true
            return result
        }
    }

    public static func cancelling(after delay: TimeInterval, onCancel completion: @escaping () -> Void) -> CancellationToken {
        let token = CancellationToken()
        let timer = Timer(timeInterval: delay, repeats: false) { timer in
            guard token.cancel() == false else { return }
            completion()
            timer.invalidate()
        }
        RunLoop.main.add(timer, forMode: .default)
        return token
    }
}
