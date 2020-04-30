//
//  APIClientQueueSchedulerSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 4/24/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

@testable import Lucid

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
