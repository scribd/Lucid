//
//  Result.swift
//  Lucid
//
//  Created by Théophane Rupin on 5/17/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

public extension Result {

    var error: Failure? {
        switch self {
        case .failure(let error):
            return error
        case .success:
            return nil
        }
    }

    var value: Value? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }

    init(value: Value) {
        self = .success(value)
    }

    init(error: Error) {
        self = .failure(error)
    }

    func analysis<U>(_ ifSuccess: (Value) -> U, ifFailure: (Error) -> U) -> U {
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
