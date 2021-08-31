//
//  DataTypeTests.swift
//  LucidTests
//
//  Created by Stephane Magne on 6/26/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import Lucid
@testable import LucidTestKit

final class DataTypeTests: XCTestCase {

    func test_encoding_and_decoding_a_lazy_value() {

        struct Object: Codable, Equatable {
            let name: String
            let age: Int
            let petName: Lazy<String>
        }

        let object1 = Object(name: "Steve", age: 40, petName: .unrequested)
        let object2 = Object(name: "Bob", age: 45, petName: .requested("GoodDog"))

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let encodedData1 = try encoder.encode(object1)
            let encodedData2 = try encoder.encode(object2)

            let decodedObject1 = try decoder.decode(Object.self, from: encodedData1)
            let decodedObject2 = try decoder.decode(Object.self, from: encodedData2)
            
            XCTAssertEqual(object1, decodedObject1)
            XCTAssertEqual(object2, decodedObject2)
        } catch {
            XCTFail("failed with error \(error)")
        }
    }

    // MARK: APIRequestConfig.CachePolicy

    func _testCachePolicyMapping(_ cachePolicy: APIRequestConfig.CachePolicy, _ urlCachePolicy: NSURLRequest.CachePolicy) {
        let config = APIRequestConfig(method: .get,
                                      path: .path(""),
                                      cachePolicy: cachePolicy)

        guard let request = config.urlRequest(host: "test",
                                              queryEncoder: APIClientSpy.encodeQuery,
                                              bodyEncoder: APIClientSpy.encodeBody) else {
            XCTFail("couldn't generate request from config \(config)")
            return
        }

        XCTAssertEqual(request.cachePolicy, urlCachePolicy)
    }

    func test_request_config_with_standard_cache_policy_is_translated_to_use_protocol_cache_policy() {
        _testCachePolicyMapping(.standard, .useProtocolCachePolicy)
    }

    func test_request_config_with_server_only_cache_policy_is_translated_to_reload_ignoring_local_and_remote_cache_data() {
        _testCachePolicyMapping(.serverOnly, .reloadIgnoringLocalAndRemoteCacheData)
    }

    func test_request_config_with_remote_cache_or_server_cache_policy_is_translated_to_reload_ignoring_local_cache_data() {
        _testCachePolicyMapping(.remoteCacheOrServer, .reloadIgnoringLocalCacheData)
    }

    func test_request_config_with_cache_or_server_cache_policy_is_translated_to_return_cache_data_else_load() {
        _testCachePolicyMapping(.cacheOrServer, .returnCacheDataElseLoad)
    }

    func test_request_config_with_validated_cache_or_server_cache_policy_is_translated_to_reload_revalidating_cache_data() {
        _testCachePolicyMapping(.validatedCacheOrServer, .reloadRevalidatingCacheData)
    }

    func test_request_config_with_cache_only_cache_policy_is_translated_to_return_cache_data_dont_load() {
        _testCachePolicyMapping(.cacheOnly, .returnCacheDataDontLoad)
    }

    #if canImport(UIKit)

    // MARK: Color

    func test_red_hex_pair() {
        let color = Color(hex: "FF0000")

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.colorValue.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 1.0)
        XCTAssertEqual(green, 0.0)
        XCTAssertEqual(blue, 0.0)
        XCTAssertEqual(alpha, 1.0)
    }

    func test_green_hex_pair() {
        let color = Color(hex: "00FF00")

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.colorValue.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 0.0)
        XCTAssertEqual(green, 1.0)
        XCTAssertEqual(blue, 0.0)
        XCTAssertEqual(alpha, 1.0)
    }

    func test_blue_hex_pair() {
        let color = Color(hex: "0000FF")

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.colorValue.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 0.0)
        XCTAssertEqual(green, 0.0)
        XCTAssertEqual(blue, 1.0)
        XCTAssertEqual(alpha, 1.0)
    }

    func test_red_short_hex() {
        let color = Color(hex: "F00")

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.colorValue.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 1.0)
        XCTAssertEqual(green, 0.0)
        XCTAssertEqual(blue, 0.0)
        XCTAssertEqual(alpha, 1.0)
    }

    func test_green_short_hex() {
        let color = Color(hex: "0F0")

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.colorValue.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 0.0)
        XCTAssertEqual(green, 1.0)
        XCTAssertEqual(blue, 0.0)
        XCTAssertEqual(alpha, 1.0)
    }

    func test_blue_short_hex() {
        let color = Color(hex: "00F")

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.colorValue.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 0.0)
        XCTAssertEqual(green, 0.0)
        XCTAssertEqual(blue, 1.0)
        XCTAssertEqual(alpha, 1.0)
    }

    #endif
}
