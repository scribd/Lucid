//
//  CodingPathTests.swift
//  LucidTests
//
//  Created by Stephane Magne on 9/17/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import XCTest

@testable import Lucid_ReactiveKit
@testable import LucidTestKit_ReactiveKit

final class StoreCodingPathTestsStackTests: XCTestCase {

    private var payload: Payload!

    private var rootObject: RootObject!

    private var nestedObject: NestedObject!

    private var encoder: JSONEncoder!

    private var decoder: JSONDecoder!

    override func setUp() {
        super.setUp()

        nestedObject = NestedObject(id: 123, value: "some")
        rootObject = RootObject(name: "Test", title: "Manager", nested: nestedObject)
        payload = Payload(root: rootObject)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    override func tearDown() {
        defer { super.tearDown() }

        nestedObject = nil
        rootObject = nil
        payload = nil
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func test_basic_encoding_decoding() {
        let jsonData: Data
        do {
            jsonData = try encoder.encode(payload)
        } catch {
            XCTFail("failed to encode data")
            return
        }

        let decodedPayload: Payload
        do {
            decodedPayload = try decoder.decode(Payload.self, from: jsonData)
        } catch {
            XCTFail("failed to decode data")
            return
        }

        XCTAssertEqual(decodedPayload, payload)
    }

    func test_that_it_excludes_root_object_path() {
        let jsonData: Data
        do {
            jsonData = try encoder.encode(payload)
        } catch {
            XCTFail("failed to encode data")
            return
        }

        decoder.setExcludedPaths([
            "root.title"
        ])

        let decodedPayload: Payload
        do {
            decodedPayload = try decoder.decode(Payload.self, from: jsonData)
        } catch {
            XCTFail("failed to decode data")
            return
        }

        let expectedNestedObject = NestedObject(id: 123, value: "some")
        let expectedRootObject = RootObject(name: "Test", title: nil, nested: expectedNestedObject)
        let expectedPayload = Payload(root: expectedRootObject)

        XCTAssertEqual(decodedPayload, expectedPayload)
    }

    func test_that_it_excludes_root_object_path_for_subobject() {
        let jsonData: Data
        do {
            jsonData = try encoder.encode(payload)
        } catch {
            XCTFail("failed to encode data")
            return
        }

        decoder.setExcludedPaths([
            "root.nested"
        ])

        let decodedPayload: Payload
        do {
            decodedPayload = try decoder.decode(Payload.self, from: jsonData)
        } catch {
            XCTFail("failed to decode data")
            return
        }

        let expectedRootObject = RootObject(name: "Test", title: "Manager", nested: nil)
        let expectedPayload = Payload(root: expectedRootObject)

        XCTAssertEqual(decodedPayload, expectedPayload)
    }

    func test_that_it_excludes_nested_object_path() {
        let jsonData: Data
        do {
            jsonData = try encoder.encode(payload)
        } catch {
            XCTFail("failed to encode data")
            return
        }

        decoder.setExcludedPaths([
            "nested.value"
        ])

        let decodedPayload: Payload
        do {
            decodedPayload = try decoder.decode(Payload.self, from: jsonData)
        } catch {
            XCTFail("failed to decode data")
            return
        }

        let expectedNestedObject = NestedObject(id: 123, value: nil)
        let expectedRootObject = RootObject(name: "Test", title: "Manager", nested: expectedNestedObject)
        let expectedPayload = Payload(root: expectedRootObject)

        XCTAssertEqual(decodedPayload, expectedPayload)
    }

    func test_that_it_excludes_nested_object_using_two_depth_path() {
        let jsonData: Data
        do {
            jsonData = try encoder.encode(payload)
        } catch {
            XCTFail("failed to encode data")
            return
        }

        decoder.setExcludedPaths([
            "root.nested.value"
        ])

        let decodedPayload: Payload
        do {
            decodedPayload = try decoder.decode(Payload.self, from: jsonData)
        } catch {
            XCTFail("failed to decode data")
            return
        }

        let expectedNestedObject = NestedObject(id: 123, value: nil)
        let expectedRootObject = RootObject(name: "Test", title: "Manager", nested: expectedNestedObject)
        let expectedPayload = Payload(root: expectedRootObject)

        XCTAssertEqual(decodedPayload, expectedPayload)
    }

    func test_that_it_excludes_multiple_paths() {
        let jsonData: Data
        do {
            jsonData = try encoder.encode(payload)
        } catch {
            XCTFail("failed to encode data")
            return
        }

        decoder.setExcludedPaths([
            "root.title",
            "nested.value"
        ])

        let decodedPayload: Payload
        do {
            decodedPayload = try decoder.decode(Payload.self, from: jsonData)
        } catch {
            XCTFail("failed to decode data")
            return
        }

        let expectedNestedObject = NestedObject(id: 123, value: nil)
        let expectedRootObject = RootObject(name: "Test", title: nil, nested: expectedNestedObject)
        let expectedPayload = Payload(root: expectedRootObject)

        XCTAssertEqual(decodedPayload, expectedPayload)
    }

    func test_that_it_doesnt_exclude_nested_object_using_mismatched_path() {
        let jsonData: Data
        do {
            jsonData = try encoder.encode(payload)
        } catch {
            XCTFail("failed to encode data")
            return
        }

        decoder.setExcludedPaths([
            "other.nested.value"
        ])

        let decodedPayload: Payload
        do {
            decodedPayload = try decoder.decode(Payload.self, from: jsonData)
        } catch {
            XCTFail("failed to decode data")
            return
        }

        let expectedNestedObject = NestedObject(id: 123, value: "some")
        let expectedRootObject = RootObject(name: "Test", title: "Manager", nested: expectedNestedObject)
        let expectedPayload = Payload(root: expectedRootObject)

        XCTAssertEqual(decodedPayload, expectedPayload)
    }
}

private struct Payload: Encodable, Equatable {
    let root: RootObject
}

extension Payload: Decodable {

    enum Keys: String, CodingKey {
        case root
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let excludedProperties = decoder.excludedPropertiesAtCurrentPath
        root = try container.decode(RootObject.self, forKeys: [.root], excludedProperties: excludedProperties, logError: false)
    }
}

private struct RootObject: Encodable, Equatable {
    let name: String
    let title: String?
    let nested: NestedObject?
}

extension RootObject: Decodable {

    enum Keys: String, CodingKey {
        case name
        case title
        case nested
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let excludedProperties = decoder.excludedPropertiesAtCurrentPath
        name = try container.decode(String.self, forKeys: [.name], excludedProperties: excludedProperties, logError: false)
        title = try container.decode(String.self, forKeys: [.title], excludedProperties: excludedProperties, logError: false)
        nested = try container.decode(NestedObject.self, forKeys: [.nested], defaultValue: nil, excludedProperties: excludedProperties, logError: false)
    }
}

private struct NestedObject: Encodable, Equatable {
    let id: Int
    let value: String?
}

extension NestedObject: Decodable {

    enum Keys: String, CodingKey {
        case id
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let excludedProperties = decoder.excludedPropertiesAtCurrentPath
        id = try container.decode(Int.self, forKeys: [.id], excludedProperties: excludedProperties, logError: false)
        value = try container.decode(String.self, forKeys: [.value], defaultValue: nil, excludedProperties: excludedProperties, logError: false)
    }
}
