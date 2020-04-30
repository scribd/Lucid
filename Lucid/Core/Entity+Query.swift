//
//  Entity+Query.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/28/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

// MARK: - Filter

public extension DualHashDictionary where Value: Entity, Value.Identifier == Key {
    
    /// Filters the values based on the filter's criteria.
    ///
    /// - Note: Returns the values with a pseudo random order.
    /// - Parameters:
    ///     - filter: Filter criteria used to filter down the values. When nil, all the values are returned.
    /// - Returns: An array of values.
    func filter(with filter: Query<Value>.Filter?) -> AnySequence<Value> {
        if let filter = filter {
            if let identifiers = filter.extractOrIdentifiers {
                return identifiers.lazy.compactMap { self[$0] }.any
            } else {
                return values.filter(with: filter)
            }
        } else {
            return values.any
        }
    }
}

public extension Sequence where Element: Entity {
    
    /// Filters the values based on the filter's criteria.
    ///
    /// - Parameters:
    ///     - filter: Filter criteria used to filter down the values. When nil, all the values are returned.
    /// - Returns: An array of values.
    func filter(with filter: Query<Element>.Filter?) -> AnySequence<Element> {
        guard let filter = filter else { return any }
        return self.filter { $0.evaluate(filter).boolValue }.any
    }
}

public extension OrderedDualHashDictionary where Value: Entity, Value.Identifier == Key {
    
    /// Filters the values based on the filter's criteria.
    ///
    /// - Parameters:
    ///     - filter: Filter criteria used to filter down the values. When nil, all the values are returned.
    /// - Returns: An array of values.
    func filter(with filter: Query<Value>.Filter?) -> AnySequence<Value> {
        if let filter = filter {
            if let identifiers = filter.extractOrIdentifiers {
                return identifiers.lazy.compactMap { self[$0] }.any
            } else {
                return dictionary.values.lazy.filter(with: filter)
            }
        } else {
            return dictionary.values.any
        }
    }
}

// MARK: - Order

public extension Sequence where Element: Entity {
    
    /// Sort elements based on a given ordering criteria.
    ///
    /// - Parameters:
    ///     - order: Ordering criteria used to sort the elements.
    ///     - elementsByID: A dictionary of the elements indexed by identifier used for optimization.
    ///                     If nil, a new one is created and used internally.
    /// - Returns: A sorted array of elements.
    func order(with order: [Query<Element>.Order], elementsByID: DualHashDictionary<Element.Identifier, Element>? = nil) -> [Element] {
        
        guard let nextOrdering = order.last else {
            return Array(self)
        }
        
        let sortedEntities: [Element] = {
            switch nextOrdering {
            case .asc(.identifier):
                return sorted { $0.identifier < $1.identifier }
            case .asc(.index(let index)):
                return sorted { $0.entityIndexValue(for: index) < $1.entityIndexValue(for: index) }
            case .desc(.identifier):
                return sorted { $0.identifier > $1.identifier }
            case .desc(.index(let index)):
                return sorted { $0.entityIndexValue(for: index) > $1.entityIndexValue(for: index) }
            case .natural:
                return Array(self)
            case .identifiers(let identifiers):
                let elementsByID = elementsByID ?? reduce(into: DualHashDictionary<Element.Identifier, Element>()) { $0[$1.identifier] = $1 }
                let identifiersSet = DualHashSet(identifiers)
                let results = identifiers.compactMap { elementsByID[$0] }
                if results.count == elementsByID.count {
                    return results
                }
                return results + filter { !identifiersSet.contains($0.identifier) }
            }
        }()
        
        return sortedEntities.order(with: order.dropLast(), elementsByID: elementsByID)
    }
}

public extension DualHashDictionary where Value: Entity, Value.Identifier == Key {

    /// Sort values based on a given ordering criteria.
    ///
    /// - Parameters:
    ///     - order: Ordering criteria used to sort the values.
    /// - Returns: A sorted array of values.
    func order(with order: [Query<Value>.Order]) -> [Value] {
        return values.order(with: order, elementsByID: self)
    }
}

public extension OrderedDualHashDictionary where Value: Entity, Value.Identifier == Key {
    
    /// Sort values based on a given ordering criteria.
    ///
    /// - Parameters:
    ///     - order: Ordering criteria used to sort the values.
    /// - Returns: A sorted array of values.
    func order(with order: [Query<Value>.Order]) -> [Value] {
        
        guard let nextOrdering = order.last else {
            return orderedKeyValues.map { $0.1 }
        }
        
        let values: [Value] = {
            switch nextOrdering {
            case .natural:
                return orderedKeyValues.map { $0.1 }
            case .asc,
                 .desc,
                 .identifiers:
                return lazy.map { $0.1 }.order(with: order, elementsByID: dictionary)
            }
        }()
        
        return values.order(with: order.dropLast(), elementsByID: dictionary)
    }
}
    
// MARK: - Evaluate

private extension Entity {
    
    /// Evaluate if an entity matches a given filter criteria.
    ///
    /// - Parameters:
    ///     - filter: Filter criteria.
    /// - Returns: `.bool(true)` if matching, `.bool(false)` otherwise.
    func evaluate(_ filter: Query<Self>.Filter) -> Query<Self>.Value {
        switch filter {
        case .binary(let property, .containedIn, .values(let values)),
             .binary(.values(let values), .containedIn, let property):
            let value = evaluate(property)
            return .bool(values.contains(value))
            
        case .binary(let left, let comparison, let right):
            let leftValue = evaluate(left)
            let rightValue = evaluate(right)
            
            switch comparison {
            case .equalTo:
                return .bool(leftValue == rightValue)
            case .and:
                return .bool(leftValue.boolValue && rightValue.boolValue)
            case .or:
                return .bool(leftValue.boolValue || rightValue.boolValue)
            case .match:
                return evaluateMatch(leftValue, rightValue)
            case .lessThan:
                return .bool(leftValue < rightValue)
            case .lessThanOrEqual:
                return .bool(leftValue <= rightValue)
            case .greaterThan:
                return .bool(leftValue > rightValue)
            case .greaterThanOrEqual:
                return .bool(leftValue >= rightValue)
            case .containedIn:
                return .bool(false)
            }
            
        case .negated(let filter):
            return .bool(evaluate(filter).boolValue == false)

        case .property(let property):
            switch property {
            case .identifier:
                return .identifier(identifier)
            case .index(let indexName):
                return .index(entityIndexValue(for: indexName))
            }
            
        case .value(let value):
            return value
            
        case .values:
            return .bool(true)
        }
    }
    
    private func evaluateMatch(_ lhs: Query<Self>.Value, _ rhs: Query<Self>.Value) -> Query<Self>.Value {
        switch (lhs, rhs) {
        case (.index(.regex(let regex)), .index(.string(let string))),
             (.index(.string(let string)), .index(.regex(let regex))):
            let range = NSRange(location: 0, length: string.count)
            return .bool(!regex.matches(in: string, options: [], range: range).isEmpty)
            
        case (.index(.string(let string)), .index(.string(let regexString))):
            do {
                let regex = try NSRegularExpression(pattern: regexString, options: [])
                return evaluateMatch(.index(.string(string)), .index(.regex(regex)))
            } catch {
                Logger.log(.error, "\(Self.self): Could not build regex from string: \(regexString).", assert: true)
                return .bool(false)
            }
            
        case (.index(.int(let value)), .index(.string(let regexString))):
            return evaluateMatch(.index(.string("\(value)")), .index(.string(regexString)))

        case (.index(.double(let value)), .index(.string(let regexString))):
            return evaluateMatch(.index(.string("\(value)")), .index(.string(regexString)))
            
        case (.index(.float(let value)), .index(.string(let regexString))):
            return evaluateMatch(.index(.string("\(value)")), .index(.string(regexString)))

        default:
            return .bool(lhs == rhs)
        }
    }
}

// MARK: - Utils

public extension Sequence where Element: EntityIdentifiable {
    
    var byIdentifier: OrderedDualHashDictionary<Element.Identifier, Element> {
        return OrderedDualHashDictionary(lazy.map { ($0.identifier, $0) })
    }
}
