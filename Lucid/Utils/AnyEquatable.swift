//
//  AnyEquatable.swift
//  Lucid
//
//  Created by Théophane Rupin on 5/2/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

public struct AnyEquatable: Equatable, CustomDebugStringConvertible, CustomStringConvertible {

    public typealias Comparer = (Any, Any) -> Bool

    private let comparer: Comparer

    public let target: Any

    public init(target: Any, comparer: @escaping Comparer) {
        self.target = target
        self.comparer = comparer
    }

    public init<E: Equatable>(typedTarget: E) {
        self.target = typedTarget
        self.comparer = { lhs, rhs in
            guard let typedLHS = lhs as? E,
                let typedRHS = rhs as? E else {
                    return false
            }
            return typedLHS == typedRHS
        }
    }

    public static func == (lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
        return lhs.comparer(lhs.target, rhs.target)
    }

    public var description: String {
        return "\(self.target)"
    }

    public var debugDescription: String {
        return "\(self.target)"
    }
}
