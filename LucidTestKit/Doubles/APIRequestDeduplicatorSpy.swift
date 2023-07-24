//
//  APIRequestDeduplicatorSpy.swift
//  LucidTestKit
//
//  Created by Ibrahim Sha'ath on 3/27/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import Lucid

public final class APIRequestDeduplicatorSpy: APIRequestDeduplicating {

    public init() {
        // no-op
    }

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

    public var isDuplicatedValue: Bool = true

    public private(set) var isDuplicatedInvocations = [APIRequestConfig]()

    public func isDuplicated(request: Lucid.APIRequestConfig) async -> Bool {
        isDuplicatedInvocations.append(request)
        return isDuplicatedValue
    }

    public var waitForDuplicatedValue: Result<APIClientResponse<Data>, APIError> = .failure(APIError.other("Failure"))

    public private(set) var waitForDuplicatedInvocations = [APIRequestConfig]()

    public func waitForDuplicated(request: Lucid.APIRequestConfig) async -> Result<Lucid.APIClientResponse<Data>, Lucid.APIError> {
        waitForDuplicatedInvocations.append(request)
        return waitForDuplicatedValue
    }


    public private(set) var applyResultToDuplicatesInvocations = [(
        APIRequestConfig,
        Result<APIClientResponse<Data>, APIError>
    )]()

    public func applyResultToDuplicates(request: APIRequestConfig, result: Result<APIClientResponse<Data>, APIError>) {
        applyResultToDuplicatesInvocations.append((request, result))
    }
}
