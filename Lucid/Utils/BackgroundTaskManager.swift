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

protocol CoreBackgroundTaskManaging: AnyObject {
    func beginBackgroundTask(expirationHandler: (() -> Void)?) -> UIBackgroundTaskIdentifier
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier)
}

extension UIApplication: CoreBackgroundTaskManaging {}

protocol BackgroundTaskManaging: AnyObject {
    func start(_ timeoutHandler: @escaping () -> Void) -> UUID
    func stop(_ taskID: UUID) -> Bool
}

final class BackgroundTaskManager: BackgroundTaskManaging {

    private enum Constants {
        // The system can terminate the app for any background task not ended after 30s.
        static let timeout: TimeInterval = 30
    }

    private let coreManager: CoreBackgroundTaskManaging
    private let timeout: TimeInterval

    private var _taskID: UIBackgroundTaskIdentifier = .invalid
    private let dispatchQueue = DispatchQueue(label: "\(BackgroundTaskManager.self):taskID")
    private var _timeoutHandlers = [UUID: () -> Void]()

    init(_ coreManager: CoreBackgroundTaskManaging = UIApplication.shared,
         timeout: TimeInterval = Constants.timeout) {
        self.coreManager = coreManager
        self.timeout = timeout
    }

    func start(_ timeoutHandler: @escaping () -> Void) -> UUID {
        let uuid = UUID()
        dispatchQueue.async {
            if self._timeoutHandlers.count == 0 {
                self._start()
            }
            self._timeoutHandlers[uuid] = timeoutHandler
        }
        return uuid
    }

    func stop(_ taskID: UUID) -> Bool {
        return dispatchQueue.sync {
            let hasValue = self._timeoutHandlers[taskID] != nil
            self._timeoutHandlers[taskID] = nil
            return hasValue
        }
    }

    private func _start() {
        guard _taskID == .invalid else {
            Logger.log(.debug, "\(BackgroundTaskManager.self): A background task is already running: \(_taskID)")
            return
        }

        let timer = Timer(timeInterval: timeout, repeats: false) { timer in
            timer.invalidate()
            self.dispatchQueue.async {
                if self._timeoutHandlers.count > 0 {
                    Logger.log(.debug, "\(BackgroundTaskManager.self): Been running for \(self.timeout)s, restarting: \(self._taskID)")
                    self._stop()
                    self._start()
                } else {
                    Logger.log(.debug, "\(BackgroundTaskManager.self): Been running for \(self.timeout)s, no renewal necessary: \(self._taskID)")
                    self._stop()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .default)

        _taskID = coreManager.beginBackgroundTask {
            timer.invalidate()
            self.dispatchQueue.async {
                Logger.log(.warning, "\(BackgroundTaskManager.self): Background task timed out: \(self._taskID)")
                for handler in self._timeoutHandlers.values {
                    handler()
                }
                self._timeoutHandlers = [:]
                self._stop()
            }
        }

        Logger.log(.debug, "\(BackgroundTaskManager.self): Beginning new background task: \(_taskID)")
    }

    private func _stop() {
        guard _taskID != .invalid else { return }
        Logger.log(.debug, "\(BackgroundTaskManager.self): Ending background task: \(_taskID)")
        coreManager.endBackgroundTask(_taskID)
        _taskID = .invalid
    }
}

#endif
