//
//  DataStructuresTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 5/3/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import XCTest
@testable import Lucid
@testable import LucidTestKit

// MARK: - Dictionary

final class DualHashDictionaryTests: XCTestCase {

    private var dictionary: DualHashDictionary<IdentifierValueType<String, Int>, Int>!

    override func setUp() {
        super.setUp()
        dictionary = DualHashDictionary()
    }

    override func tearDown() {
        defer { super.tearDown() }
        dictionary = nil
    }

    func test_dictionary_should_set_a_value_with_a_local_identifier_and_retrieve_it_with_a_local_identifier() {
        dictionary[.local("0")] = 42
        XCTAssertEqual(dictionary[.local("0")], 42)
    }

    func test_dictionary_should_set_a_value_with_a_local_identifier_and_retrieve_it_with_a_remote_and_local_identifier() {
        dictionary[.local("0")] = 42
        XCTAssertEqual(dictionary[.remote(0, "0")], 42)
    }

    func test_dictionary_should_set_a_value_with_a_local_identifier_and_not_retrieve_it_with_a_remote_identifier() {
        dictionary[.local("0")] = 42
        XCTAssertNil(dictionary[.remote(0, nil)])
    }

    func test_dictionary_should_set_a_value_with_a_remote_identifier_and_retrieve_it_with_a_remote_identifier() {
        dictionary[.remote(0, nil)] = 42
        XCTAssertEqual(dictionary[.remote(0, nil)], 42)
    }

    func test_dictionary_should_set_a_value_with_a_remote_identifier_and_retrieve_it_with_a_remote_and_local_identifier() {
        dictionary[.remote(0, nil)] = 42
        XCTAssertEqual(dictionary[.remote(0, "0")], 42)
    }

    func test_dictionary_should_set_a_value_with_a_remote_identifier_and_not_retrieve_it_with_a_local_identifier() {
        dictionary[.remote(0, nil)] = 42
        XCTAssertNil(dictionary[.local("0")])
    }

    func test_dictionary_should_set_a_value_with_a_remote_and_local_identifier_and_retrieve_it_with_a_local_identifier() {
        dictionary[.remote(0, "0")] = 42
        XCTAssertEqual(dictionary[.local("0")], 42)
    }

    func test_dictionary_should_set_a_value_with_a_remote_and_local_identifier_and_retrieve_it_with_a_remote_identifier() {
        dictionary[.remote(0, "0")] = 42
        XCTAssertEqual(dictionary[.remote(0, nil)], 42)
    }

    func test_dictionary_should_set_a_value_with_a_remote_and_local_identifier_and_retrieve_it_with_a_remote_and_local_identifier() {
        dictionary[.remote(0, "0")] = 42
        XCTAssertEqual(dictionary[.remote(0, "0")], 42)
    }

    func test_dictionary_should_set_with_two_unrelated_identifiers_and_retrieve_two_different_values() {
        dictionary[.remote(0, nil)] = 42
        dictionary[.local("0")] = 24
        XCTAssertEqual(dictionary[.remote(0, nil)], 42)
        XCTAssertEqual(dictionary[.local("0")], 24)
        XCTAssertEqual(dictionary.count, 2)
        XCTAssertEqual(dictionary.values.count, 2)
    }

    func test_dictionary_should_set_with_two_unrelated_identifiers_and_retrieve_the_local_value_with_a_remote_and_local_identifier() {
        dictionary[.remote(0, nil)] = 42
        dictionary[.local("0")] = 24
        XCTAssertEqual(dictionary[.remote(0, "0")], 24)
        XCTAssertEqual(dictionary.count, 2)
        XCTAssertEqual(dictionary.values.count, 2)
    }

    func test_dictionary_should_set_with_two_unrelated_identifiers_and_retrieve_the_local_value_prior_to_the_remote_value() {
        dictionary[.remote(0, nil)] = 42
        dictionary[.local("0")] = 24
        XCTAssertEqual(dictionary[.remote(0, "0")], 24)
        XCTAssertEqual(dictionary[.remote(0, nil)], 42)
        XCTAssertEqual(dictionary[.local("0")], 24)
        XCTAssertEqual(dictionary.count, 2)
        XCTAssertEqual(dictionary.values.count, 2)
    }

    func test_dictionary_should_set_a_value_with_a_remote_identifier_and_update_it_with_a_remote_and_local_identifier() {
        dictionary[.remote(0, nil)] = 42
        dictionary[.remote(0, "0")] = 24
        XCTAssertEqual(dictionary[.remote(0, nil)], 24)
        XCTAssertEqual(dictionary[.remote(0, "0")], 24)
        XCTAssertEqual(dictionary[.local("0")], 24)
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary.values.count, 1)
    }

    func test_dictionary_should_set_a_value_with_a_local_identifier_and_update_it_with_a_remote_and_local_identifier() {
        dictionary[.local("0")] = 42
        dictionary[.remote(0, "0")] = 24
        XCTAssertEqual(dictionary[.local("0")], 24)
        XCTAssertEqual(dictionary[.remote(0, "0")], 24)
        XCTAssertEqual(dictionary[.local("0")], 24)
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary.values.count, 1)
    }

    func test_dictionary_should_set_a_value_with_a_remote_and_local_identifier_and_update_it_with_a_local_identifier() {
        dictionary[.remote(0, "0")] = 42
        dictionary[.local("0")] = 24
        XCTAssertEqual(dictionary[.local("0")], 24)
        XCTAssertEqual(dictionary[.remote(0, "0")], 24)
        XCTAssertEqual(dictionary[.local("0")], 24)
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary.values.count, 1)
    }

    func test_dictionary_should_set_a_value_with_a_remote_and_local_identifier_and_update_it_with_a_remote_identifier() {
        dictionary[.remote(0, "0")] = 42
        dictionary[.remote(0, nil)] = 24
        XCTAssertEqual(dictionary[.local("0")], 24)
        XCTAssertEqual(dictionary[.remote(0, "0")], 24)
        XCTAssertEqual(dictionary[.local("0")], 24)
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary.values.count, 1)
    }

    func test_dictionary_should_set_a_value_with_a_remote_and_local_identifier_and_update_it_with_a_local_and_remote_identifier() {
        dictionary[.remote(0, "0")] = 42
        dictionary[.remote(0, "0")] = 24
        XCTAssertEqual(dictionary[.local("0")], 24)
        XCTAssertEqual(dictionary[.remote(0, "0")], 24)
        XCTAssertEqual(dictionary[.local("0")], 24)
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary.values.count, 1)
    }

    func test_dictionary_should_set_with_two_unrelated_identifiers_and_update_it_with_a_local_and_remote_identifier() {
        dictionary[.remote(0, nil)] = 42
        dictionary[.local("0")] = 24
        dictionary[.remote(0, "0")] = 36
        XCTAssertEqual(dictionary[.local("0")], 36)
        XCTAssertEqual(dictionary[.remote(0, "0")], 36)
        XCTAssertEqual(dictionary[.local("0")], 36)
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary.values.count, 1)
    }

    func test_dictionary_should_set_a_value_with_a_local_identifier_and_remove_it_with_a_local_and_remote_identifier() {
        dictionary[.local("0")] = 42
        dictionary[.remote(0, "0")] = nil
        XCTAssertNil(dictionary[.local("0")])
        XCTAssertNil(dictionary[.remote(0, "0")])
        XCTAssertNil(dictionary[.remote(0, nil)])
        XCTAssertEqual(dictionary.count, 0)
        XCTAssertEqual(dictionary.values.count, 0)
    }

    func test_dictionary_should_set_a_value_with_a_remote_identifier_and_remove_it_with_a_local_and_remote_identifier() {
        dictionary[.remote(0, nil)] = 42
        dictionary[.remote(0, "0")] = nil
        XCTAssertNil(dictionary[.local("0")])
        XCTAssertNil(dictionary[.remote(0, "0")])
        XCTAssertNil(dictionary[.remote(0, nil)])
        XCTAssertEqual(dictionary.count, 0)
        XCTAssertEqual(dictionary.values.count, 0)
    }

    func test_dictionary_should_set_a_value_with_a_local_and_remote_identifier_and_remove_it_with_a_remote_identifier() {
        dictionary[.remote(0, "0")] = 42
        dictionary[.remote(0, nil)] = nil
        XCTAssertNil(dictionary[.local("0")])
        XCTAssertNil(dictionary[.remote(0, "0")])
        XCTAssertNil(dictionary[.remote(0, nil)])
        XCTAssertEqual(dictionary.count, 0)
        XCTAssertEqual(dictionary.values.count, 0)
    }

    func test_dictionary_should_set_a_value_with_a_local_and_remote_identifier_and_remove_it_with_a_local_identifier() {
        dictionary[.remote(0, "0")] = 42
        dictionary[.local("0")] = nil
        XCTAssertNil(dictionary[.local("0")])
        XCTAssertNil(dictionary[.remote(0, "0")])
        XCTAssertNil(dictionary[.remote(0, nil)])
        XCTAssertEqual(dictionary.count, 0)
        XCTAssertEqual(dictionary.values.count, 0)
    }

    func test_dictionary_should_set_a_value_with_a_local_and_remote_identifier_and_remove_it_with_a_local_and_remote_identifier() {
        dictionary[.remote(0, "0")] = 42
        dictionary[.remote(0, "0")] = nil
        XCTAssertNil(dictionary[.local("0")])
        XCTAssertNil(dictionary[.remote(0, "0")])
        XCTAssertNil(dictionary[.remote(0, nil)])
        XCTAssertEqual(dictionary.count, 0)
        XCTAssertEqual(dictionary.values.count, 0)
    }

    func test_dictionary_should_set_with_two_unrelated_identifiers_and_remove_it_with_a_local_and_remote_identifier() {
        dictionary[.remote(0, nil)] = 42
        dictionary[.local("0")] = 24
        dictionary[.remote(0, "0")] = nil
        XCTAssertNil(dictionary[.local("0")])
        XCTAssertNil(dictionary[.remote(0, "0")])
        XCTAssertNil(dictionary[.remote(0, nil)])
        XCTAssertEqual(dictionary.count, 0)
        XCTAssertEqual(dictionary.values.count, 0)
    }

    func test_dictionary_should_count_one_element_after_complex_series_of_writes() {
        dictionary[.remote(0, nil)] = 42
        dictionary[.local("0")] = 24
        dictionary[.remote(0, "0")] = 31
        dictionary[.remote(0, nil)] = nil
        dictionary[.remote(1, nil)] = 12
        dictionary[.local("1")] = 21
        dictionary[.remote(0, "1")] = 2
        dictionary[.remote(0, nil)] = nil
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary.values.count, 1)
    }

    func test_dictionary_key_with_no_dual_hash_should_not_overlap_with_other_keys() {
        var dictionary = DualHashDictionary<Query<EntitySpy>.Value, Int>()
        dictionary[.bool(true)] = 42
        dictionary[.identifier(EntitySpyIdentifier(value: .remote(0, "0")))] = 24
        dictionary[.index(.none)] = 36
        XCTAssertEqual(dictionary[.bool(true)], 42)
        XCTAssertEqual(dictionary[.identifier(EntitySpyIdentifier(value: .remote(0, "0")))], 24)
        XCTAssertEqual(dictionary[.index(.none)], 36)
        XCTAssertEqual(dictionary.count, 3)
        XCTAssertEqual(dictionary.values.count, 3)
    }

    func test_dictionary_key_values_should_be_unique_and_take_a_full_key_in_case_of_conflict() {
        dictionary[.remote(0, nil)] = 42
        dictionary[.local("0")] = 42
        dictionary[.remote(0, "0")] = 42
        XCTAssertEqual(dictionary.keys.first, .remote(0, nil))
        XCTAssertEqual(dictionary.values.first, 42)
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary.values.count, 1)
    }

    func test_identifier_should_update_its_internal_value_with_a_full_key_as_soon_as_available_when_getting() {
        var dictionary = DualHashDictionary<EntitySpyIdentifier, Int>()
        let identifier = EntitySpyIdentifier(value: .remote(0, nil))
        dictionary[identifier] = 42
        _ = dictionary[EntitySpyIdentifier(value: .remote(0, "0"))]
        XCTAssertEqual(identifier.value.remoteValue, 0)
        XCTAssertEqual(identifier.value.localValue, "0")
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary.values.count, 1)
    }

    func test_identifier_should_update_its_internal_value_with_a_full_key_as_soon_as_available_when_setting() {
        var dictionary = DualHashDictionary<EntitySpyIdentifier, Int>()
        let identifier = EntitySpyIdentifier(value: .remote(0, nil))
        dictionary[identifier] = 42
        dictionary[EntitySpyIdentifier(value: .remote(0, "0"))] = 42
        XCTAssertEqual(identifier.value.remoteValue, 0)
        XCTAssertEqual(identifier.value.localValue, "0")
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary.values.count, 1)
    }

    func test_identifier_should_only_update_its_internal_value_with_a_full_key_as_soon_as_available_when_setting() {
        var dictionary = DualHashDictionary<EntitySpyIdentifier, Int>()
        let identifier = EntitySpyIdentifier(value: .remote(0, nil))
        let otherIdentifier = EntitySpyIdentifier(value: .remote(1, nil))
        dictionary[identifier] = 42
        dictionary[otherIdentifier] = 24
        dictionary[EntitySpyIdentifier(value: .remote(0, "0"))] = 42
        XCTAssertEqual(identifier.value.remoteValue, 0)
        XCTAssertEqual(identifier.value.localValue, "0")
        XCTAssertEqual(otherIdentifier.value.remoteValue, 1)
        XCTAssertNil(otherIdentifier.value.localValue)
        XCTAssertEqual(dictionary.count, 2)
        XCTAssertEqual(dictionary.values.count, 2)
    }

    func test_two_dictionaries_with_the_same_key_values_should_be_equal() {
        dictionary[.remote(0, "0")] = 0
        dictionary[.remote(1, "1")] = 1
        var otherDictionary = DualHashDictionary<IdentifierValueType<String, Int>, Int>()
        otherDictionary[.remote(0, "0")] = 0
        otherDictionary[.remote(1, "1")] = 1
        XCTAssertEqual(dictionary, otherDictionary)
    }

    func test_two_dictionaries_with_matching_keys_and_same_values_should_be_equal() {
        dictionary[.remote(0, nil)] = 0
        dictionary[.local("0")] = 0
        dictionary[.remote(0, "0")] = 0
        var otherDictionary = DualHashDictionary<IdentifierValueType<String, Int>, Int>()
        otherDictionary[.remote(0, nil)] = 0
        XCTAssertEqual(dictionary, otherDictionary)
    }

    func test_two_dictionaries_with_different_keys_same_values_should_not_be_equal() {
        dictionary[.remote(0, "0")] = 0
        dictionary[.remote(2, "1")] = 1
        var otherDictionary = DualHashDictionary<IdentifierValueType<String, Int>, Int>()
        otherDictionary[.remote(0, "0")] = 0
        otherDictionary[.remote(1, "1")] = 1
        XCTAssertNotEqual(dictionary, otherDictionary)
    }

    func test_two_dictionaries_with_matching_keys_and_not_the_same_values_should_not_be_equal() {
        dictionary[.remote(0, nil)] = 0
        dictionary[.local("0")] = 0
        dictionary[.remote(0, "0")] = 0
        var otherDictionary = DualHashDictionary<IdentifierValueType<String, Int>, Int>()
        otherDictionary[.remote(0, nil)] = 1
        XCTAssertNotEqual(dictionary, otherDictionary)
    }
}

// MARK: - Ordered Dictionaries

final class OrderedDualHashDictionaryTests: XCTestCase {

    private var dictionary: OrderedDualHashDictionary<IdentifierValueType<String, Int>, Int>!

    override func setUp() {
        super.setUp()
        dictionary = OrderedDualHashDictionary()
    }

    override func tearDown() {
        defer { super.tearDown() }
        dictionary = nil
    }

    func test_should_add_elements_and_retrieve_them_in_order_of_insertion() {
        dictionary[.remote(0, nil)] = 0
        dictionary[.remote(1, nil)] = 1
        dictionary[.remote(2, nil)] = 2
        dictionary[.remote(3, nil)] = 3
        XCTAssertEqual(dictionary.orderedKeys, [.remote(0, nil), .remote(1, nil), .remote(2, nil), .remote(3, nil)])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [0, 1, 2, 3])
    }

    func test_should_add_an_element_twice_and_retrieve_it_once_in_order_of_insertion() {
        dictionary[.remote(0, nil)] = 0
        dictionary[.remote(1, nil)] = 1
        dictionary[.remote(2, nil)] = 2
        dictionary[.remote(0, nil)] = 3
        XCTAssertEqual(dictionary.orderedKeys, [.remote(1, nil), .remote(2, nil), .remote(0, nil)])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [1, 2, 3])
    }

    func test_should_add_an_element_twice_and_count_a_correct_amount_of_elements() {
        dictionary[.remote(0, nil)] = 0
        dictionary[.remote(1, nil)] = 1
        dictionary[.remote(2, nil)] = 2
        dictionary[.remote(0, nil)] = 3
        XCTAssertEqual(dictionary.count, 3)
    }

    func test_should_initialize_from_key_values_and_retrieve_elements_in_order_of_insertion() {
        dictionary = OrderedDualHashDictionary([
            (.remote(0, nil), 0),
            (.remote(1, nil), 1),
            (.remote(2, nil), 2),
            (.remote(0, nil), 3)
        ])
        XCTAssertEqual(dictionary.orderedKeys, [.remote(1, nil), .remote(2, nil), .remote(0, nil)])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [1, 2, 3])
    }

    func test_should_delete_value_and_remove_key_from_ordered_list_when_setting_value_to_nil() {
        dictionary = OrderedDualHashDictionary([
            (.remote(0, nil), 0),
            (.remote(1, nil), 1),
            (.remote(2, nil), 2),
            (.remote(0, nil), 3)
        ])

        dictionary[.remote(1, nil)] = nil

        XCTAssertEqual(dictionary.orderedKeys, [.remote(2, nil), .remote(0, nil)])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [2, 3])
    }
}

final class OptimizedWriteOperationOrderedDualHashDictionaryTests: XCTestCase {

    private var dictionary: OrderedDualHashDictionary<IdentifierValueType<String, Int>, Int>!

    override func setUp() {
        super.setUp()
        dictionary = OrderedDualHashDictionary(optimizeWriteOperation: true)
    }

    override func tearDown() {
        defer { super.tearDown() }
        dictionary = nil
    }

    func test_should_add_elements_and_retrieve_them_in_order_of_insertion() {
        dictionary[.remote(0, nil)] = 0
        dictionary[.remote(1, nil)] = 1
        dictionary[.remote(2, nil)] = 2
        dictionary[.remote(3, nil)] = 3
        XCTAssertEqual(dictionary.orderedKeys, [.remote(0, nil), .remote(1, nil), .remote(2, nil), .remote(3, nil)])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [0, 1, 2, 3])
    }

    func test_should_add_an_element_twice_and_retrieve_it_once_in_order_of_insertion() {
        dictionary[.remote(0, nil)] = 0
        dictionary[.remote(1, nil)] = 1
        dictionary[.remote(2, nil)] = 2
        dictionary[.remote(0, nil)] = 3
        XCTAssertEqual(dictionary.orderedKeys, [.remote(1, nil), .remote(2, nil), .remote(0, nil)])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [1, 2, 3])
    }

    func test_should_add_an_element_twice_and_count_a_correct_amount_of_elements() {
        dictionary[.remote(0, nil)] = 0
        dictionary[.remote(1, nil)] = 1
        dictionary[.remote(2, nil)] = 2
        dictionary[.remote(0, nil)] = 3
        XCTAssertEqual(dictionary.count, 3)
    }

    func test_should_initialize_from_key_values_and_retrieve_elements_in_order_of_insertion() {
        dictionary = OrderedDualHashDictionary([
            (.remote(0, nil), 0),
            (.remote(1, nil), 1),
            (.remote(2, nil), 2),
            (.remote(0, nil), 3)
        ], optimizeWriteOperation: true)
        XCTAssertEqual(dictionary.orderedKeys, [.remote(1, nil), .remote(2, nil), .remote(0, nil)])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [1, 2, 3])
    }

    func test_should_delete_value_and_remove_key_from_ordered_list_when_setting_value_to_nil() {
        dictionary = OrderedDualHashDictionary([
            (.remote(0, nil), 0),
            (.remote(1, nil), 1),
            (.remote(2, nil), 2),
            (.remote(0, nil), 3)
        ], optimizeWriteOperation: true)

        dictionary[.remote(1, nil)] = nil

        XCTAssertEqual(dictionary.orderedKeys, [.remote(2, nil), .remote(0, nil)])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [2, 3])
    }
}

final class OrderedDictionaryTests: XCTestCase {

    private var dictionary: OrderedDictionary<String, Int>!

    override func setUp() {
        super.setUp()
        dictionary = OrderedDictionary()
    }

    override func tearDown() {
        defer { super.tearDown() }
        dictionary = nil
    }

    func test_should_add_elements_and_retrieve_them_in_order_of_insertion() {
        dictionary["0"] = 0
        dictionary["1"] = 1
        dictionary["2"] = 2
        dictionary["3"] = 3
        XCTAssertEqual(dictionary.orderedKeys, ["0", "1", "2", "3"])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [0, 1, 2, 3])
    }

    func test_should_add_an_element_twice_and_retrieve_it_once_in_order_of_insertion() {
        dictionary["0"] = 0
        dictionary["1"] = 1
        dictionary["2"] = 2
        dictionary["0"] = 3
        XCTAssertEqual(dictionary.orderedKeys, ["1", "2", "0"])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [1, 2, 3])
    }

    func test_should_add_an_element_twice_and_count_a_correct_amount_of_elements() {
        dictionary["0"] = 0
        dictionary["1"] = 1
        dictionary["2"] = 2
        dictionary["0"] = 3
        XCTAssertEqual(dictionary.count, 3)
    }

    func test_should_initialize_from_key_values_and_retrieve_elements_in_order_of_insertion() {
        dictionary = OrderedDictionary([
            ("0", 0),
            ("1", 1),
            ("2", 2),
            ("0", 3)
        ])
        XCTAssertEqual(dictionary.orderedKeys, ["1", "2", "0"])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [1, 2, 3])
    }

    func test_should_delete_value_and_remove_key_from_ordered_list_when_setting_value_to_nil() {
        dictionary = OrderedDictionary([
            ("0", 0),
            ("1", 1),
            ("2", 2),
            ("0", 3)
            ])

        dictionary["1"] = nil

        XCTAssertEqual(dictionary.orderedKeys, ["2", "0"])
        XCTAssertEqual(dictionary.orderedKeyValues.map { $0.1 }, [2, 3])
    }
}

// MARK: - Set

final class OrderedSetTests: XCTestCase {

    private var set: OrderedSet<String>!

    override func setUp() {
        super.setUp()
        set = OrderedSet()
    }

    override func tearDown() {
        defer { super.tearDown() }
        set = nil
    }

    func test_should_add_elements_and_retrieve_them_in_order_of_insertion() {
        set.append("0")
        set.append("1")
        set.append("2")
        set.append("3")
        XCTAssertEqual(set.array, ["0", "1", "2", "3"])
    }

    func test_should_add_an_element_twice_and_retrieve_it_once_in_order_of_insertion() {
        set.append("0")
        set.append("1")
        set.append("2")
        set.append("0")
        XCTAssertEqual(set.array, ["1", "2", "0"])
    }

    func test_should_add_an_element_twice_and_count_a_correct_amount_of_elements() {
        set.append("0")
        set.append("1")
        set.append("2")
        set.append("0")
        XCTAssertEqual(set.count, 3)
    }

    func test_should_initialize_from_key_values_and_retrieve_elements_in_order_of_insertion() {
        set = OrderedSet(["0", "1", "2", "0"])
        XCTAssertEqual(set.array, ["1", "2", "0"])
    }

    func test_should_remove_member() {
        set.append("0")
        set.append("1")
        set.append("2")
        set.append("0")
        set.remove("2")
        XCTAssertEqual(set.array, ["1", "0"])
    }

    func test_should_decode_from_legacy_encoded_data() throws {
        let jsonEncoder = JSONEncoder()
        let jsonDecoder = JSONDecoder()

        var dictionary = OrderedDictionary<String, String>()
        dictionary["0"] = "0"
        dictionary["3"] = "3"
        dictionary["2"] = "2"
        dictionary["1"] = "1"

        let data = try jsonEncoder.encode(dictionary)
        set = try jsonDecoder.decode(OrderedSet<String>.self, from: data)

        XCTAssertEqual(set.array, ["0", "3", "2", "1"])
    }

    func test_should_decode_from_encoded_data() throws {
        let jsonEncoder = JSONEncoder()
        let jsonDecoder = JSONDecoder()

        let data = try jsonEncoder.encode(OrderedSet(["0", "3", "2", "1"]))
        set = try jsonDecoder.decode(OrderedSet<String>.self, from: data)

        XCTAssertEqual(set.array, ["0", "3", "2", "1"])
    }
}

final class DualHashSetTests: XCTestCase {

    private var set: DualHashSet<IdentifierValueType<String, Int>>!

    override func setUp() {
        super.setUp()
        set = DualHashSet()
    }

    override func tearDown() {
        defer { super.tearDown() }
        set = nil
    }

    // MARK: count

    func test_should_insert_element_and_have_it_reflected_by_count() {
        set.insert(.remote(0, "0"))
        XCTAssertEqual(set.count, 1)
    }

    func test_should_insert_two_elements_and_have_them_reflected_by_count() {
        set.insert(.remote(0, "0"))
        set.insert(.remote(1, "1"))
        XCTAssertEqual(set.count, 2)
    }

    func test_should_insert_two_similar_elements_and_count_only_one_element() {
        set.insert(.remote(0, "0"))
        set.insert(.local("0"))
        XCTAssertEqual(set.count, 1)
    }

    // MARK: enumeration

    func test_should_inset_two_elements_and_retrieve_then_with_an_iterator() {
        set.insert(.remote(0, "0"))
        set.insert(.remote(1, "1"))
        let elements = set.enumerated().map { $0.element }
        XCTAssertTrue(elements.contains(.remote(0, "0")))
        XCTAssertTrue(elements.contains(.remote(1, "1")))
    }

    // MARK: contains

    func test_set_contains_remote() {
        set.insert(.remote(0, "0"))
        XCTAssertTrue(set.contains(.remote(0, "0")))
        XCTAssertTrue(set.contains(.remote(0, nil)))
        XCTAssertTrue(set.contains(.local("0")))
        XCTAssertEqual(set.count, 1)
    }

    func test_set_contains_local() {
        set.insert(.local("0"))
        XCTAssertTrue(set.contains(.remote(0, "0")))
        XCTAssertTrue(set.contains(.local("0")))
        XCTAssertFalse(set.contains(.remote(0, nil)))
        XCTAssertEqual(set.count, 1)
    }

    func test_set_merges_local_and_remote_and_contains_both() {
        set.insert(.local("0"))
        set.insert(.remote(0, "0"))
        XCTAssertTrue(set.contains(.local("0")))
        XCTAssertTrue(set.contains(.remote(0, "0")))
        XCTAssertEqual(set.count, 1)
    }

    func test_set_merges_local_remote_only_and_remote_and_contains_all_three() {
        set.insert(.local("0"))
        set.insert(.remote(0, nil))
        set.insert(.remote(0, "0"))
        XCTAssertTrue(set.contains(.local("0")))
        XCTAssertTrue(set.contains(.remote(0, nil)))
        XCTAssertTrue(set.contains(.remote(0, "0")))
        XCTAssertEqual(set.count, 1)
    }

}
