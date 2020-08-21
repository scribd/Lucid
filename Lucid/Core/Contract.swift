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

// MARK: Contracts

public struct AlwaysValidContract: EntityContract {

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
