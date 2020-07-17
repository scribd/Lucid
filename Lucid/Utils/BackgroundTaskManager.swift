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
    func beginBackgroundTask(timeout: TimeInterval = 30, expirationHandler: @escaping () -> Void) -> Property<UIBackgroundTaskIdentifier> {
        let taskID = Property(UIBackgroundTaskIdentifier.invalid)

        let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { timer in
            timer.invalidate()
            if taskID.value != .invalid {
                self.endBackgroundTask(taskID.value)
                taskID.value = self.beginBackgroundTask(timeout: timeout, expirationHandler: expirationHandler).value
            }
        }

        taskID.value = beginBackgroundTask {
            timer.invalidate()
            if taskID.value != .invalid {
                self.endBackgroundTask(taskID.value)
                taskID.value = .invalid
            }
            expirationHandler()
        }

        return taskID
    }
}

extension UIApplication: BackgroundTaskManaging { }

#endif
