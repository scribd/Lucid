//
//  APIClientQueueSchedulerSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 4/24/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Lucid

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

    public func didEnqueueNewRequest() async {
        didEnqueueNewRequestCallCount += 1
    }

    public func flush() async {
        flushCallCount += 1
    }

    public func requestDidSucceed() async {
        requestDidSucceedCallCount += 1
    }

    public func requestDidFail() async {
        requestDidFailCallCount += 1
    }
}

public final actor APIClientQueueSchedulerDelegateSpy: APIClientQueueSchedulerDelegate {

    public init() {
        // no-op
    }

    public private(set) var processNextStubs: [APIClientQueueSchedulerProcessNextResult] = []

    public func setProcessNextStubs(_ stubs: [APIClientQueueSchedulerProcessNextResult]) async {
        self.processNextStubs = stubs
    }

    public private(set) var processNextInvocations: [Void] = [Void]()

    @discardableResult
    public func processNext() async -> APIClientQueueSchedulerProcessNextResult {
        processNextInvocations.append(())
        defer { processNextStubs = processNextStubs.dropFirst().array }
        return processNextStubs.first ?? .didNotProcess
    }
}
