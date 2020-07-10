//
//  Sequence.swift
//  Lucid
//
//  Created by Théophane Rupin on 9/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

public extension Sequence {

    @inlinable var any: AnySequence<Element> {
        return AnySequence(self)
    }

    @inlinable var array: [Element] {
        return Array(self)
    }

    @inlinable var first: Element? {
        return first { _ in true }
    }

    @inlinable var isEmpty: Bool {
        return first == nil
    }
}

public extension AnySequence {

    @inlinable static var empty: AnySequence<Element> {
        return Array.empty.any
    }
}

public extension Array {

    @inlinable static var empty: [Element] {
        return []
    }
}

extension AnySequence: Equatable where Element: Equatable {

    public static func == (lhs: AnySequence<Element>, rhs: AnySequence<Element>) -> Bool {
        return lhs.elementsEqual(rhs)
    }
}

public extension Result where Success: Sequence {

    @inlinable var any: Result<AnySequence<Success.Element>, Failure> {
        switch self {
        case .success(let sequence):
            return .success(sequence.any)
        case .failure(let error):
            return .failure(error)
        }
    }
}
