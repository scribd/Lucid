//
//  APIRequestDeduplicatorSpy.swift
//  LucidTestKit
//
//  Created by Ibrahim Sha'ath on 3/27/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import XCTest

@testable import Lucid

final class APIRequestDeduplicatorSpy: APIRequestDeduplicating {

    var testForDuplicationPassthrough: Bool = true
    private(set) var testForDuplicationInvocations = [(
        APIRequestConfig,
        (Result<APIClientResponse<Data>, APIError>) -> Void,
        (Bool) -> Void
    )]()
    func testForDuplication(request: APIRequestConfig, handler: @escaping (Result<APIClientResponse<Data>, APIError>) -> Void, completion: @escaping (Bool) -> Void) {
        testForDuplicationInvocations.append((request, handler, completion))
        if testForDuplicationPassthrough {
            completion(false)
        }
    }

    private(set) var applyResultToDuplicatesInvocations = [(
        APIRequestConfig,
        Result<APIClientResponse<Data>, APIError>
    )]()
    func applyResultToDuplicates(request: APIRequestConfig, result: Result<APIClientResponse<Data>, APIError>) {
        applyResultToDuplicatesInvocations.append((request, result))
    }
}
