//
//  Async.swift
//  Lucid
//
//  Created by Ezequiel Munz on 01/12/2023.
//  Copyright © 2023 Scribd. All rights reserved.
//

import XCTest

extension XCTestCase {
    ///
    /// Asynchronous assertion function that allows a future expectation to be checked.
    /// The expression passed by argument will be checked every 10 miliseconds until it gets satisfied or the timeout is hit
    /// If the expression is eventually satisfied, the test will pass
    /// If the timeout is hit before the expression is satisfied, the test will fail
    ///
    /// This function is useful to test asynchronous code where the execution happens within multiple threads
    ///
    /// - parameters:
    ///     - expression: The expression to be eventually satisfied
    ///     - timeout: The timeout interval for the operation to finish
    ///     - file: The file where the function is being called from (We don't need to overwrite it's value)
    ///     - line: The line where the function is being called from (We don't need to overwrite it's value)
    ///
    public func AsyncExpectation(expression: @escaping @autoclosure () async -> Bool, timeout: TimeInterval, file: StaticString = #file, line: UInt = #line) async {
        await withTaskGroup(of: Void.self) { group in
            // Timeout
            group.addTask {
                let timeoutValue = UInt64(1000000000 * timeout)
                var elapsedTime: TimeInterval = Date().timeIntervalSince1970
                try? await Task.sleep(nanoseconds: timeoutValue)
                guard Task.isCancelled == false else { return }
                elapsedTime = Date().timeIntervalSince1970 - elapsedTime
                XCTFail("Timeout after: \(elapsedTime)", file: file, line: line)
            }
            // Assertion
            group.addTask {
                var success = false
                var elapsedTime: TimeInterval = Date().timeIntervalSince1970
                repeat {
                    guard Task.isCancelled == false else { return }
                    if await expression() {
                        success = true
                        elapsedTime = Date().timeIntervalSince1970 - elapsedTime
                        XCTAssertTrue(success, "Comparison succeeded after \(elapsedTime) seconds", file: file, line: line)
                        return
                    }
                    try? await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
                } while success == false
            }

            await group.next()
            group.cancelAll()
        }
    }

    ///
    /// Base assertion function that takes an asynchronous expression
    /// This option is viable to use within `actor` properties
    ///
    /// - parameters:
    ///     - expression: Expression to be satisfied that returns a boolean
    ///     - message: A message to display on the test
    ///     - file: The file where the function is being called from (We don't need to overwrite it's value)
    ///     - line: The line where the function is being called from (We don't need to overwrite it's value)
    ///
    public func XCTAsyncAssert(_ expression: @autoclosure () async throws -> Bool,
                               _ message: @autoclosure () -> String = "",
                               file: StaticString = #filePath,
                               line: UInt = #line) async {
        do {
            let result = try await expression()
            XCTAssert(result, message(), file: file, line: line)
        } catch {
            XCTFail("Expression error: \(error)", file: file, line: line)
        }
    }

    ///
    /// True assertion function that takes an asynchronous expression
    /// This option is viable to use within `actor` properties
    ///
    /// - parameters:
    ///     - expression: Expression to be satisfied that returns a boolean
    ///     - message: A message to display on the test
    ///     - file: The file where the function is being called from (We don't need to overwrite it's value)
    ///     - line: The line where the function is being called from (We don't need to overwrite it's value)
    ///
    public func XCTAsyncAssertTrue(_ expression: @autoclosure () async throws -> Bool,
                                   _ message: @autoclosure () -> String = "",
                                   file: StaticString = #filePath,
                                   line: UInt = #line) async {
        do {
            let result = try await expression()
            XCTAssertTrue(result, message(), file: file, line: line)
        } catch {
            XCTFail("Expression error: \(error)", file: file, line: line)
        }
    }

    ///
    /// False assertion function that takes an asynchronous expression
    /// This option is viable to use within `actor` properties
    ///
    /// - parameters:
    ///     - expression: Expression to be satisfied that returns a boolean
    ///     - message: A message to display on the test
    ///     - file: The file where the function is being called from (We don't need to overwrite it's value)
    ///     - line: The line where the function is being called from (We don't need to overwrite it's value)
    ///
    public func XCTAsyncAssertFalse(_ expression: @autoclosure () async throws -> Bool,
                                    _ message: @autoclosure () -> String = "",
                                    file: StaticString = #filePath,
                                    line: UInt = #line) async {
        do {
            let result = try await expression()
            XCTAssertFalse(result, message(), file: file, line: line)
        } catch {
            XCTFail("Expression error: \(error)", file: file, line: line)
        }
    }

    ///
    /// Equality assertion function that takes an asynchronous expression
    /// This option is viable to use within `actor` properties
    ///
    /// - parameters:
    ///     - expression: Expression to be satisfied that returns a boolean
    ///     - message: A message to display on the test
    ///     - file: The file where the function is being called from (We don't need to overwrite it's value)
    ///     - line: The line where the function is being called from (We don't need to overwrite it's value)
    ///
    public func XCTAsyncAssertEqual<T>(_ expression1: @autoclosure () async throws -> T,
                                       _ expression2: @autoclosure () async throws -> T,
                                       _ message: @autoclosure () -> String = "",
                                       file: StaticString = #filePath,
                                       line: UInt = #line) async where T : Equatable {
        do {
            let result1 = try await expression1()
            let result2 = try await expression2()
            XCTAssertEqual(result1, result2, message(), file: file, line: line)
        } catch {
            XCTFail("Expression error: \(error)", file: file, line: line)
        }
    }

    ///
    /// Nil assertion function that takes an asynchronous expression
    /// This option is viable to use within `actor` properties
    ///
    /// - parameters:
    ///     - expression: Expression to be satisfied that returns a boolean
    ///     - message: A message to display on the test
    ///     - file: The file where the function is being called from (We don't need to overwrite it's value)
    ///     - line: The line where the function is being called from (We don't need to overwrite it's value)
    ///
    public func XCTAsyncAssertNil<T>(_ expression: @autoclosure () async throws -> T?,
                                     _ message: @autoclosure () -> String = "",
                                     file: StaticString = #filePath,
                                     line: UInt = #line) async {
        do {
            let result = try await expression()
            XCTAssertNil(result, message(), file: file, line: line)
        } catch {
            XCTFail("Expression error: \(error)", file: file, line: line)
        }
    }

    ///
    /// Not nil assertion function that takes an asynchronous expression
    /// This option is viable to use within `actor` properties
    ///
    /// - parameters:
    ///     - expression: Expression to be satisfied that returns a boolean
    ///     - message: A message to display on the test
    ///     - file: The file where the function is being called from (We don't need to overwrite it's value)
    ///     - line: The line where the function is being called from (We don't need to overwrite it's value)
    ///
    public func XCTAsyncAssertNotNil<T>(_ expression: @autoclosure () async throws -> T?,
                                        _ message: @autoclosure () -> String = "",
                                        file: StaticString = #filePath,
                                        line: UInt = #line) async {
        do {
            let result = try await expression()
            XCTAssertNotNil(result, message(), file: file, line: line)
        } catch {
            XCTFail("Expression error: \(error)", file: file, line: line)
        }
    }
}

