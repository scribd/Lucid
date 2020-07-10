//
//  APIClientQueueDefaultSchedulerTests.swift
//  LucidTests
//
//  Created by Ibrahim Sha'ath on 3/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Lucid_ReactiveKit
@testable import LucidTestKit_ReactiveKit

final class APIClientQueueDefaultSchedulerTests: XCTestCase {

    private var dispatchQueue: DispatchQueue!

    private var timeInterval: TimeInterval!

    private var timer: MockTimer!

    private var timerProvider: MockTimerProvider!

    private var delegate: APIClientQueueSchedulerDelegateSpy!

    private var scheduler: APIClientQueueDefaultScheduler!

    override func setUp() {
        super.setUp()
        dispatchQueue = DispatchQueue(label: "\(APIClientQueueDefaultSchedulerTests.self)")
        timeInterval = 12345
        Logger.shared = LoggerMock()
        timer = MockTimer()
        timerProvider = MockTimerProvider(timer: timer)
        delegate = APIClientQueueSchedulerDelegateSpy()
        scheduler = APIClientQueueDefaultScheduler(timeInterval: timeInterval,
                                                   timerProvider: timerProvider,
                                                   stateQueue: dispatchQueue)
        scheduler.delegate = delegate
    }

    override func tearDown() {
        dispatchQueue = nil
        timeInterval = nil
        timer = nil
        timerProvider = nil
        delegate = nil
        scheduler = nil
        super.tearDown()
    }
}

extension APIClientQueueDefaultSchedulerTests {

    func testThatItInvokesTheDelegateWhenDidEnqueueNewRequestIsCalledInACleanState() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // ensure delegate starts out clean
        XCTAssertEqual(delegate.processNextInvocations.count, 0)

        // invoke scheduler
        scheduler.didEnqueueNewRequest()

        // ensure delegate was invoked
        dispatchQueue.sync {
            XCTAssertEqual(delegate.processNextInvocations.count, 1)
        }
    }

    func testThatItInvokesTheDelegateWhenFlushIsCalledInACleanState() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // ensure delegate starts out clean
        XCTAssertEqual(delegate.processNextInvocations.count, 0)

        // invoke scheduler
        scheduler.flush()

        // ensure delegate was invoked
        dispatchQueue.sync {
            XCTAssertEqual(delegate.processNextInvocations.count, 1)
        }
    }

    func testThatItInvokesTheDelegateEveryTimeDidEnqueueNewRequestIsCalledWhileTheDelegateHasNothingToProcess() {

        // state
        delegate.processNextStubs = [.didNotProcess]

        // ensure delegate starts out clean
        XCTAssertEqual(delegate.processNextInvocations.count, 0)

        // invoke scheduler
        scheduler.didEnqueueNewRequest()
        scheduler.didEnqueueNewRequest()
        scheduler.didEnqueueNewRequest()

        // ensure delegate was invoked
        dispatchQueue.sync {
            XCTAssertEqual(delegate.processNextInvocations.count, 3)
        }
    }

    func testThatItInvokesTheDelegateEveryTimeFlushIsCalledWhileTheDelegateHasNothingToProcess() {

        // state
        delegate.processNextStubs = [.didNotProcess]

        // ensure delegate starts out clean
        XCTAssertEqual(delegate.processNextInvocations.count, 0)

        // invoke scheduler
        scheduler.flush()
        scheduler.flush()
        scheduler.flush()

        // ensure delegate was invoked
        dispatchQueue.sync {
            XCTAssertEqual(delegate.processNextInvocations.count, 3)
        }
    }

    func testThatItInvokesTheDelegateEveryTimeDidEnqueueNewRequestIsCalled() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        scheduler.didEnqueueNewRequest()
        scheduler.didEnqueueNewRequest()

        dispatchQueue.sync {
            // ensure delegate was invoked twice
            XCTAssertEqual(delegate.processNextInvocations.count, 2)
        }
    }

    func testThatItInvokesTheDelegateWhenFlushIsCalledEvenIfOperationsAreProcessing() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        scheduler.didEnqueueNewRequest()
        scheduler.flush()

        dispatchQueue.sync {
            // ensure delegate was invoked twice
            XCTAssertEqual(delegate.processNextInvocations.count, 2)
        }
    }

    func testThatItReinvokesTheDelegateWhenARequestSucceeds() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        scheduler.didEnqueueNewRequest()
        scheduler.requestDidSucceed()

        dispatchQueue.sync {
            // ensure delegate was invoked twice
            XCTAssertEqual(delegate.processNextInvocations.count, 2)
        }
    }

    func testThatItInvokesTheDelegateWhenDidEnqueueNewRequestIsCalledIfThePriorRequestWasSuccessfulAndNoFurtherRequestsWereWaiting() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        scheduler.didEnqueueNewRequest()
        scheduler.requestDidSucceed()

        // invoke scheduler
        scheduler.didEnqueueNewRequest()

        dispatchQueue.sync {
            // ensure delegate was invoked three times
            XCTAssertEqual(delegate.processNextInvocations.count, 3)
        }
    }

    func testThatItInvokesTheDelegateWhenFlushIsCalledIfThePriorRequestWasSuccessfulAndNoFurtherRequestsWereWaiting() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        scheduler.flush()
        scheduler.requestDidSucceed()
        scheduler.flush()

        dispatchQueue.sync {
            // ensure delegate was invoked three times
            XCTAssertEqual(delegate.processNextInvocations.count, 3)
        }
    }

    func testThatItGetsATimerWhenARequestFails() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        scheduler.didEnqueueNewRequest()

        dispatchQueue.sync {
            // ensure timer provider starts out clean
            XCTAssertEqual(timerProvider.scheduledTimerInvocations.count, 0)
        }

        // fail request
        scheduler.requestDidFail()

        dispatchQueue.sync {
            // ensure timer provider was invoked
            XCTAssertEqual(timerProvider.scheduledTimerInvocations.count, 1)
            let invocation = timerProvider.scheduledTimerInvocations[0]
            XCTAssertEqual(invocation.timeInterval, timeInterval)
            XCTAssertTrue(invocation.target === scheduler)
        }
    }

    func testThatItReinvokesTheDelegateWhenARequestFailsAndTheTimerFinishes() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        scheduler.didEnqueueNewRequest()

        // fail request
        scheduler.requestDidFail()

        dispatchQueue.sync {
            // ensure delegate starts out clean
            XCTAssertEqual(delegate.processNextInvocations.count, 1)

            // ensure timer provider was invoked
            XCTAssertEqual(timerProvider.scheduledTimerInvocations.count, 1)

            // finish timer
            let invocation = timerProvider.scheduledTimerInvocations[0]
            _ = invocation.target.perform(invocation.selector)
        }

        dispatchQueue.sync {
            // ensure delegate was invoked
            XCTAssertEqual(delegate.processNextInvocations.count, 2)
        }
    }

    func testThatItInvalidatesTheTimerAndInvokesTheDelegateWhenDidEnqueueNewRequestIsCalledAndAPriorRequestFailedAndTheTimerHasNotFinished() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        scheduler.didEnqueueNewRequest()

        // fail request
        scheduler.requestDidFail()

        // invoke scheduler
        scheduler.didEnqueueNewRequest()

        dispatchQueue.sync {
            // ensure timer was invalidated
            XCTAssertEqual(timer.invalidateInvocations, 1)

            // ensure delegate was invoked only twice
            XCTAssertEqual(delegate.processNextInvocations.count, 2)
        }
    }

    func testThatItInvokesTheDelegateWhenFlushIsCalledIfAPriorRequestFailedEvenfIfTheTimerHasNotFinished() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        scheduler.flush()

        // fail request
        scheduler.requestDidFail()

        dispatchQueue.sync {
            // ensure timer starts out clean
            XCTAssertEqual(timer.invalidateInvocations, 0)
        }

        // invoke scheduler
        scheduler.flush()

        dispatchQueue.sync {
            // ensure timer was invalidated
            XCTAssertEqual(timer.invalidateInvocations, 1)

            // ensure delegate was invoked only twice
            XCTAssertEqual(delegate.processNextInvocations.count, 2)
        }
    }

    // MARK: - barrier vs concurrent

    func testThatItInvokesTheProcessingDelegateOnceWhenProcessingBarrier() {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        scheduler.flush()

        dispatchQueue.sync {
            // ensure delegate was not invoked
            XCTAssertEqual(delegate.processNextInvocations.count, 1)
        }
    }

    func testThatItInvokesTheProcessingDelegateTwiceWhenProcessingConcurrent() {

        // state
        delegate.processNextStubs = [.processedConcurrent]

        // invoke scheduler
        scheduler.flush()

        dispatchQueue.sync {
            // ensure delegate was not invoked
            XCTAssertEqual(delegate.processNextInvocations.count, 2)
        }
    }
}

// MARK: - Doubles

private final class MockTimer: ScheduledTimer {

    var invalidateInvocations = 0
    func invalidate() {
        invalidateInvocations += 1
    }
}

private final class MockTimerProvider: ScheduledTimerProviding {

    private let timer: MockTimer

    init(timer: MockTimer) {
        self.timer = timer
    }

    var scheduledTimerInvocations = [(timeInterval: TimeInterval, target: AnyObject, selector: Selector)]()
    func scheduledTimer(timeInterval: TimeInterval, target: AnyObject, selector: Selector) -> ScheduledTimer {
        scheduledTimerInvocations.append((timeInterval: timeInterval, target: target, selector: selector))
        return timer
    }
}
