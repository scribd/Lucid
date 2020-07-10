//
//  ScheduledTimer.swift
//  Lucid
//
//  Created by Ibrahim Sha'ath on 3/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

public protocol ScheduledTimer: AnyObject {
    func invalidate()
}

extension Timer: ScheduledTimer { }

public protocol ScheduledTimerProviding {
    func scheduledTimer(timeInterval: TimeInterval,
                        target: AnyObject,
                        selector: Selector) -> ScheduledTimer
}

public struct ScheduledTimerProvider: ScheduledTimerProviding {

    public init() { }

    public func scheduledTimer(timeInterval: TimeInterval,
                               target: AnyObject,
                               selector: Selector) -> ScheduledTimer {

        let timer = Timer(timeInterval: timeInterval,
                          target: target,
                          selector: selector,
                          userInfo: nil,
                          repeats: false)        

        RunLoop.main.add(timer, forMode: .common)

        return timer
    }
}
