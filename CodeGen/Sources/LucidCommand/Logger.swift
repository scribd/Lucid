//
//  Logger.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/20/19.
//

import LucidCodeGenCore
import PathKit

// MARK: - Errors

struct PrintableError: Error, CustomStringConvertible {
    let description: String
}

extension DecodingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dataCorrupted(let context):
            return "Corrupted data -  \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "Could not find key: \(key.stringValue) - \(context.debugDescription)"
        case .typeMismatch(let type, let context):
            return "Mismatching type: \(type) - \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Could not find value: \(type) - \(context.debugDescription)"
        @unknown default:
            fatalError("Unhandled new case: \(self).")
        }
    }
}

// MARK: - Levels

enum LogLevel: Int {
    case none = -1
    case error = 0
    case warning = 1
    case info = 2
}

// MARK: - Logger

final class Logger {
    
    private var depth = 0
    private var stepsByDepth = [Int: Int]()
    
    private let level: LogLevel
    
    init(level: LogLevel = .info) {
        self.level = level
    }
    
    func warn(_ message: String) {
        print(level: .warning, "\(indentation)⚠️  \(message)")
    }
    
    func error(_ message: String) {
        print(level: .error, "\(indentation)🔴 \(message)")
    }
    
    func throwError(_ message: String) throws -> Never {
        error(message)
        throw PrintableError(description: message)
    }
    
    func info(_ message: String) {
        print(level: .info, "\(indentation)- \(message)")
    }

    func done(_ message: String) {
        print(level: .info, "\(indentation)✅ \(message)")
    }
    
    func br() {
        print(level: .info, String())
    }
    
    func moveToChild(_ message: String) {
        let step = stepsByDepth[depth] ?? 0
        let startIcon = UnicodeScalar(9312 + step) ?? "🚥"
        print(level: .info, "\(indentation)\(startIcon)  >>>  \(message)")
        stepsByDepth[depth] = step + 1
        depth += 1
    }

    func moveToParent() {
        stepsByDepth[depth] = nil
        depth -= 1
    }

    func ask<T>(_ message: String, defaultValue: T? = nil) -> T where T: UserInputConvertible {

        while true {
            let defaultMessage = defaultValue.flatMap { " (default: \($0.userDescription))" } ?? String()
            info("\(message) [\(T.userTypeDescription)]\(defaultMessage)")
            guard let input = readLine() else { continue }
            guard input.isEmpty == false else {
                if let defaultValue = defaultValue {
                    return defaultValue
                } else {
                    error("Invalid input: \(input)")
                    continue
                }
            }

            if let value = T(input) {
                return value
            } else {
                error("Invalid input: \(input)")
            }
        }
    }
    
    private var indentation: String {
        return (0..<depth).map { _ in "  " }.joined() + "  "
    }
    
    private func print(level: LogLevel, _ string: String) {
        guard level.rawValue <= self.level.rawValue else { return }
        Swift.print(string)
    }
}

protocol UserInputConvertible {
    init?(_ description: String)
    var userDescription: String { get }
    static var userTypeDescription: String { get }
}

extension UserInputConvertible {
    static var userTypeDescription: String {
        return "\(Self.self)"
    }
}

extension UserInputConvertible where Self: CustomStringConvertible {
    var userDescription: String {
        return description
    }
}

extension String: UserInputConvertible {}
extension Int: UserInputConvertible {}
extension Double: UserInputConvertible {}
extension Float: UserInputConvertible {}
extension Path: UserInputConvertible {}

extension Array: UserInputConvertible where Element: UserInputConvertible {

    init?(_ description: String) {
        let strings = description
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let elements = strings.compactMap { Element($0) }

        guard strings.count == elements.count else {
            return nil
        }

        self = elements
    }
}

extension Bool: UserInputConvertible {

    init?(_ description: String) {
        switch description.lowercased() {
        case "true",
             "yes",
             "y",
             "1":
            self = true
        case "false",
             "no",
             "n",
             "0":
            self = false
        default:
            return nil
        }
    }

    var userDescription: String {
        return self ? "y" : "n"
    }

    static var userTypeDescription: String {
        return "y/n"
    }
}
