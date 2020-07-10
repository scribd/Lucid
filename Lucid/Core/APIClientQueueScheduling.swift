//
//  APIClientQueueScheduling.swift
//  Lucid
//
//  Created by Ibrahim Sha'ath on 3/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

public protocol APIClientQueueScheduling: AnyObject {

    func didEnqueueNewRequest()

    func flush()

    func requestDidSucceed()

    func requestDidFail()

    var delegate: APIClientQueueSchedulerDelegate? { get set }
}

public protocol APIClientQueueSchedulerDelegate: AnyObject {

    @discardableResult
    func processNext() -> APIClientQueueSchedulerProcessNextResult
}

public enum APIClientQueueSchedulerProcessNextResult {
    case didNotProcess
    case processedBarrier
    case processedConcurrent
}

public extension APIClientQueueSchedulerProcessNextResult {

    var didProcess: Bool {
        switch self {
        case .didNotProcess:
            return false
        case .processedBarrier,
             .processedConcurrent:
            return true
        }
    }
}
