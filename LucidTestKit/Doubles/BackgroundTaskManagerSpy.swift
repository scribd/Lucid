//
//  CoreBackgroundTaskManagerSpy.swift
//  LucidTestKit
//
//  Created by Ibrahim Sha'ath on 2/28/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation
import UIKit
@testable import Lucid_ReactiveKit

public final class CoreBackgroundTaskManagerSpy: CoreBackgroundTaskManaging {

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

public final class BackgroundTaskManagerSpy: BackgroundTaskManaging {

    // MARK: - Invocations

    public private(set) var startInvocations = [() -> Void]()
    public private(set) var stopInvocations = [UUID]()
    
    // MARK: - Values

    public var startValue = UUID()
    public var stopValue = true

    public init(){
        // no-op
    }

    // MARK: - API

    public func start(_ timeoutHandler: @escaping () -> Void) -> UUID {
        startInvocations.append(timeoutHandler)
        return startValue
    }

    public func stop(_ taskID: UUID) -> Bool {
        stopInvocations.append(taskID)
        return stopValue
    }
}
