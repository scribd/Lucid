//
//  Version.swift
//  Lucid
//
//  Created by Stephane Magne on 1/13/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

struct Version: Comparable, CustomStringConvertible {

    let major: Int
    let minor: Int
    let dot: Int?

    private init(major: Int, minor: Int, dot: Int?) {
        self.major = major
        self.minor = minor
        self.dot = dot
    }

    init(_ versionString: String) throws {
        var split: [Int] = try versionString.split(separator: ".").map { component in
            guard let value = Int(String(component)) else {
                throw VersionError.couldNotFormFromString(versionString)
            }
            return value
        }.reversed()
        guard let major = split.popLast(), let minor = split.popLast() else {
            throw VersionError.couldNotFormFromString(versionString)
        }
        self.major = major
        self.minor = minor
        self.dot = split.popLast()
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major < rhs.major { return true }
        guard lhs.major == rhs.major else { return false }
        if lhs.minor < rhs.minor { return true }
        guard lhs.minor == rhs.minor else { return false }
        if (lhs.dot ?? .min) < (rhs.dot ?? .min) { return true }
        return false
    }

    static var oldestVersion: Version { return Version(major: 9, minor: 5, dot: 0) }

    var description: String {
        if let dot = dot {
            return "\(major).\(minor).\(dot)"
        } else {
            return "\(major).\(minor)"
        }
    }
}

enum VersionError: Error, CustomStringConvertible {
    case couldNotFormFromString(String)

    var description: String {
        switch self {
        case .couldNotFormFromString(let string):
            return "Could not form valid version from string '\(string)'"
        }
    }
}
