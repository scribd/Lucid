//
//  AnyEquatable.swift
//  Lucid
//
//  Created by Théophane Rupin on 5/2/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

struct AnyEquatable: Equatable, CustomDebugStringConvertible, CustomStringConvertible {

    typealias Comparer = (Any, Any) -> Bool

    private let comparer: Comparer

    let target: Any

    init(target: Any, comparer: @escaping Comparer) {
        self.target = target
        self.comparer = comparer
    }

    init<E: Equatable>(typedTarget: E) {
        self.target = typedTarget
        self.comparer = { lhs, rhs in
            guard let typedLHS = lhs as? E,
                let typedRHS = rhs as? E else {
                    return false
            }
            return typedLHS == typedRHS
        }
    }

    static func == (lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
        return lhs.comparer(lhs.target, rhs.target)
    }

    var description: String {
        return "\(self.target)"
    }

    var debugDescription: String {
        return "\(self.target)"
    }
}