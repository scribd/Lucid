//
//  LoggerMock.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 2/6/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import XCTest

@testable import Lucid

@objc(SCLoggerMock)
final class LoggerMock: NSObject, Logging {
    
    let shouldCauseFailures: Bool
    
    let logLevel: LogType
    
    init(logLevel: LogType = .debug, shouldCauseFailures: Bool = true) {
        self.logLevel = logLevel
        self.shouldCauseFailures = shouldCauseFailures
    }
    
    func log(_ type: LogType,
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
    
    func loggableErrorString(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain):\(nsError.code):\(String(describing: nsError.userInfo[NSLocalizedDescriptionKey]))"
    }
    
    func recordErrorOnCrashlytics(_ error: Error) {
        // no-op
    }
}
