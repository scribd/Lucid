//
//  LogManagerProtocol.swift
//  Lucid
//
//  Created by Théophane Rupin on 12/7/17.
//  Copyright © 2017 Scribd. All rights reserved.
//

import Foundation

@objc(SCLogType)
public enum LogType: Int {
    case verbose
    case info
    case debug
    case warning
    case error
}

@objc(SCLogging)
public protocol Logging {
    
    @objc(logWithType:message:domain:assert:file:function:line:)
    func log(_ type: LogType,
             _ message: @autoclosure () -> String,
             domain: String,
             assert: Bool,
             file: String,
             function: String,
             line: UInt)

    func loggableErrorString(_ error: Error) -> String
    
    @objc func recordErrorOnCrashlytics(_ error: Error)
}

extension Logging {
    
    public func log(_ type: LogType,
                    _ message: @autoclosure () -> String,
                    domain: String,
                    assert: Bool = false,
                    _file: String = #file,
                    _function: String = #function,
                    _line: UInt = #line) {
        log(type, message(), domain: domain, assert: assert, file: _file, function: _function, line: _line)
    }
}

@objc public final class Logger: NSObject {

    @objc(sharedLogger)
    public static var shared: Logging?
    
    public static func log(_ type: LogType,
                           _ message: @autoclosure () -> String,
                           domain: String,
                           assert: Bool = false,
                           file: String = #file,
                           function: String = #function,
                           line: UInt = #line) {
        
        guard let shared = shared else {
            if NSClassFromString("XCTest") == nil {
                assertionFailure("\(Logger.self): shared logger should be set before calling \(#function)")
            }
            return
        }

        shared.log(type,
                   message(),
                   domain: domain,
                   assert: assert,
                   file: file,
                   function: function,
                   line: line)
    }
    
    public static func loggableErrorString(_ error: Error) -> String {
        guard let shared = shared else {
            if NSClassFromString("XCTest") == nil {
                assertionFailure("\(Logger.self): shared logger should be set before calling \(#function)")
            }
            return ""
        }

        return shared.loggableErrorString(error)
    }
}

// MARK: - Lucid Domain

extension Logger {
    
    static func log(_ type: LogType,
                    _ message: @autoclosure () -> String,
                    assert: Bool = false,
                    file: String = #file,
                    function: String = #function,
                    line: UInt = #line) {
        
        log(type, message(), domain: "Lucid", assert: assert, file: file, function: function, line: line)
    }
}
