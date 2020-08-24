//
//  Contract.swift
//  Lucid
//
//  Created by Stephane Magne on 8/18/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation

// MARK: EntityContract

public protocol EntityContract {

    func shouldValidate<E>(_ entityType: E.Type) -> Bool where E: Entity

    func isEntityValid<E>(_ entity: E, for query: Query<E>) -> Bool where E: Entity
}

public protocol EntityGraphContract: EntityContract {

    func contract(at depth: Int) -> EntityGraphContract
}

public extension EntityGraphContract {

    func contract(at depth: Int) -> EntityGraphContract {
        // This currently mirrors existing functionality, will be completed with ticket IPT-4054
        if depth == 0 {
            return self
        } else {
            return AlwaysValidContract()
        }
    }
}

// MARK: Contracts

public struct AlwaysValidContract: EntityGraphContract {

    public init() { }

    public func shouldValidate<E>(_ entityType: E.Type) -> Bool where E: Entity {
        return false
    }

    public func isEntityValid<E>(_ entity: E, for query: Query<E>) -> Bool where E: Entity {
        return true
    }
}

/*
struct SampleContract: EntityContract {

    public func isEntityValid<E>(_ entity: E, for query: Query<E>) -> Bool where E: Entity {
        switch entity {
        case let entity as Genre:
            return entity.someValidationFunction(for: query)
            // or:
            // let genreContract = GenreContract(entity, for: query)
            // return genreContract.isValid()
        case let entity as Movie:
            return entity.someValidationFunction(for: query)
        default:
            return true
        }
    }
}
 */

/*
struct SampleGraphContract: EntityGraphContract {

    let levelContextualData: SomeData

    func contract(at depth: Int) -> EntityGraphContract {

        let contexualData = contextualContractData(depth: depth)

        return SampleGraphContract(levelContextualData: levelContextualData)
    }

    private func contextualContractData(depth: Int) -> ContextualData {
         // return some data
    }
 }
 */
