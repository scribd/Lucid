//
//  BackgroundTaskManagerSpy.swift
//  LucidTestKit
//
//  Created by Ibrahim Sha'ath on 2/28/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
import UIKit
@testable import Lucid_ReactiveKit

public final class BackgroundTaskManagerSpy: BackgroundTaskManaging {

    // MARK: - Records

    public private(set) var expirationHandlerRecords = [UIBackgroundTaskIdentifier: (() -> Void)]()
    public private(set) var beginBackgroundTaskCallCountRecord = 0

    public private(set) var endBackgroundTaskRecords = [UIBackgroundTaskIdentifier]()

    // MARK: - Stubs

    public var backgroundTaskIDRawValueStub: Int = 123

    // MARK: - API

    public init() {
        // no-op
    }

    public func beginBackgroundTask(expirationHandler: (() -> Void)?) -> UIBackgroundTaskIdentifier {
        let identifier = UIBackgroundTaskIdentifier(rawValue: backgroundTaskIDRawValueStub)
        if let expirationHandler = expirationHandler {
            expirationHandlerRecords[identifier] = expirationHandler
        }
        beginBackgroundTaskCallCountRecord += 1
        return identifier
    }

    public func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        endBackgroundTaskRecords.append(identifier)
    }
}
