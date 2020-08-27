//
//  Dictionary+EntityIdentifier.swift
//  Lucid
//
//  Created by Théophane Rupin on 5/1/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

// MARK: - Hasher

/// An object responsible of retrieving an object's dual hash.
///
/// - Note: A dual hash is a hash representation which is composed of 4 different combinations:
///         1. (X, nil)
///         2. (nil, Y)
///         3. (X, Y)
///         4. (nil, nil)
///
///         When used as a hash map key, it makes the combinations 1, 2, 3 point to the same value.
///
///         This comes handy when indexing values based on a key composed of either a remote identifier,
///         a local identifier or both of them.
public struct DualHasher {

    fileprivate struct Key<T>: Hashable where T: DualHashable {
        private let constantHash: Int
        private var firstHash: Int?
        private var secondHash: Int?

        let _key: T

        init(wrapping key: T, constantHash: Int, firstHash: Int?, secondHash: Int?) {
            _key = key
            self.constantHash = constantHash
            self.firstHash = firstHash
            self.secondHash = secondHash
        }
    }

    private var constantHasher = Hasher()
    private var firstHasher: Hasher?
    private var secondHasher: Hasher?

    public mutating func combine<H>(_ constantValue: H) where H: Hashable {
        constantHasher.combine(constantValue)
    }

    public mutating func combine<H>(_ dualValue: H) where H: DualHashable {
        dualValue.hash(into: &self)
    }

    public mutating func combine<H>(firstValue: H) where H: Hashable {
        if firstHasher != nil {
            Logger.log(.error, "\(DualHasher.self): Dual Hash violation. Only one first value can be combined at a time.", assert: true)
        } else {
            firstHasher = Hasher()
            firstHasher?.combine(firstValue)
        }
    }

    public mutating func combine<H>(secondValue: H) where H: Hashable {
        if secondHasher != nil {
            Logger.log(.error, "\(DualHasher.self): Dual Hash violation. Only one second value can be combined at a time.", assert: true)
        } else {
            secondHasher = Hasher()
            secondHasher?.combine(secondValue)
        }
    }

    fileprivate func finalize<T>(with key: T) -> Key<T> where T: DualHashable {
        return Key(wrapping: key,
                   constantHash: constantHasher.finalize(),
                   firstHash: firstHasher?.finalize(),
                   secondHash: secondHasher?.finalize())
    }
}

// MARK: - Hashable

public protocol DualHashable: Equatable {

    func hash(into hasher: inout DualHasher)

    func update(with newValue: Self)
}

extension DualHashable {
    public func update(with newValue: Self) {
        // no-op
    }
}

extension Array: DualHashable where Element: DualHashable {
    public func hash(into hasher: inout DualHasher) {
        forEach { hasher.combine($0) }
    }
}

private extension DualHashable {

    var dualKey: DualHasher.Key<Self> {
        var hasher = DualHasher()
        hash(into: &hasher)
        return hasher.finalize(with: self)
    }
}

// MARK: - Dictionary

/// Dictionary which follows the rules of dual hashing.
///
/// - Note: The underlying dictionary is some kind of double mapping on a value.
///
///         Possible Key Types |                Values
///         ---------------------------------------------------------
///             1. (X, nil)   -->  DoubleRef  --|
///             2. (nil, Y)   -->  DoubleRef  --|-->  Ref  -->  Value
///             3. (X, Y)     -->  DoubleRef  --|
///             4. (nil, nil) -->  DoubleRef  --|
///
///         Because key 1 and 2 can be inferred from 3, there are several rules this
///         hash table needs to follow to work properly.
///
///         *For insertions*:
///         - With a key of type 1, 2 or 4, do a regular insertion.
///         - With a key of type 3, insert the key and its derivated keys 1 and 2.
///
///         *For deletions*:
///         - With a key of type 1, 2, or 4, set the reference's value to nil then remove the key.
///         - With a key of type 3, remove the key with its derivated keys 1 and 2.
///
///         *For updates*:
///         - With a key of type 1, 2, or 4, update the reference's value.
///         - With a key of type 3, reinsert the keys and its derivated keys 1 and 2.
///
public struct DualHashDictionary<Key, Value>: Sequence where Key: DualHashable {

    fileprivate final class Reference: Hashable {
        var value: Value?
        var keys = Set<DualHasher.Key<Key>>()
    }

    fileprivate final class DoubleReference {
        let reference: Reference

        init(_ reference: Reference = Reference()) {
            self.reference = reference
        }
    }

    private var _references: [DualHasher.Key<Key>: DoubleReference]

    public private(set) var count = 0

    public init() {
        _references = [:]
    }

    public init<S>(_ keyValues: S) where S: Sequence, S.Element == (Key, Value) {
        _references = [:]
        for (key, value) in keyValues {
            self[key] = value
        }
    }

    private init(_ references: [DualHasher.Key<Key>: DoubleReference]) {
        _references = references
    }

    public subscript(key: Key) -> Value? {
        get {
            let dualKey = key.dualKey
            if let doubleReference = self.reference(for: dualKey) {
                updateStoredKeys(with: dualKey, doubleReference)
                return doubleReference.reference.value
            } else {
                return nil
            }
        }
        set(newValue) {
            let dualKey = key.dualKey

            let storedReference = reference(for: dualKey)

            if let storedReference = storedReference {
                updateStoredKeys(with: dualKey, storedReference)
            }

            updateCount(with: dualKey, storedReference, newValue)

            if let fullKey = dualKey.fullKey, let firstKey = dualKey.firstKey, let secondKey = dualKey.secondKey {
                if let newValue = newValue {
                    let newDoubleReference = storedReference ?? DoubleReference()
                    newDoubleReference.reference.value = newValue
                    newDoubleReference.reference.keys.insert(firstKey)
                    newDoubleReference.reference.keys.insert(secondKey)
                    newDoubleReference.reference.keys.insert(fullKey)

                    _references[firstKey] = newDoubleReference
                    _references[secondKey] = newDoubleReference
                    _references[fullKey] = newDoubleReference
                } else {
                    _references[firstKey] = nil
                    _references[secondKey] = nil
                    _references[fullKey] = nil
                }
            } else if let key = dualKey.firstKey ?? dualKey.secondKey ?? dualKey.emptyKey {
                if let newValue = newValue {
                    let newDoubleReference = storedReference ?? DoubleReference()
                    newDoubleReference.reference.value = newValue
                    newDoubleReference.reference.keys.insert(key)

                    _references[key] = newDoubleReference
                } else {
                    if let storedReference = storedReference {
                        storedReference.reference.value = nil
                        for key in storedReference.reference.keys {
                            _references[key] = nil
                            storedReference.reference.keys = Set()
                        }
                    }
                    _references[key] = nil
                }
            }
        }
    }

    @inline(__always)
    private func reference(for dualKey: DualHasher.Key<Key>) -> DoubleReference? {
        if let key = dualKey.fullKey, let doubleReference = _references[key] {
            return doubleReference
        } else if let key = dualKey.firstKey, let doubleReference = _references[key] {
            return doubleReference
        } else if let key = dualKey.secondKey, let doubleReference = _references[key] {
            return doubleReference
        } else if let key = dualKey.emptyKey, let doubleReference = _references[key] {
            return doubleReference
        } else {
            return nil
        }
    }

    @inline(__always)
    private func updateStoredKeys(with dualKey: DualHasher.Key<Key>, _ doubleReference: DoubleReference) {
        if dualKey.fullKey != nil {
            for key in doubleReference.reference.keys where key.fullKey == nil {
                key._key.update(with: dualKey._key)
            }
        }
    }

    @inline(__always)
    private mutating func updateCount(with dualKey: DualHasher.Key<Key>, _ doubleReference: DoubleReference?, _ newValue: Value?) {
        switch (newValue, doubleReference?.reference.value) {
        case (.some, .none):
            count += 1
        case (.none, .some):
            count -= 1
        default:
            break
        }

        if let fullKey = dualKey.fullKey, let firstKey = dualKey.firstKey, let secondKey = dualKey.secondKey {
            if _references[firstKey]?.reference.value != nil &&
                _references[secondKey]?.reference.value != nil &&
                _references[fullKey]?.reference == nil {
                count -= 1
            }
        }
    }

    public func makeIterator() -> Array<(Key, Value)>.Iterator {
        return keys.compactMap { key in
            if let value = self[key] {
                return (key, value)
            } else {
                return nil
            }
        }.makeIterator()
    }

    public var values: [Value] {
        return Set(_references.values.lazy.map { $0.reference }).compactMap { $0.value }
    }

    public var keys: [Key] {
        return _references
            .reduce(into: [Reference: DualHasher.Key<Key>]()) { keys, element in
                if keys[element.value.reference] == nil || element.key.fullKey != nil {
                    keys[element.value.reference] = element.key
                }
            }
            .values
            .map { $0._key }
    }

    public var isEmpty: Bool {
        return count == 0
    }

    public func merging(_ other: DualHashDictionary<Key, Value>, uniquingKeysWith combine: (Value, Value) throws -> Value) rethrows -> DualHashDictionary<Key, Value> {
        var values = DualHashDictionary(_references)
        for (otherKey, otherValue) in other {
            if let value = self[otherKey] {
                values[otherKey] = try combine(value, otherValue)
            } else {
                values[otherKey] = otherValue
            }
        }
        return values
    }
}

// MARK: - Set

/// Set implementatino which follows the same rules of Dual Hashing than `DualHashDictionary`
public struct DualHashSet<Element>: Sequence where Element: DualHashable {

    public struct _Iterator: IteratorProtocol {
        private var iterator: DualHashDictionary<Element, Void>.Iterator

        fileprivate init(wrapping iterator: DualHashDictionary<Element, Void>.Iterator) {
            self.iterator = iterator
        }

        public mutating func next() -> Element? {
            return iterator.next()?.0
        }
    }

    private var _values: DualHashDictionary<Element, Void>

    public func makeIterator() -> _Iterator {
        return _Iterator(wrapping: _values.makeIterator())
    }

    public init() {
        _values = DualHashDictionary()
    }

    public init<S>(_ values: S) where S: Sequence, S.Element == Element {
        _values = DualHashDictionary(values.map { ($0, ()) })
    }

    public mutating func insert(_ element: Element) {
        _values[element] = ()
    }

    public var count: Int {
        return _values.count
    }

    public var isEmpty: Bool {
        return count == 0
    }

    public mutating func subtract(_ other: DualHashSet<Element>) {
        for (key, _) in other._values {
            _values[key] = nil
        }
    }

    public mutating func intersection(_ other: DualHashSet<Element>) {
        for (key, _) in _values {
            _values[key] = other._values[key]
        }
    }

    public func contains(_ element: Element) -> Bool {
        return _values[element] != nil
    }
}

// MARK: - OrderedDictionary

/// Dictionary which keeps track of the order in which keys have been inserted.
///
/// - Note:
///     If the same key is set twice it is inserted back into the list of ordered keys.
///
///     E.g.
///     ```
///     let dictionary = OrderedDictionary<String, Int>()
///     dictionary["foo"] = 42
///     dictionary["bar"] = 24
///     dictionary["foo"] = 43
///     print(dictionary.orderedValues)
///     ```
///     Prints:
///     ```
///     $ 24, 43
///     ```
public struct OrderedDictionary<Key, Value>: Sequence where Key: Hashable {

    public private(set) var dictionary = [Key: Value]()

    public private(set) var orderedKeys = [Key]()

    public init() {
        // no-op
    }

    public init<S>(_ keyValues: S) where S: Sequence, S.Element == (Key, Value) {
        keyValues.reversed().forEach { key, value in
            guard dictionary[key] == nil else { return }
            dictionary[key] = value
            orderedKeys = [key] + orderedKeys
        }
    }

    public init(_ dictionary: [Key: Value], sortBy areInIncreasingOrder: (Key, Key) -> Bool) {
        self.init(dictionary.keys.sorted(by: areInIncreasingOrder).lazy.compactMap { key -> (Key, Value)? in
            guard let value = dictionary[key] else { return nil }
            return (key, value)
        })
    }

    public subscript(key: Key) -> Value? {
        get {
            return dictionary[key]
        }
        set {
            add(key: key, value: newValue, append: true)
        }
    }

    public func makeIterator() -> Array<(Key, Value)>.Iterator {
        return orderedKeyValues.makeIterator()
    }

    public var orderedKeyValues: [(Key, Value)] {
        return orderedKeys.compactMap { key in
            dictionary[key].flatMap { (key, $0) }
        }
    }

    public var orderedValues: [Value] {
        return orderedKeys.compactMap { dictionary[$0] }
    }

    public var isEmpty: Bool {
        return dictionary.isEmpty
    }

    public var count: Int {
        return dictionary.count
    }

    public func contains(_ key: Key) -> Bool {
        return dictionary[key] != nil
    }

    public mutating func append(key: Key, value: Value) {
        add(key: key, value: value, append: true)
    }

    public mutating func prepend(key: Key, value: Value) {
        add(key: key, value: value, append: false)
    }

    public mutating func popFirst() ->  (key: Key, value: Value)? {
        guard orderedKeys.isEmpty == false else { return nil }
        let key = orderedKeys.removeFirst()
        guard let value = dictionary[key] else { return nil }
        dictionary[key] = nil
        return (key, value)
    }

    public mutating func popLast() ->  (key: Key, value: Value)? {
        guard orderedKeys.isEmpty == false else { return nil }
        let key = orderedKeys.removeLast()
        guard let value = dictionary[key] else { return nil }
        dictionary[key] = nil
        return (key, value)
    }

    public mutating func replace(key: Key, value: Value) {
        guard dictionary[key] != nil else {
            append(key: key, value: value)
            return
        }

        dictionary[key] = value
    }

    private mutating func add(key: Key, value: Value?, append: Bool) {
        if dictionary[key] == nil && value != nil {
            if append {
                orderedKeys += [key]
            } else {
                orderedKeys = [key] + orderedKeys
            }
        } else {
            orderedKeys.firstIndex(of: key).flatMap { index -> Void in
                orderedKeys.remove(at: index)
            }
            if value != nil {
                if append {
                    orderedKeys += [key]
                } else {
                    orderedKeys = [key] + orderedKeys
                }
            }
        }
        dictionary[key] = value
    }
}

// MARK: - OrderedSet

/// Set which keeps track of the order in which elements have been inserted.
///
/// - Note:
///     If the same element is added twice it is reinserted at the specified position.
///
///     E.g.
///     ```
///     let set = OrderedSet<Int>()
///
///     set.append(1)
///     set.append(2)
///     set.append(1)
///     print(set.array)
///     ```
///     Prints:
///     ```
///     $ [2, 1]
///     ```
public struct OrderedSet<Element>: Sequence where Element: Hashable {

    private var data = OrderedDictionary<Element, Void>()

    public init() {
        // no-op
    }

    public init<S>(_ values: S) where S: Sequence, S.Element == Element {
        values.forEach { value in
            data.append(key: value, value: ())
        }
    }

    public init(_ set: Set<Element>, sortBy areInIncreasingOrder: (Element, Element) -> Bool) {
        self.init(set.array.sorted(by: areInIncreasingOrder))
    }

    public func makeIterator() -> Array<Element>.Iterator {
        return array.makeIterator()
    }

    public mutating func append(_ element: Element) {
        data.append(key: element, value: ())
    }

    public mutating func prepend(_ element: Element) {
        data.prepend(key: element, value: ())
    }

    public mutating func popFirst() -> Element? {
        return data.popFirst()?.key
    }

    public mutating func popLast() -> Element? {
        return data.popLast()?.key
    }

    @discardableResult
    public mutating func remove(at index: Int) -> Element {
        let member = data.orderedKeys[index]
        defer { data[member] = nil }
        return member
    }

    @discardableResult
    public mutating func remove(_ member: Element) -> Element? {
        defer { data[member] = nil }
        return data[member] != nil ? member : nil
    }

    public var array: [Element] {
        return data.orderedKeys
    }

    public var count: Int {
        return data.count
    }

    public var isEmpty: Bool {
        return data.isEmpty
    }
}

/// Dual Hash Dictionary which keeps track of the order in which keys have been inserted.
///
/// - Note:
///     If the same key is set twice it is inserted back into the list of ordered keys.
///
///     E.g.
///     ```
///     let dictionary = OrderedDictionary<String, Int>()
///     dictionary["foo"] = 42
///     dictionary["bar"] = 24
///     dictionary["foo"] = 43
///     print(dictionary.orderedValues)
///     ```
///     Prints:
///     ```
///     $ 24, 43
///     ```
public struct OrderedDualHashDictionary<Key, Value>: Sequence where Key: DualHashable {

    public private(set) var dictionary = DualHashDictionary<Key, Value>()

    public private(set) var orderedKeys = [Key]()

    public init() {
        // no-op
    }

    public init<S>(_ keyValues: S) where S: Sequence, S.Element == (Key, Value) {
        keyValues.reversed().forEach { key, value in
            guard dictionary[key] == nil else { return }
            dictionary[key] = value
            orderedKeys = [key] + orderedKeys
        }
    }

    public init(_ dictionary: DualHashDictionary<Key, Value>, sortBy areInIncreasingOrder: (Key, Key) -> Bool) {
        self.init(dictionary.keys.sorted(by: areInIncreasingOrder).lazy.compactMap { key -> (Key, Value)? in
            guard let value = dictionary[key] else { return nil }
            return (key, value)
        })
    }

    public subscript(key: Key) -> Value? {
        get {
            return dictionary[key]
        }
        set {
            if dictionary[key] == nil && newValue != nil {
                orderedKeys.append(key)
            } else {
                orderedKeys.firstIndex(of: key).flatMap { index -> Void in
                    orderedKeys.remove(at: index)
                }
                if newValue != nil {
                    orderedKeys.append(key)
                }
            }
            dictionary[key] = newValue
        }
    }

    public func makeIterator() -> Array<(Key, Value)>.Iterator {
        return orderedKeyValues.makeIterator()
    }

    public var orderedKeyValues: [(Key, Value)] {
        return orderedKeys.compactMap { key in
            dictionary[key].flatMap { (key, $0) }
        }
    }

    public var isEmpty: Bool {
        return dictionary.isEmpty
    }

    public var count: Int {
        return dictionary.count
    }
}

// MARK: - Utils

private extension DualHasher.Key {

    var firstKey: DualHasher.Key<T>? {
        guard firstHash != nil else { return nil }
        var key = self
        key.secondHash = nil
        return key
    }

    var secondKey: DualHasher.Key<T>? {
        guard secondHash != nil else { return nil }
        var key = self
        key.firstHash = nil
        return key
    }

    var fullKey: DualHasher.Key<T>? {
        guard firstHash != nil && secondHash != nil else { return nil }
        return self
    }

    var emptyKey: DualHasher.Key<T>? {
        guard firstHash == nil && secondHash == nil else { return nil }
        return self
    }
}

// MARK: - Hashable

extension DualHasher.Key {

    func hash(into hasher: inout Hasher) {
        hasher.combine(constantHash)
        if let firstHash = firstHash {
            hasher.combine(firstHash)
        }
        if let secondHash = secondHash {
            hasher.combine(secondHash)
        }
    }

    static func == (_ lhs: DualHasher.Key<T>, _ rhs: DualHasher.Key<T>) -> Bool {
        guard lhs._key == rhs._key else { return false }
        guard lhs.firstHash == rhs.firstHash else { return false }
        guard lhs.secondHash == rhs.secondHash else { return false }
        guard lhs.constantHash == rhs.constantHash else { return false }
        return true
    }
}

extension DualHashDictionary.Reference {

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension OrderedDictionary: Hashable where Value: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(orderedKeyValues.lazy.map { $0.1 })
        hasher.combine(orderedKeys)
    }
}

// MARK: - Equatable

extension DualHashDictionary: Equatable where Key: Equatable, Value: Equatable {

    public static func == (_ lhs: DualHashDictionary<Key, Value>, _ rhs: DualHashDictionary<Key, Value>) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for key in lhs.keys where rhs[key] != lhs[key] {
            return false
        }
        for key in rhs.keys where lhs[key] != rhs[key] {
            return false
        }
        return true

    }
}

extension OrderedDualHashDictionary: Equatable where Key: Equatable, Value: Equatable {

    public static func == (_ lhs: OrderedDualHashDictionary<Key, Value>, _ rhs: OrderedDualHashDictionary<Key, Value>) -> Bool {
        guard lhs.orderedKeys == rhs.orderedKeys else { return false }
        guard lhs.orderedKeyValues.lazy.map({ $0.1 }) == rhs.orderedKeyValues.lazy.map({ $0.1 }) else { return false }
        return true
    }
}

extension DualHashSet: Equatable {

    public static func == (_ lhs: DualHashSet<Element>, _ rhs: DualHashSet<Element>) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for element in lhs where rhs.contains(element) == false {
            return false
        }
        for element in rhs where lhs.contains(element) == false {
            return false
        }
        return true
    }
}

extension DualHashDictionary.DoubleReference: Equatable where Value: Equatable {

    static func == (_ lhs: DualHashDictionary<Key, Value>.DoubleReference, _ rhs: DualHashDictionary<Key, Value>.DoubleReference) -> Bool {
        return lhs.reference == rhs.reference
    }
}

extension DualHashDictionary.Reference {

    static func == (_ lhs: DualHashDictionary<Key, Value>.Reference, _ rhs: DualHashDictionary<Key, Value>.Reference) -> Bool {
        return lhs === rhs
    }
}

extension OrderedDictionary: Equatable where Value: Equatable {

    public static func == (_ lhs: OrderedDictionary, _ rhs: OrderedDictionary) -> Bool {
        guard lhs.orderedKeys == rhs.orderedKeys else { return false }
        guard lhs.orderedKeyValues.lazy.map({ $0.1 }) == rhs.orderedKeyValues.lazy.map({ $0.1 }) else { return false }
        return true
    }
}

// MARK: - DualHashable

extension Optional: DualHashable where Wrapped: DualHashable {

    public func hash(into hasher: inout DualHasher) {
        switch self {
        case .some(let value):
            hasher.combine(value)
        case .none:
            hasher.combine("none")
        }
    }
}

// MARK: - Decodable

extension OrderedDictionary: Decodable where Key: Decodable, Value: Decodable {}

extension OrderedSet: Decodable where Element: Decodable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Retro compatibility with previous implementations
        if let keys = try? container.decode([Element].self) {
            data = OrderedDictionary(keys.lazy.map { ($0, ()) })
        } else {
            data = OrderedDictionary(
                try container
                    .decode(OrderedDictionary<Element, Element>.self)
                    .map { key, _ in (key, ()) }
            )
        }
    }
}

// MARK: - Encodable

extension OrderedDictionary: Encodable where Key: Encodable, Value: Encodable {}

extension OrderedSet: Encodable where Element: Encodable {

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data.orderedKeys)
    }
}

// MARK: - Sort

extension OrderedDictionary where Key: Comparable {

    public func sorted() -> OrderedDictionary {
        var result = self
        result.orderedKeys = result.orderedKeys.sorted()
        return result
    }

    public init(_ dictionary: [Key: Value]) {
        self.init(dictionary, sortBy: <)
    }
}

extension OrderedSet where Element: Comparable {

    public func sorted() -> OrderedSet {
        return OrderedSet(data.orderedKeys.sorted())
    }
}
