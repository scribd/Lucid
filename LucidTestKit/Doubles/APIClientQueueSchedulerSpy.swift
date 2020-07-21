//
//  APIClientQueueSchedulerSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 4/24/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

#if LUCID_REACTIVE_KIT
import Lucid_ReactiveKit
#else
import Lucid
#endif

public final class APIClientQueueSchedulerSpy: APIClientQueueScheduling {

    // MARK: - Records

    public private(set) var didInitializeCallCount = 0

    public private(set) var didEnqueueNewRequestCallCount = 0

    public private(set) var flushCallCount = 0

    public private(set) var requestDidSucceedCallCount = 0

    public private(set) var requestDidFailCallCount = 0

    // MARK: - API

    public init() {
        // no-op
    }

    public weak var delegate: APIClientQueueSchedulerDelegate?

    public func didEnqueueNewRequest() {
        didEnqueueNewRequestCallCount += 1
    }

    public func flush() {
        flushCallCount += 1
    }

    public func requestDidSucceed() {
        requestDidSucceedCallCount += 1
    }

    public func requestDidFail() {
        requestDidFailCallCount += 1
    }
}

public final class APIClientQueueSchedulerDelegateSpy: APIClientQueueSchedulerDelegate {

    public init() {
        // no-op
    }

    public var processNextStubs: [APIClientQueueSchedulerProcessNextResult] = []

    public private(set) var processNextInvocations = [Void]()

    @discardableResult
    public func processNext() -> APIClientQueueSchedulerProcessNextResult {
        processNextInvocations.append(())
        defer { processNextStubs = processNextStubs.dropFirst().array }
        return processNextStubs.first ?? .didNotProcess
    }
}
