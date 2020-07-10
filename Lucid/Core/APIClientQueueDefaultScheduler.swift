//
//  APIClientQueueDefaultScheduler.swift
//  Lucid
//
//  Created by Ibrahim Sha'ath on 3/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

public final class APIClientQueueDefaultScheduler {

    private enum State {
        case ready
        case requestScheduled(timer: ScheduledTimer)
    }

    private let stateQueue: DispatchQueue
    private var _state: State

    private let timeInterval: TimeInterval
    private let timerProvider: ScheduledTimerProviding

    public weak var delegate: APIClientQueueSchedulerDelegate?

    public init(timeInterval: TimeInterval = Constants.defaultTimeInterval,
                timerProvider: ScheduledTimerProviding = ScheduledTimerProvider(),
                stateQueue: DispatchQueue = DispatchQueue(label: "\(APIClientQueueDefaultScheduler.self)_state_queue")) {

        self.timeInterval = timeInterval
        self.timerProvider = timerProvider
        self.stateQueue = stateQueue
        self._state = .ready

        if stateQueue === DispatchQueue.main {
            Logger.log(.error, "\(APIClientQueueDefaultScheduler.self) should not assign the main queue as the state queue.", assert: true)
        }
    }
}

extension APIClientQueueDefaultScheduler: APIClientQueueScheduling {

    public func didEnqueueNewRequest() {
        stateQueue.async(flags: .barrier) {
            self._beginRequest()
        }
    }

    public func flush() {
        stateQueue.async(flags: .barrier) {
            self._beginRequest()
        }
    }

    public func requestDidSucceed() {
        stateQueue.async(flags: .barrier) {
            switch self._state {
            case .requestScheduled:
                Logger.log(.info, "\(APIClientQueueDefaultScheduler.self) request did succeed while in scheduled state.")
            case .ready:
                self._beginRequest()
            }
        }
    }

    public func requestDidFail() {
        stateQueue.async(flags: .barrier) {
            switch self._state {
            case .requestScheduled:
                Logger.log(.info, "\(APIClientQueueDefaultScheduler.self) request did fail while in scheduled state")
                return
            case .ready:
                let timer = self.timerProvider.scheduledTimer(timeInterval: self.timeInterval,
                                                              target: self,
                                                              selector: #selector(self.beginRequest))
                self._state = .requestScheduled(timer: timer)
            }
        }
    }
}

private extension APIClientQueueDefaultScheduler {

    @objc func beginRequest() {
        stateQueue.async(flags: .barrier) {
            self._beginRequest()
        }
    }

    func _beginRequest() {
        switch _state {
        case .ready:
             break
        case .requestScheduled(let timer):
            timer.invalidate()
        }

        _state = .ready

        guard let delegate = delegate else {
            Logger.log(.error, "\(APIClientQueueDefaultScheduler.self) lacks delegate", assert: true)
            return
        }

        let processResult = delegate.processNext()

        switch processResult {
        case .didNotProcess,
             .processedBarrier:
            return
        case .processedConcurrent:
            _beginRequest()
        }
    }
}

public extension APIClientQueueDefaultScheduler {

    enum Constants {
        public static let defaultTimeInterval: TimeInterval = 15
    }
}
