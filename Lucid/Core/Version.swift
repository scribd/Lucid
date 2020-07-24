//
//  Version.swift
//  Lucid
//
//  Created by Stephane Magne on 1/13/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

public struct Version: Comparable, CustomStringConvertible {

    public let major: Int
    public let minor: Int
    public let patch: Int?

    private init(major: Int, minor: Int, patch: Int?) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(_ versionString: String) throws {
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
        self.patch = split.popLast()
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major < rhs.major { return true }
        guard lhs.major == rhs.major else { return false }
        if lhs.minor < rhs.minor { return true }
        guard lhs.minor == rhs.minor else { return false }
        if (lhs.patch ?? .min) < (rhs.patch ?? .min) { return true }
        return false
    }

    static var oldestVersion: Version { return Version(major: 0, minor: 0, patch: nil) }

    public var description: String {
        if let patch = patch {
            return "\(major).\(minor).\(patch)"
        } else {
            return "\(major).\(minor)"
        }
    }
}

public enum VersionError: Error, CustomStringConvertible {
    case couldNotFormFromString(String)

    public var description: String {
        switch self {
        case .couldNotFormFromString(let string):
            return "Could not form valid version from string '\(string)'"
        }
    }
}
