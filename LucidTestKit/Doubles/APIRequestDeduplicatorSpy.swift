//
//  APIRequestDeduplicatorSpy.swift
//  LucidTestKit
//
//  Created by Ibrahim Sha'ath on 3/27/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

#if !RELEASE

import XCTest

#if LUCID_REACTIVE_KIT
@testable import Lucid_ReactiveKit
#else
@testable import Lucid
#endif

public final class APIRequestDeduplicatorSpy: APIRequestDeduplicating {

    public var testForDuplicationPassthrough: Bool = true

    public private(set) var testForDuplicationInvocations = [(
        APIRequestConfig,
        (Result<APIClientResponse<Data>, APIError>) -> Void,
        (Bool) -> Void
    )]()

    public func testForDuplication(request: APIRequestConfig, handler: @escaping (Result<APIClientResponse<Data>, APIError>) -> Void, completion: @escaping (Bool) -> Void) {
        testForDuplicationInvocations.append((request, handler, completion))
        if testForDuplicationPassthrough {
            completion(false)
        }
    }

    public private(set) var applyResultToDuplicatesInvocations = [(
        APIRequestConfig,
        Result<APIClientResponse<Data>, APIError>
    )]()

    public func applyResultToDuplicates(request: APIRequestConfig, result: Result<APIClientResponse<Data>, APIError>) {
        applyResultToDuplicatesInvocations.append((request, result))
    }
}

#endif
