//
//  BackgroundTaskManager.swift
//  Lucid
//
//  Created by Ibrahim Sha'ath on 2/28/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
import UIKit
import ReactiveKit

#if os(iOS)

protocol BackgroundTaskManaging: AnyObject {
    func beginBackgroundTask(expirationHandler: (() -> Void)?) -> UIBackgroundTaskIdentifier
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier)
}

extension BackgroundTaskManaging {

    /// Begin background task and renew it once it times out.
    func beginBackgroundTask(taskID: Property<UIBackgroundTaskIdentifier>? = nil, timeout: TimeInterval = 30, expirationHandler: @escaping () -> Void) -> Property<UIBackgroundTaskIdentifier> {
        let taskID = taskID ?? Property(UIBackgroundTaskIdentifier.invalid)

        let timer = Timer(timeInterval: timeout, repeats: false) { timer in
            timer.invalidate()
            if taskID.value != .invalid {
                self.endBackgroundTask(taskID.value)
                taskID.value = .invalid
                taskID.value = self.beginBackgroundTask(taskID: nil, timeout: timeout, expirationHandler: expirationHandler).value
            }
        }
        RunLoop.current.add(timer, forMode: .default)

        var originalValue = UIBackgroundTaskIdentifier.invalid
        taskID.value = beginBackgroundTask {
            timer.invalidate()
            let value = taskID.value
            if value != .invalid, value == originalValue {
                self.endBackgroundTask(taskID.value)
                taskID.value = .invalid
            }
            expirationHandler()
        }
        originalValue = taskID.value

        return taskID
    }
}

extension UIApplication: BackgroundTaskManaging { }

#endif
