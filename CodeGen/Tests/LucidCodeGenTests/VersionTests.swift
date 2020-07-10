//
//  VersionTests.swift
//  LucidCodeGenTests
//
//  Created by Théophane Rupin on 3/20/19.
//

@testable import LucidCodeGen

import XCTest

final class VersionTests: XCTestCase {
    
    func test_should_parse_release_tag_with_major_minor_and_build() throws {
        let version = try Version("release_10.1-40", source: .gitTag)
        XCTAssertEqual(version.description, "10.1 (40) - appStore")
    }
    
    func test_should_parse_release_tag_with_major_minor_dot_and_build() throws {
        let version = try Version("release_10.1.1-40", source: .gitTag)
        XCTAssertEqual(version.description, "10.1.1 (40) - appStore")
    }
    
    func test_should_parse_release_tag_with_major_minor_and_dot() throws {
        let version = try Version("release_10.1.1", source: .gitTag)
        XCTAssertEqual(version.description, "10.1.1 - appStore")
    }

    func test_should_parse_release_tag_with_major_minor() throws {
        let version = try Version("release_10.1", source: .gitTag)
        XCTAssertEqual(version.description, "10.1 - appStore")
    }
    
    func test_should_parse_beta_tag_with_major_minor_dot_and_build() throws {
        let version = try Version("beta_release_10.1.1-40", source: .gitTag)
        XCTAssertEqual(version.description, "10.1.1 (40) - beta")
    }
    
    func test_should_parse_model_version_with_major_minor() throws {
        let version = try Version("10_1", source: .coreDataModel)
        XCTAssertEqual(version.description, "10.1 - other")
    }
    
    func test_should_parse_model_version_with_major_minor_dot() throws {
        let version = try Version("10_1_1", source: .coreDataModel)
        XCTAssertEqual(version.description, "10.1.1 - other")
    }
    
    func test_should_parse_model_version_with_major_minor_dot_and_ignored_build() throws {
        let version = try Version("10_1_1-40", source: .coreDataModel)
        XCTAssertEqual(version.description, "10.1.1 - other")
    }
    
    func test_should_parse_description_with_major_minor_and_build() throws {
        let version = try Version("10.1", source: .description)
        XCTAssertEqual(version.description, "10.1 - other")
    }
    
    func test_should_parse_description_with_major_minor_and_dot() throws {
        let version = try Version("10.1.1", source: .description)
        XCTAssertEqual(version.description, "10.1.1 - other")
    }
    
    func test_absence_of_dot_should_be_less_than_presence_of_dot() throws {
        let lhs = try Version("10.1", source: .gitTag)
        let rhs = try Version("10.1.0", source: .gitTag)
        XCTAssertLessThan(lhs, rhs)
    }
    
    func test_absence_of_dot_should_be_less_than_presence_of_positive_dot() throws {
        let lhs = try Version("10.1", source: .gitTag)
        let rhs = try Version("10.1.10", source: .gitTag)
        XCTAssertLessThan(lhs, rhs)
    }
    
    func test_absence_of_build_should_be_less_than_presence_of_build() throws {
        let lhs = try Version("10.1.1", source: .gitTag)
        let rhs = try Version("10.1.1-0", source: .gitTag)
        XCTAssertLessThan(lhs, rhs)
    }

    func test_absence_of_build_should_be_less_than_presence_of_positive_build() throws {
        let lhs = try Version("10.1.1", source: .gitTag)
        let rhs = try Version("10.1.1-10", source: .gitTag)
        XCTAssertLessThan(lhs, rhs)
    }
    
    func test_major_should_be_compared_first() throws {
        let lhs = try Version("release_10.1.1-10", source: .gitTag)
        let rhs = try Version("beta_11.2.1-10", source: .gitTag)
        XCTAssertLessThan(lhs, rhs)
    }
    
    func test_minor_should_be_compared_second() throws {
        let lhs = try Version("release_10.1.2-10", source: .gitTag)
        let rhs = try Version("beta_10.2.1-10", source: .gitTag)
        XCTAssertLessThan(lhs, rhs)
    }

    func test_dot_should_be_compared_third() throws {
        let lhs = try Version("release_10.1.1-11", source: .gitTag)
        let rhs = try Version("beta_10.1.2-10", source: .gitTag)
        XCTAssertLessThan(lhs, rhs)
    }
    
    func test_build_should_be_compared_fourth() throws {
        let lhs = try Version("release_10.1.1-10", source: .gitTag)
        let rhs = try Version("beta_10.1.1-11", source: .gitTag)
        XCTAssertLessThan(lhs, rhs)
    }
    
    func test_tag_should_be_compared_fourth() throws {
        let lhs = try Version("beta_10.1.1-10", source: .gitTag)
        let rhs = try Version("release_10.1.1-10", source: .gitTag)
        XCTAssertLessThan(lhs, rhs)
    }

    func test_shortest_length_should_be_applied_for_comparison() throws {
        let lhs = try Version("10.14", source: .description)
        let rhs = try Version("9.9.1", source: .description)
        XCTAssertGreaterThan(lhs, rhs)
    }
}
