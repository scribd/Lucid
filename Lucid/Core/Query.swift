//
//  Query.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/21/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

// MARK: - Query

/// Contains criterias describing how to run a search query.
///
/// Search queries can be built easily with syntactic sugar.
///
/// E.g. search a rating by document identifier.
/// ```
/// let _ = Query<Rating>(filter: .identifier == .identifier(DocumentIdentifier(value: 42).ratingIdentifier))
/// ```
///
/// E.g. search ratings by document identifiers.
/// ```
/// let _ = Query<Rating>(filter: .identifier == .identifier(DocumentIdentifier(value: 42).ratingIdentifier)
///            || .identifier == .identifier(DocumentIdentifier(value: 24).ratingIdentifier))
/// ```
///
/// E.g. search documents matching title.
/// ```
/// let _ = Query<Document>(filter: .identifier ~= .string(".*super book.*"))
/// ```
public struct Query<E>: Equatable where E: Entity {

    // MARK: - Filter

    /// Filter expression representation.
    ///
    /// E.g. search a rating by document identifier.
    /// ```
    /// let _ = Filter<Rating>.binary(.property(.identifier), .equalTo, .value(DocumentIdentifier(value: 42).ratingIdentifier))
    /// ```
    public indirect enum Filter: Equatable {
        case property(Property)
        case value(Value)
        case values(DualHashSet<Value>)
        case negated(Filter)
        case binary(Filter, Operator, Filter)
    }

    // MARK: - Operator

    public enum Operator: Equatable {
        case equalTo
        case and
        case or
        case match
        case containedIn
        case greaterThan
        case greaterThanOrEqual
        case lessThan
        case lessThanOrEqual
    }

    // MARK: - Value

    public enum Value: DualHashable, Comparable {
        case identifier(E.Identifier)
        case index(EntityIndexValue<E.RelationshipIdentifier, E.Subtype>)
        case bool(Bool)
    }

    // MARK: - Property

    public enum Property: Equatable {
        case identifier
        case index(E.IndexName)
    }

    // MARK: - Order

    /// Order representation used for sorting.
    ///
    /// - Cases:
    ///     - asc: Ascendant order based on a given property.
    ///     - desc: Descendant order based on a given property.
    ///     - natural: Keep the server's order. No reordering.
    ///     - identifiers: Takes a given list of identifiers order.
    public enum Order: Equatable {
        case asc(by: Property)
        case desc(by: Property)
        case natural
        case identifiers(AnySequence<E.Identifier>)
    }

    // MARK: - Dependencies

    public var filter: Filter?
    public var groupedBy: E.IndexName?
    public var uniquely: Bool
    public var order: [Order]
    public var offset: Int?
    public var limit: Int?
    public var context: E.QueryContext?

    // MARK: - Init

    public init(filter: Filter? = nil,
                groupedBy: E.IndexName? = nil,
                uniquely: Bool = false,
                order: [Order] = [.asc(by: .identifier)],
                offset: Int? = nil,
                limit: Int? = nil,
                context: E.QueryContext? = nil) {
        self.filter = filter
        self.groupedBy = groupedBy
        self.uniquely = uniquely
        self.order = order
        self.offset = offset
        self.limit = limit
        self.context = context
    }

    // MARK: - Get Convenience

    public static func identifier(_ identifier: E.Identifier) -> Query {
        return Query(filter: .binary(
            .property(.identifier),
            .equalTo,
            .value(.identifier(identifier))
        ))
    }

    public var identifier: E.Identifier? {
        return filter?.extractOrIdentifiers?.first
    }

    public var identifiers: AnySequence<E.Identifier>? {
        return filter?.extractOrIdentifiers
    }

    // MARK: - Search Convenience

    public static func filter(_ filter: Filter?) -> Query {
        return Query(filter: filter)
    }

    public static func order<S>(_ order: S) -> Query where S: Sequence, S.Element == Order {
        return Query(order: order.array)
    }

    public func order<S>(_ order: S) -> Query where S: Sequence, S.Element == Order {
        var query = self
        query.order = order.array
        return query
    }

    public func grouped(by indexName: E.IndexName?) -> Query {
        var query = self
        query.groupedBy = indexName
        return query
    }

    public static var all: Query { return Query(filter: .all) }
}

// MARK: - QueryResultConvertible

extension Query.Property: QueryResultConvertible {

    public var requestValue: String {
        switch self {
        case .identifier:
            return "identifier"
        case .index(let index):
            return index.requestValue
        }
    }
}

// MARK: - Result

/// Contain the result of a search query.
///
/// - Cases:
///     - groups: For when the query has a groupBy property.
///     - entities: For regular queries.
public struct QueryResult<E>: QueryResultInterface where E: Entity {

    public enum Data {
        case groups(DualHashDictionary<EntityIndexValue<E.RelationshipIdentifier, E.Subtype>, [E]>)
        case entitiesSequence(AnySequence<E>)
        case entitiesArray([E])
    }

    private(set) var data: Data

    // MARK: - O(n) operations the first time only

    /// Convert to an array of entities
    ///
    /// - Note: O(n) the first time, then O(1).
    @discardableResult
    mutating public func materialize() -> QueryResult<E> {
        switch data {
        case .entitiesSequence(let entities):
            data = .entitiesArray(entities.array)
        case .groups,
             .entitiesArray:
            break
        }
        return self
    }

    // MARK: - O(n) operations before materialization, O(1) after.

    public var materialized: QueryResult<E> {
        switch data {
        case .entitiesSequence(let entities):
            return QueryResult(data: .entitiesArray(entities.array), _metadata: _metadata)
        case .groups,
             .entitiesArray:
            return self
        }
    }

    public var count: Int {
        return array.count
    }

    public var any: AnySequence<E> {
        switch data {
        case .groups(let groups):
            return groups.values.lazy.flatMap { $0 }.any
        case .entitiesSequence(let entities):
            return entities
        case .entitiesArray(let entities):
            return entities.any
        }
    }

    public var array: [E] {
        switch data {
        case .groups(let groups):
            return groups.values.flatMap { $0 }
        case .entitiesSequence(let entities):
            return entities.array
        case .entitiesArray(let entities):
            return entities
        }
    }

    public var groups: DualHashDictionary<EntityIndexValue<E.RelationshipIdentifier, E.Subtype>?, [E]> {
        switch data {
        case .groups(let groups):
            return DualHashDictionary(groups.lazy.map { (.some($0), $1) })
        case .entitiesSequence(let entities) where entities.isEmpty == false:
            return DualHashDictionary([(nil, entities.array)])
        case .entitiesArray(let entities) where entities.isEmpty == false:
            return DualHashDictionary([(nil, entities)])
        case .entitiesArray,
             .entitiesSequence:
            return DualHashDictionary()
        }
    }

    // MARK: - O(1) operations

    public var isEmpty: Bool {
        return any.isEmpty
    }

    public var entity: E? {
        return any.first
    }

    public var first: E? {
        return entity
    }

    // MARK: Private RemoteEntity Addition

    fileprivate var _metadata: Metadata<E>?
}

public protocol QueryResultInterface: Equatable {
    associatedtype E: Entity

    @discardableResult
    mutating func materialize() -> QueryResult<E>

    var materialized: QueryResult<E> { get }

    var count: Int { get }

    var any: AnySequence<E> { get }

    var array: [E] { get }

    var groups: DualHashDictionary<EntityIndexValue<E.RelationshipIdentifier, E.Subtype>?, [E]> { get }

    var isEmpty: Bool { get }

    var entity: E? { get }

    var first: E? { get }
}

// MARK: QueryResult + RemoteEntity

public extension QueryResult where E: RemoteEntity {

    var metadata: Metadata<E>? {
        return _metadata
    }
}

// MARK: - Equatable

extension QueryResult {

    public static func == (_ lhs: QueryResult<E>, _ rhs: QueryResult<E>) -> Bool {
        switch (lhs.data, rhs.data) {
        case (.groups(let lhs), .groups(let rhs)):
            return lhs == rhs
        default:
            return lhs.any == rhs.any
        }
    }
}

// MARK: - Sequence

extension QueryResult: Sequence {
    public __consuming func makeIterator() -> AnySequence<E>.Iterator {
        return any.makeIterator()
    }
}

// MARK: - Inits

public extension QueryResult {

    init(data: Data) {
        self.data = data
    }

    init(from entitiesByID: DualHashDictionary<E.Identifier, E>, for query: Query<E>) {
        self.init(from: entitiesByID.values.any, for: query, entitiesByID: entitiesByID)
    }

    init<S>(fromProcessedEntities entities: S, for query: Query<E>) where S: Sequence, S.Element == E {
        self.init(from: entities, for: query, alreadyOrdered: true, alreadyPaginated: true)
    }

    init<S>(from entities: S,
            for query: Query<E>,
            entitiesByID: DualHashDictionary<E.Identifier, E>? = nil,
            alreadyOrdered: Bool = false,
            alreadyPaginated: Bool = false) where S: Sequence, S.Element == E {

        var entities = entities.any

        if query.uniquely {
            var identifiers = DualHashSet<E.Identifier>()
            entities = entities.filter { entity in
                defer { identifiers.insert(entity.identifier) }
                return identifiers.contains(entity.identifier)
            }.any
        }

        if alreadyOrdered == false {
            entities = entities.order(with: query.order, elementsByID: entitiesByID).any
        }

        if alreadyPaginated == false {
            if let offset = query.offset {
                entities = entities.dropFirst(offset)
            }

            if let limit = query.limit {
                entities = entities.prefix(limit)
            }
        }

        if let index = query.groupedBy {
            data = .groups(entities.reduce(into: DualHashDictionary<EntityIndexValue, [E]>()) { groups, entity in
                let indexValue = entity.entityIndexValue(for: index)
                var group = groups[indexValue] ?? []
                group.append(entity)
                groups[indexValue] = group
            })
        } else {
            data = .entitiesSequence(entities)
        }
    }

    init(from entity: E?,
         for query: Query<E> = .all) {
        self.init(from: [entity].compactMap { $0 },
                  for: query)
    }

    init(from entities: [E],
         for query: Query<E>,
         entitiesByID: DualHashDictionary<E.Identifier, E>? = nil,
         alreadyOrdered: Bool = false,
         alreadyPaginated: Bool = false) {

        var entities = entities

        if query.uniquely {
            var identifiers = DualHashSet<E.Identifier>()
            entities = entities.filter { entity in
                defer { identifiers.insert(entity.identifier) }
                return identifiers.contains(entity.identifier)
            }
        }

        if alreadyOrdered == false {
            entities = entities.order(with: query.order, elementsByID: entitiesByID)
        }

        if alreadyPaginated == false {
            if let offset = query.offset {
                entities = Array(entities.dropFirst(offset))
            }

            if let limit = query.limit {
                entities = Array(entities.prefix(limit))
            }
        }

        if let index = query.groupedBy {
            data = .groups(entities.reduce(into: DualHashDictionary<EntityIndexValue, [E]>()) { groups, entity in
                let indexValue = entity.entityIndexValue(for: index)
                var group = groups[indexValue] ?? []
                group.append(entity)
                groups[indexValue] = group
            })
        } else {
            data = .entitiesArray(entities)
        }
    }

    static func empty() -> QueryResult<E> {
        return QueryResult(data: .entitiesArray([]))
    }

    static func entity(_ entity: E?) -> QueryResult<E> {
        return QueryResult(data: .entitiesArray(entity.flatMap { [$0] } ?? []))
    }

    static func entities<S>(_ entities: S) -> QueryResult<E> where S: Sequence, S.Element == E {
        return QueryResult(data: .entitiesSequence(entities.any))
    }

    static func entities(_ entities: [E]) -> QueryResult<E> {
        return QueryResult(data: .entitiesArray(entities))
    }

    static func groups(_ groups: DualHashDictionary<EntityIndexValue<E.RelationshipIdentifier, E.Subtype>, [E]>) -> QueryResult<E> {
        return QueryResult(data: .groups(groups))
    }
}

public extension QueryResult where E: RemoteEntity {

    init(from entity: E?,
         for query: Query<E> = .all,
         metadata: Metadata<E>?) {
        self.init(from: [entity].compactMap { $0 },
                  for: query,
                  metadata: metadata)
    }

    init<S>(fromProcessedEntities entities: S,
            for query: Query<E>,
            metadata: Metadata<E>?) where S: Sequence, S.Element == E {
        self.init(from: entities,
                  for: query,
                  alreadyOrdered: true,
                  alreadyPaginated: true,
                  metadata: metadata)
    }

    init<S>(from entities: S,
            for query: Query<E>,
            entitiesByID: DualHashDictionary<E.Identifier, E>? = nil,
            alreadyOrdered: Bool = false,
            alreadyPaginated: Bool = false,
            metadata: Metadata<E>?) where S: Sequence, S.Element == E {

        self.init(from: entities,
                  for: query,
                  entitiesByID: entitiesByID,
                  alreadyOrdered: alreadyOrdered,
                  alreadyPaginated: alreadyPaginated)

        self._metadata = metadata
    }
}

public extension Sequence where Element: Entity {

    func update(byReplacing newEntities: DualHashDictionary<Element.Identifier, Element>) -> [Element] {
        var mutableEntities = Array(self)
        var index = 0
        for entity in self {
            if let newEntity = newEntities[entity.identifier] {
                mutableEntities[index] = newEntity
            }
            index += 1
        }
        return mutableEntities
    }

    func update(byReplacingOrAdding newEntities: DualHashDictionary<Element.Identifier, Element>) -> [Element] {
        let entitiesByIdentifier = self
            .reduce(into: DualHashDictionary<Element.Identifier, Element>()) { $0[$1.identifier] = $1 }
            .merging(newEntities) { _, newValue in newValue }
        return entitiesByIdentifier.values
    }
}

public extension Query.Filter {

    static var all: Query.Filter? { return nil }

    func extractOrRelationshipIDs<ID: EntityIdentifier>(named relationshipName: E.IndexName) -> AnySequence<ID> {
        switch self {
        case .binary(.property(.index(let indexName)), .equalTo, .value(.index(.relationship(let value)))) where indexName == relationshipName,
             .binary(.value(.index(.relationship(let value))), .equalTo, .property(.index(let indexName))) where indexName == relationshipName:
            return [value.toRelationshipID()].compactMap { $0 }.any

        case .binary(.property(.index(let indexName)), .containedIn, .values(let values)) where indexName == relationshipName,
             .binary(.values(let values), .containedIn, .property(.index(let indexName))) where indexName == relationshipName:
            return values.lazy.compactMap { $0.relationshipIdentifier?.toRelationshipID() }.any

        case .binary(let lhs, .or, let rhs):
            let leftIDs: AnySequence<ID> = lhs.extractOrRelationshipIDs(named: relationshipName)
            let rightIDs: AnySequence<ID> = rhs.extractOrRelationshipIDs(named: relationshipName)
            return [leftIDs, rightIDs].joined().any

        case .negated,
             .binary,
             .property,
             .value,
             .values:
            return .empty
        }
    }

    var extractOrIdentifiers: AnySequence<E.Identifier>? {
        switch self {
        case .binary(.property(.identifier), .equalTo, .value(.identifier(let identifier))),
             .binary(.value(.identifier(let identifier)), .equalTo, .property(.identifier)):
            return [identifier].any

        case .binary(.property(.identifier), .containedIn, .values(let values)),
             .binary(.values(let values), .containedIn, .property(.identifier)):
            let identifiers = values.lazy.compactMap { $0.identifier }
            guard identifiers.isEmpty == false else { return nil }
            return identifiers.any

        case .binary(let lhs, .or, let rhs):
            if let leftValue = lhs.extractOrIdentifiers, let rightValue = rhs.extractOrIdentifiers {
                let identifiers = [leftValue, rightValue].joined()
                guard identifiers.isEmpty == false else { return nil }
                return identifiers.any
            } else {
                return nil
            }

        case .binary,
             .negated,
             .property,
             .value,
             .values:
            return nil
        }
    }
}

extension Query.Order {

    var isNatural: Bool {
        switch self {
        case .natural:
            return true
        case .asc,
             .desc,
             .identifiers:
            return false
        }
    }

    var isDeterministic: Bool {
        switch self {
        case .asc,
             .desc,
             .identifiers:
            return true
        case .natural:
            return false
        }
    }

    var isByIdentifiers: Bool {
        switch self {
        case .identifiers:
            return true
        case .asc,
             .desc,
             .natural:
            return false
        }
    }
}

extension Query.Value {

    var identifier: E.Identifier? {
        switch self {
        case .identifier(let identifier):
            return identifier
        case .bool,
             .index:
            return nil
        }
    }

    var isIdentifier: Bool {
        return identifier != nil
    }

    var relationshipIdentifier: E.RelationshipIdentifier? {
        switch self {
        case .index(.relationship(let identifier)):
            return identifier
        case .bool,
             .identifier,
             .index:
            return nil
        }
    }

    var isRelationshipIdentifier: Bool {
        return relationshipIdentifier != nil
    }

    var boolValue: Bool {
        switch self {
        case .bool(let value):
            return value
        case .identifier,
             .index:
            return true
        }
    }
}

// MARK: - Contract Support

extension QueryResult {

    func validatingContract(_ contract: EntityContract, with query: Query<E>) -> QueryResult {

        guard contract.shouldValidate(E.self) else { return self }

        var queryResult: QueryResult

        switch data {   
        case .groups(var dictionary):
            dictionary.forEach { index, entities in
                dictionary[index] = entities.filter { contract.isEntityValid($0, for: query) }
            }
            queryResult = QueryResult(data: .groups(dictionary))

        case .entitiesSequence(let sequence):
            queryResult = QueryResult(data: .entitiesSequence(sequence.filter { contract.isEntityValid($0, for: query) }.any))

        case .entitiesArray(let entities):
            queryResult = QueryResult(data: .entitiesArray(entities.filter { contract.isEntityValid($0, for: query) }))
        }

        queryResult._metadata = _metadata
        return queryResult
    }
}

// MARK: - Syntactic Sugar

public func == <E: Entity>(lhs: Query<E>.Filter, rhs: Query<E>.Filter) -> Query<E>.Filter {
    return .binary(lhs, .equalTo, rhs)
}

public func == <E: Entity>(lhs: Query<E>.Property, rhs: Query<E>.Value) -> Query<E>.Filter {
    return .property(lhs) == .value(rhs)
}

public func == <E: Entity>(lhs: E.IndexName, rhs: E.RelationshipIdentifier) -> Query<E>.Filter {
    return .index(lhs) == .index(.relationship(rhs))
}

public func == <E: Entity>(lhs: E.IndexName, rhs: E.Subtype) -> Query<E>.Filter {
    return .index(lhs) == .index(.subtype(rhs))
}

public func == <E: Entity>(lhs: E.IndexName, rhs: EntityIndexValue<E.RelationshipIdentifier, E.Subtype>) -> Query<E>.Filter {
    return .index(lhs) == .index(rhs)
}

public func > <E: Entity>(lhs: Query<E>.Filter, rhs: Query<E>.Filter) -> Query<E>.Filter {
    return .binary(lhs, .greaterThan, rhs)
}

public func > <E: Entity>(lhs: Query<E>.Property, rhs: Query<E>.Value) -> Query<E>.Filter {
    return .property(lhs) > .value(rhs)
}

public func > <E: Entity>(lhs: E.IndexName, rhs: E.RelationshipIdentifier) -> Query<E>.Filter {
    return .index(lhs) > .index(.relationship(rhs))
}

public func > <E: Entity>(lhs: E.IndexName, rhs: E.Subtype) -> Query<E>.Filter {
    return .index(lhs) > .index(.subtype(rhs))
}

public func > <E: Entity>(lhs: E.IndexName, rhs: EntityIndexValue<E.RelationshipIdentifier, E.Subtype>) -> Query<E>.Filter {
    return .index(lhs) > .index(rhs)
}

public func >= <E: Entity>(lhs: Query<E>.Filter, rhs: Query<E>.Filter) -> Query<E>.Filter {
    return .binary(lhs, .greaterThanOrEqual, rhs)
}

public func >= <E: Entity>(lhs: Query<E>.Property, rhs: Query<E>.Value) -> Query<E>.Filter {
    return .property(lhs) >= .value(rhs)
}

public func >= <E: Entity>(lhs: E.IndexName, rhs: E.RelationshipIdentifier) -> Query<E>.Filter {
    return .index(lhs) >= .index(.relationship(rhs))
}

public func >= <E: Entity>(lhs: E.IndexName, rhs: E.Subtype) -> Query<E>.Filter {
    return .index(lhs) >= .index(.subtype(rhs))
}

public func >= <E: Entity>(lhs: E.IndexName, rhs: EntityIndexValue<E.RelationshipIdentifier, E.Subtype>) -> Query<E>.Filter {
    return .index(lhs) >= .index(rhs)
}

public func < <E: Entity>(lhs: Query<E>.Filter, rhs: Query<E>.Filter) -> Query<E>.Filter {
    return .binary(lhs, .lessThan, rhs)
}

public func < <E: Entity>(lhs: Query<E>.Property, rhs: Query<E>.Value) -> Query<E>.Filter {
    return .property(lhs) < .value(rhs)
}

public func < <E: Entity>(lhs: E.IndexName, rhs: E.RelationshipIdentifier) -> Query<E>.Filter {
    return .index(lhs) < .index(.relationship(rhs))
}

public func < <E: Entity>(lhs: E.IndexName, rhs: E.Subtype) -> Query<E>.Filter {
    return .index(lhs) < .index(.subtype(rhs))
}

public func < <E: Entity>(lhs: E.IndexName, rhs: EntityIndexValue<E.RelationshipIdentifier, E.Subtype>) -> Query<E>.Filter {
    return .index(lhs) < .index(rhs)
}

public func <= <E: Entity>(lhs: Query<E>.Filter, rhs: Query<E>.Filter) -> Query<E>.Filter {
    return .binary(lhs, .lessThanOrEqual, rhs)
}

public func <= <E: Entity>(lhs: Query<E>.Property, rhs: Query<E>.Value) -> Query<E>.Filter {
    return .property(lhs) <= .value(rhs)
}

public func <= <E: Entity>(lhs: E.IndexName, rhs: E.RelationshipIdentifier) -> Query<E>.Filter {
    return .index(lhs) <= .index(.relationship(rhs))
}

public func <= <E: Entity>(lhs: E.IndexName, rhs: E.Subtype) -> Query<E>.Filter {
    return .index(lhs) <= .index(.subtype(rhs))
}

public func <= <E: Entity>(lhs: E.IndexName, rhs: EntityIndexValue<E.RelationshipIdentifier, E.Subtype>) -> Query<E>.Filter {
    return .index(lhs) <= .index(rhs)
}

public func ~= <E: Entity>(lhs: Query<E>.Filter, rhs: Query<E>.Filter) -> Query<E>.Filter {
    return .binary(lhs, .match, rhs)
}

public func ~= <E: Entity>(lhs: Query<E>.Property, rhs: Query<E>.Value) -> Query<E>.Filter {
    return .property(lhs) ~= .value(rhs)
}

public func ~= <E: Entity>(lhs: E.IndexName, rhs: E.RelationshipIdentifier) -> Query<E>.Filter {
    return .index(lhs) ~= .index(.relationship(rhs))
}

public func ~= <E: Entity>(lhs: E.IndexName, rhs: EntityIndexValue<E.RelationshipIdentifier, E.Subtype>) -> Query<E>.Filter {
    return .index(lhs) ~= .index(rhs)
}

public func >> <S: Sequence, E: Entity>(lhs: Query<E>.Property, rhs: S) -> Query<E>.Filter where S.Element == Query<E>.Value {
    return .binary(.property(lhs), .containedIn, .values(DualHashSet(rhs)))
}

public func >> <S: Sequence, E: Entity>(lhs: Query<E>.Property, rhs: S) -> Query<E>.Filter where S.Element == E.Identifier {
    return .binary(.property(lhs), .containedIn, .values(DualHashSet(rhs.lazy.map { .identifier($0) })))
}

public func >> <S: Sequence, E: Entity>(lhs: E.IndexName, rhs: S) -> Query<E>.Filter where S.Element == Query<E>.Value {
    return .binary(.property(.index(lhs)), .containedIn, .values(DualHashSet(rhs)))
}

public func >> <S: Sequence, E: Entity>(lhs: E.IndexName, rhs: S) -> Query<E>.Filter where S.Element == E.RelationshipIdentifier {
    return .binary(.property(.index(lhs)), .containedIn, .values(DualHashSet(rhs.lazy.map { .index(.relationship($0)) })))
}

public func != <E: Entity>(lhs: Query<E>.Filter, rhs: Query<E>.Filter) -> Query<E>.Filter {
    return .negated(lhs == rhs)
}

public func != <E: Entity>(lhs: Query<E>.Property, rhs: Query<E>.Value) -> Query<E>.Filter {
    return .negated(lhs == rhs)
}

public func != <E: Entity>(lhs: E.IndexName, rhs: E.RelationshipIdentifier) -> Query<E>.Filter {
    return .negated(lhs == rhs)
}

public func != <E: Entity>(lhs: E.IndexName, rhs: EntityIndexValue<E.RelationshipIdentifier, E.Subtype>) -> Query<E>.Filter {
    return .negated(lhs == rhs)
}

public extension Query.Filter {
    static prefix func ! (query: Query<E>.Filter) -> Query<E>.Filter {
        return .negated(query)
    }
}

public func || <E: Entity>(lhs: Query<E>.Filter, rhs: Query<E>.Filter) -> Query<E>.Filter {
    return .binary(lhs, .or, rhs)
}

public func && <E: Entity>(lhs: Query<E>.Filter, rhs: Query<E>.Filter) -> Query<E>.Filter {
    return .binary(lhs, .and, rhs)
}

// MARK: - DualHashable

extension Query.Value {

    public func hash(into hasher: inout DualHasher) {
        switch self {
        case .bool(let value):
            hasher.combine(value)
        case .identifier(let identifier):
            hasher.combine(identifier)
        case .index(let index):
            hasher.combine(index)
        }
    }
}

// MARK: - Comparable

extension Query.Value {

    public static func < (lhs: Query.Value, rhs: Query.Value) -> Bool {
        switch (lhs, rhs) {
        case (.bool(false), .bool(true)):
            return true
        case (.identifier(let lhs), .identifier(let rhs)):
            return lhs < rhs
        case (.index(let lhs), .index(let rhs)):
            return lhs < rhs
        case (.bool, _),
             (.index, _),
             (.identifier, _):
            return false
        }
    }
}
