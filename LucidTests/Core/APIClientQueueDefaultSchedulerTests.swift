//
//  APIClientQueueDefaultSchedulerTests.swift
//  LucidTests
//
//  Created by Ibrahim Sha'ath on 3/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Lucid
@testable import LucidTestKit

final class APIClientQueueDefaultSchedulerTests: XCTestCase {

    private var timeInterval: TimeInterval!

    private var timer: MockTimer!

    private var timerProvider: MockTimerProvider!

    private var delegate: APIClientQueueSchedulerDelegateSpy!

    private var scheduler: APIClientQueueDefaultScheduler!

    override func setUp() {
        super.setUp()
        timeInterval = 12345
        LucidConfiguration.logger = LoggerMock()
        timer = MockTimer()
        timerProvider = MockTimerProvider(timer: timer)
        delegate = APIClientQueueSchedulerDelegateSpy()
        scheduler = APIClientQueueDefaultScheduler(timeInterval: timeInterval,
                                                   timerProvider: timerProvider)
        scheduler.delegate = delegate
    }

    override func tearDown() {
        timeInterval = nil
        timer = nil
        timerProvider = nil
        delegate = nil
        scheduler = nil
        super.tearDown()
    }
}

extension APIClientQueueDefaultSchedulerTests {

    func testThatItInvokesTheDelegateWhenDidEnqueueNewRequestIsCalledInACleanState() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // ensure delegate starts out clean
        XCTAssertEqual(delegate.processNextInvocations.count, 0)

        // invoke scheduler
        await scheduler.didEnqueueNewRequest()

        // ensure delegate was invoked
        XCTAssertEqual(self.delegate.processNextInvocations.count, 1)
    }

    func testThatItInvokesTheDelegateWhenFlushIsCalledInACleanState() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // ensure delegate starts out clean
        XCTAssertEqual(delegate.processNextInvocations.count, 0)

        // invoke scheduler
        await scheduler.flush()

        // ensure delegate was invoked
        XCTAssertEqual(self.delegate.processNextInvocations.count, 1)
    }

    func testThatItInvokesTheDelegateEveryTimeDidEnqueueNewRequestIsCalledWhileTheDelegateHasNothingToProcess() async {

        // state
        delegate.processNextStubs = [.didNotProcess]

        // ensure delegate starts out clean
        XCTAssertEqual(delegate.processNextInvocations.count, 0)

        // invoke scheduler
        await scheduler.didEnqueueNewRequest()
        await scheduler.didEnqueueNewRequest()
        await scheduler.didEnqueueNewRequest()

        // ensure delegate was invoked
        XCTAssertEqual(self.delegate.processNextInvocations.count, 3)
    }

    func testThatItInvokesTheDelegateEveryTimeFlushIsCalledWhileTheDelegateHasNothingToProcess() async {

        // state
        delegate.processNextStubs = [.didNotProcess]

        // ensure delegate starts out clean
        XCTAssertEqual(delegate.processNextInvocations.count, 0)

        // invoke scheduler
        await scheduler.flush()
        await scheduler.flush()
        await scheduler.flush()

        // ensure delegate was invoked
        XCTAssertEqual(self.delegate.processNextInvocations.count, 3)
    }

    func testThatItInvokesTheDelegateEveryTimeDidEnqueueNewRequestIsCalled() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        await scheduler.didEnqueueNewRequest()
        await scheduler.didEnqueueNewRequest()

        // ensure delegate was invoked twice
        XCTAssertEqual(self.delegate.processNextInvocations.count, 2)
    }

    func testThatItInvokesTheDelegateWhenFlushIsCalledEvenIfOperationsAreProcessing() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        await scheduler.didEnqueueNewRequest()
        await scheduler.flush()

        // ensure delegate was invoked twice
        XCTAssertEqual(self.delegate.processNextInvocations.count, 2)
    }

    func testThatItReinvokesTheDelegateWhenARequestSucceeds() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        await scheduler.didEnqueueNewRequest()
        await scheduler.requestDidSucceed()

        // ensure delegate was invoked twice
        XCTAssertEqual(self.delegate.processNextInvocations.count, 2)
    }

    func testThatItInvokesTheDelegateWhenDidEnqueueNewRequestIsCalledIfThePriorRequestWasSuccessfulAndNoFurtherRequestsWereWaiting() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        await scheduler.didEnqueueNewRequest()
        await scheduler.requestDidSucceed()

        // invoke scheduler
        await scheduler.didEnqueueNewRequest()

        // ensure delegate was invoked three times
        XCTAssertEqual(self.delegate.processNextInvocations.count, 3)
    }

    func testThatItInvokesTheDelegateWhenFlushIsCalledIfThePriorRequestWasSuccessfulAndNoFurtherRequestsWereWaiting() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        await scheduler.flush()
        await scheduler.requestDidSucceed()
        await scheduler.flush()

        // ensure delegate was invoked three times
        XCTAssertEqual(self.delegate.processNextInvocations.count, 3)
    }

    func testThatItGetsATimerWhenARequestFails() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        await scheduler.didEnqueueNewRequest()

        // ensure timer provider starts out clean
        XCTAssertEqual(self.timerProvider.scheduledTimerInvocations.count, 0)

        // fail request
        await scheduler.requestDidFail()

        // ensure timer provider was invoked
        XCTAssertEqual(self.timerProvider.scheduledTimerInvocations.count, 1)
        let invocation = self.timerProvider.scheduledTimerInvocations[0]
        XCTAssertEqual(invocation.timeInterval, self.timeInterval)
        XCTAssertTrue(invocation.target === self.scheduler)
    }

    func testThatItReinvokesTheDelegateWhenARequestFailsAndTheTimerFinishes() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        await scheduler.didEnqueueNewRequest()

        // fail request
        await scheduler.requestDidFail()

        // ensure delegate starts out clean
        XCTAssertEqual(self.delegate.processNextInvocations.count, 1)

        // ensure timer provider was invoked
        XCTAssertEqual(self.timerProvider.scheduledTimerInvocations.count, 1)

        // finish timer
        let invocation = self.timerProvider.scheduledTimerInvocations[0]
        _ = invocation.target.perform(invocation.selector)

        try? await Task.sleep(nanoseconds: 1000000)

        // ensure delegate was invoked
        XCTAssertEqual(self.delegate.processNextInvocations.count, 2)
    }

    func testThatItInvalidatesTheTimerAndInvokesTheDelegateWhenDidEnqueueNewRequestIsCalledAndAPriorRequestFailedAndTheTimerHasNotFinished() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        await scheduler.didEnqueueNewRequest()

        // fail request
        await scheduler.requestDidFail()

        // invoke scheduler
        await scheduler.didEnqueueNewRequest()

        // ensure timer was invalidated
        XCTAssertEqual(self.timer.invalidateInvocations, 1)

        // ensure delegate was invoked only twice
        XCTAssertEqual(self.delegate.processNextInvocations.count, 2)
    }

    func testThatItInvokesTheDelegateWhenFlushIsCalledIfAPriorRequestFailedEvenfIfTheTimerHasNotFinished() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        await scheduler.flush()

        // fail request
        await scheduler.requestDidFail()

        // ensure timer starts out clean
        XCTAssertEqual(self.timer.invalidateInvocations, 0)

        // invoke scheduler
        await scheduler.flush()

        // ensure timer was invalidated
        XCTAssertEqual(self.timer.invalidateInvocations, 1)

        // ensure delegate was invoked only twice
        XCTAssertEqual(self.delegate.processNextInvocations.count, 2)
    }

    // MARK: - barrier vs concurrent

    func testThatItInvokesTheProcessingDelegateOnceWhenProcessingBarrier() async {

        // state
        delegate.processNextStubs = [.processedBarrier]

        // invoke scheduler
        await scheduler.flush()

        // ensure delegate was not invoked
        XCTAssertEqual(self.delegate.processNextInvocations.count, 1)
    }

    func testThatItInvokesTheProcessingDelegateTwiceWhenProcessingConcurrent() async {

        // state
        delegate.processNextStubs = [.processedConcurrent]

        // invoke scheduler
        await scheduler.flush()

        // ensure delegate was not invoked
        XCTAssertEqual(self.delegate.processNextInvocations.count, 2)
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
