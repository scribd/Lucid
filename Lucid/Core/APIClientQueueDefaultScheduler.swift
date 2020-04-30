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
        case requestInProgress
        case requestScheduled(timer: ScheduledTimer)
    }
    
    private let dispatchQueue: DispatchQueue
    private var _state: State

    private let timeInterval: TimeInterval
    private let timerProvider: ScheduledTimerProviding

    public weak var delegate: APIClientQueueSchedulerDelegate?

    public init(timeInterval: TimeInterval = Constants.defaultTimeInterval,
                timerProvider: ScheduledTimerProviding = ScheduledTimerProvider(),
                dispatchQueue: DispatchQueue = DispatchQueue(label: "\(APIClientQueueDefaultScheduler.self)")) {

        self.timeInterval = timeInterval
        self.timerProvider = timerProvider
        self.dispatchQueue = dispatchQueue

        _state = .ready
    }
}

extension APIClientQueueDefaultScheduler: APIClientQueueScheduling {

    public func didEnqueueNewRequest() {
        dispatchQueue.async(flags: .barrier) {
            switch self._state {
            case .ready,
                 .requestScheduled:
                self._beginRequest()
            case .requestInProgress:
                return
            }
        }
    }

    public func flush() {
        dispatchQueue.async(flags: .barrier) {
            switch self._state {
            case .ready,
                 .requestScheduled:
                self._beginRequest()
            case .requestInProgress:
                return
            }
        }
    }

    public func requestDidSucceed() {
        dispatchQueue.async(flags: .barrier) {
            switch self._state {
            case .ready,
                 .requestScheduled:
                Logger.log(.error, "\(APIClientQueueDefaultScheduler.self) encountered unexpected state", assert: true)
                return
            case .requestInProgress:
                self._state = .ready
                self._beginRequest()
            }
        }
    }

    public func requestDidFail() {
        dispatchQueue.async(flags: .barrier) {
            switch self._state {
            case .ready,
                 .requestScheduled:
                Logger.log(.error, "\(APIClientQueueDefaultScheduler.self) encountered unexpected state", assert: true)
                return
            case .requestInProgress:
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
        dispatchQueue.async {
            self._beginRequest()
        }
    }
    
    func _beginRequest() {

        switch _state {
        case .requestInProgress:
            Logger.log(.error, "\(APIClientQueueDefaultScheduler.self) encountered unexpected state", assert: true)
            return
        case .ready:
             break
        case .requestScheduled(let timer):
            timer.invalidate()
        }

        guard let delegate = delegate else {
            Logger.log(.error, "\(APIClientQueueDefaultScheduler.self) lacks delegate", assert: true)
            return
        }

        let requestIsInProgress = delegate.processNext()

        if requestIsInProgress {
            _state = .requestInProgress
        } else {
            _state = .ready
        }
    }
}

public extension APIClientQueueDefaultScheduler {

    enum Constants {
        public static let defaultTimeInterval: TimeInterval = 15
    }
}
