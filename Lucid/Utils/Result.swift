//
//  Result.swift
//  Lucid
//
//  Created by Théophane Rupin on 5/17/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

public extension Result {

    var error: Failure? {
        switch self {
        case .failure(let error):
            return error
        case .success:
            return nil
        }
    }

    var value: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }

    init(value: Success) {
        self = .success(value)
    }

    init(error: Failure) {
        self = .failure(error)
    }

    func analysis<U>(_ ifSuccess: (Success) -> U, ifFailure: (Failure) -> U) -> U {
        switch self {
        case let .success(value):
            return ifSuccess(value)
        case let .failure(error):
            return ifFailure(error)
        }
    }
}

public extension APIClientQueueResult {

    var error: E? {
        switch self {
        case .failure(let error):
            return error
        case .aborted,
             .success:
            return nil
        }
    }

    var value: APIClientResponse<T>? {
        switch self {
        case .success(let value):
            return value
        case .aborted,
             .failure:
            return nil
        }
    }

    init(value: APIClientResponse<T>) {
        self = .success(value)
    }

    init(error: E) {
        self = .failure(error)
    }
}

public extension NSLock {

    convenience init(name: String) {
        self.init()
        self.name = name
    }
}

public extension NSRecursiveLock {

    convenience init(name: String) {
        self.init()
        self.name = name
    }
}
