//
//  StringUtils.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/20/19.
//

import Foundation
import Meta

extension String {
    
    public func camelCased(separators: String = "_", strict: Bool = false) -> String {
        let words = components(separatedBy: CharacterSet(charactersIn: separators))
        return words.enumerated().reduce(String()) { $0 + ($1.offset == 0 && strict ? $1.element : $1.element.capitalized) }
    }

    private static let snakeCasedRegex: NSRegularExpression = {
        let pattern = "([a-z0-9])([A-Z])"
        do {
            return try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            fatalError("Could not create regex from pattern: \(pattern): \(error)")
        }
    }()

    var snakeCased: String {
        let range = NSRange(location: 0, length: count)
        return String.snakeCasedRegex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2").lowercased()
    }
    
    var variableCased: String {
        return split(separator: ".").map { string in
            var prefix = string.prefix { String($0) == String($0).uppercased() }
            if prefix.count > 1 && prefix.count < count {
                prefix.removeLast()
            }
            return String(prefix.lowercased() + suffix(count - prefix.count))
        }.joined(separator: ".")
    }
    
    var pluralName: String {
        let suffixMap: [(String, String)] = [
            ("y", "ies"),
            ("ed", "ed"),
            ("o", "o"),
            ("s", "s"),
        ]
        
        for map in suffixMap where hasSuffix(map.0) {
            return self.dropLast(map.0.count) + map.1
        }
        
        return self + "s"
    }
    
    func versionedName() throws -> String {
        if isArray {
            return "[\(try arrayElementType())V2]"
        }
        return self + "V2"
    }
    
    var unversionedName: String {
        if hasSuffix("V2") {
            return String(self[startIndex..<index(endIndex, offsetBy: -2)])
        } else {
            return self
        }
    }
    
    var isArray: Bool {
        return hasPrefix("[") && hasSuffix("]")
    }
    
    func arrayElementType() throws -> String {
        guard isArray else { return self }
        var string = self
        string.removeLast()
        string.removeFirst()
        guard string.isArray == false else {
            throw CodeGenError.unsupportedType(self)
        }
        return string
    }
    
    var reference: Reference {
        return .named(variableCased)
    }
}
