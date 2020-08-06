//
//  File.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/20/19.
//

import LucidCodeGen
import LucidCodeGenCore

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
    
    private var indentation: String {
        return (0..<depth).map { _ in "  " }.joined() + "  "
    }
    
    private func print(level: LogLevel, _ string: String) {
        guard level.rawValue <= self.level.rawValue else { return }
        Swift.print(string)
    }
}
