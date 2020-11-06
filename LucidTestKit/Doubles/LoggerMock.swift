//
//  LoggerMock.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 2/6/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import XCTest
import Lucid

@objc(SCLoggerMock)
public final class LoggerMock: NSObject, Logging {

    public let shouldCauseFailures: Bool

    public let logLevel: LogType

    public init(logLevel: LogType = .debug, shouldCauseFailures: Bool = true) {
        self.logLevel = logLevel
        self.shouldCauseFailures = shouldCauseFailures
    }

    public func log(_ type: LogType,
                    _ message: @autoclosure () -> String,
                    domain: String,
                    assert: Bool,
                    file: String,
                    function: String,
                    line: UInt) {

        guard type.rawValue >= logLevel.rawValue else { return }

        switch type {
        case .error where shouldCauseFailures:
            XCTFail("Unexpected error: \(message())")
        case .error,
             .debug,
             .info,
             .verbose,
             .warning:
            print("[\(type.rawValue)] \(message())")
        }
    }

    public func loggableErrorString(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain):\(nsError.code):\(String(describing: nsError.userInfo[NSLocalizedDescriptionKey]))"
    }

    public func recordErrorOnCrashlytics(_ error: Error) {
        // no-op
    }
}
