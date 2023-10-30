//
//  APIClientQueueDefaultScheduler.swift
//  Lucid
//
//  Created by Ibrahim Sha'ath on 3/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

public final class APIClientQueueDefaultScheduler {

    private actor State {
        enum Value {
            case ready
            case requestScheduled(timer: ScheduledTimer)
        }

        var currentValue: Value = .ready

        func setValue(value: Value) {
            self.currentValue = value
        }
    }

    private var _state: State

    private let timeInterval: TimeInterval
    private let timerProvider: ScheduledTimerProviding

    public weak var delegate: APIClientQueueSchedulerDelegate?

    public init(timeInterval: TimeInterval = Constants.defaultTimeInterval,
                timerProvider: ScheduledTimerProviding = ScheduledTimerProvider()) {

        self.timeInterval = timeInterval
        self.timerProvider = timerProvider
        self._state = State()
    }
}

extension APIClientQueueDefaultScheduler: APIClientQueueScheduling {

    public func didEnqueueNewRequest() async {
        await self._beginRequest()
    }

    public func flush() async {
        await self._beginRequest()
    }

    public func requestDidSucceed() async {
        switch await self._state.currentValue {
        case .requestScheduled:
            Logger.log(.info, "\(APIClientQueueDefaultScheduler.self) request did succeed while in scheduled state.")
        case .ready:
            await self._beginRequest()
        }
    }

    public func requestDidFail() async {
        switch await self._state.currentValue {
        case .requestScheduled:
            Logger.log(.info, "\(APIClientQueueDefaultScheduler.self) request did fail while in scheduled state")
            return
        case .ready:
            let timer = self.timerProvider.scheduledTimer(timeInterval: self.timeInterval,
                                                          target: self,
                                                          selector: #selector(self.beginRequest))
            await self._state.setValue(value: .requestScheduled(timer: timer))
        }
    }
}

private extension APIClientQueueDefaultScheduler {

    @objc func beginRequest() {
        Task {
            await self._beginRequest()
        }
    }

    func _beginRequest() async {
        switch await _state.currentValue {
        case .ready:
             break
        case .requestScheduled(let timer):
            timer.invalidate()
        }

        await _state.setValue(value: .ready)

        guard let delegate = delegate else {
            Logger.log(.error, "\(APIClientQueueDefaultScheduler.self) lacks delegate", assert: true)
            return
        }

        let processResult = await delegate.processNext()

        switch processResult {
        case .didNotProcess,
             .processedBarrier:
            return
        case .processedConcurrent:
            await _beginRequest()
        }
    }
}

public extension APIClientQueueDefaultScheduler {

    enum Constants {
        public static let defaultTimeInterval: TimeInterval = 15
    }
}
