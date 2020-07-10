//
//  APIClientQueueSchedulerSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 4/24/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

#if LUCID_REACTIVE_KIT
@testable import Lucid_ReactiveKit
#else
@testable import Lucid
#endif

final class APIClientQueueSchedulerSpy: APIClientQueueScheduling {

    // MARK: - Records

    private(set) var didInitializeCallCount = 0

    private(set) var didEnqueueNewRequestCallCount = 0

    private(set) var flushCallCount = 0

    private(set) var requestDidSucceedCallCount = 0

    private(set) var requestDidFailCallCount = 0

    // MARK: - API

    weak var delegate: APIClientQueueSchedulerDelegate?

    func didEnqueueNewRequest() {
        didEnqueueNewRequestCallCount += 1
    }

    func flush() {
        flushCallCount += 1
    }

    func requestDidSucceed() {
        requestDidSucceedCallCount += 1
    }

    func requestDidFail() {
        requestDidFailCallCount += 1
    }
}

final class APIClientQueueSchedulerDelegateSpy: APIClientQueueSchedulerDelegate {

    var processNextStubs: [APIClientQueueSchedulerProcessNextResult] = []

    private(set) var processNextInvocations = [(
        Void
    )]()

    @discardableResult
    func processNext() -> APIClientQueueSchedulerProcessNextResult {
        processNextInvocations.append(())
        defer { processNextStubs = processNextStubs.dropFirst().array }
        return processNextStubs.first ?? .didNotProcess
    }
}
