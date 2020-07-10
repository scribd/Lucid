//
//  Logger.swift
//  Lucid
//
//  Created by Théophane Rupin on 12/7/17.
//  Copyright © 2017 Scribd. All rights reserved.
//

import Foundation
import os

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
    public static var shared: Logging? = DefaultLogger()

    public static func log(_ type: LogType,
                           _ message: @autoclosure () -> String,
                           domain: String,
                           assert: Bool = false,
                           file: String = #file,
                           function: String = #function,
                           line: UInt = #line) {

        shared?.log(type,
                    message(),
                    domain: domain,
                    assert: assert,
                    file: file,
                    function: function,
                    line: line)
    }

    public static func loggableErrorString(_ error: Error) -> String {
        return shared?.loggableErrorString(error) ?? String()
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

// MARK: - Default Logger

final class DefaultLogger: Logging {

    func log(_ type: LogType,
             _ message: @autoclosure () -> String,
             domain: String,
             assert: Bool = false,
             file: String = #file,
             function: String = #function,
             line: UInt = #line) {

        let file = file.components(separatedBy: CharacterSet(charactersIn: "/")).last ?? file
        if #available(iOS 12.0, *) {
            os_log(type.osLogType, "%s | %s:%u | %s", domain, file, line, message())
        } else {
            print("\(type.description) | \(domain) | \(file):\(line) | \(message())")
        }
        if assert {
            assertionFailure(message())
        }
    }

    func loggableErrorString(_ error: Error) -> String {
        return error.localizedDescription
    }

    func recordErrorOnCrashlytics(_ error: Error) {
        // no-op
    }
}

extension LogType: CustomStringConvertible {

    public var description: String {
        switch self {
        case .debug:
            return "*Debug*"
        case .error:
            return "*Error*"
        case .info:
            return "*Info**"
        case .verbose:
            return "Verbose"
        case .warning:
            return "Warning"
        }
    }
}

private extension LogType {

    var osLogType: OSLogType {
        switch self {
        case .debug:
            return .debug
        case .error:
            return .error
        case .info,
             .verbose:
            return .info
        case .warning:
            return .fault
        }
    }
}
