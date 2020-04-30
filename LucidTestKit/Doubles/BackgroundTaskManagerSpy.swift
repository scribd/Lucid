//
//  BackgroundTaskManagerSpy.swift
//  LucidTestKit
//
//  Created by Ibrahim Sha'ath on 2/28/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
import UIKit

@testable import Lucid

final class BackgroundTaskManagerSpy: BackgroundTaskManaging {

    // MARK: - Records

    private(set) var expirationHandlerRecords = [UIBackgroundTaskIdentifier: (() -> Void)]()
    private(set) var beginBackgroundTaskCallCountRecord = 0

    private(set) var endBackgroundTaskRecords = [UIBackgroundTaskIdentifier]()

    // MARK: - Stubs

    var backgroundTaskIDRawValueStub: Int = 123

    // MARK: - API

    func beginBackgroundTask(expirationHandler: (() -> Void)?) -> UIBackgroundTaskIdentifier {
        let identifier = UIBackgroundTaskIdentifier(rawValue: backgroundTaskIDRawValueStub)
        if let expirationHandler = expirationHandler {
            expirationHandlerRecords[identifier] = expirationHandler
        }
        beginBackgroundTaskCallCountRecord += 1
        return identifier
    }

    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        endBackgroundTaskRecords.append(identifier)
    }
}
