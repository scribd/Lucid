//
//  StoreSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 12/10/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

#if !RELEASE

import Foundation
import XCTest

#if LUCID_REACTIVE_KIT
@testable import Lucid_ReactiveKit
#else
@testable import Lucid
#endif

open class StoreSpy<E: Entity>: StoringConvertible {

    // MARK: - Stubs

    public var levelStub: StoreLevel = .memory

    public var getResultStub: Result<QueryResult<E>, StoreError>?

    public var searchResultStub: Result<QueryResult<E>, StoreError>?

    public var setResultStub: Result<[E], StoreError>?

    public var removeAllResultStub: Result<[E.Identifier], StoreError>?

    public var removeResultStub: Result<Void, StoreError>?

    // MARK: - Records

    public private(set) var getCallCount = 0

    public private(set) var searchCallCount = 0

    public private(set) var setCallCount = 0

    public private(set) var removeAllCallCount = 0

    public private(set) var removeCallCount = 0

    public private(set) var identifierRecords = [E.Identifier]()

    public private(set) var readContextRecords = [ReadContext<E>]()

    public private(set) var writeContextRecords = [WriteContext<E>]()

    public private(set) var entityRecords = [E]()

    public private(set) var queryRecords = [Query<E>]()

    // MARK: - Asynchronous Timing

    public var stubAsynchronousCompletionQueue: DispatchQueue?

    // MARK: - API

    public init() {
        // no-op
    }

    open var level: StoreLevel {
        return levelStub
    }

    open func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        getCallCount += 1
        if let identifier = query.identifier {
            identifierRecords.append(identifier)
        }
        queryRecords.append(query)
        readContextRecords.append(context)
        guard let result = getResultStub else {
            XCTFail("Expected result stub to be set.")
            completion(.failure(.notSupported))
            return
        }
        if let asynchronousQueue = stubAsynchronousCompletionQueue {
            asynchronousQueue.asyncAfter(deadline: .now() + .milliseconds(20)) {
                completion(result)
            }
        } else {
            completion(result)
        }
    }

    open func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        searchCallCount += 1
        queryRecords.append(query)
        readContextRecords.append(context)
        guard let result = searchResultStub else {
            XCTFail("Expected result stub to be set")
            completion(.failure(.notSupported))
            return
        }
        if let asynchronousQueue = stubAsynchronousCompletionQueue {
            asynchronousQueue.asyncAfter(deadline: .now() + .milliseconds(20)) {
                completion(result)
            }
        } else {
            completion(result)
        }
    }

    open func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {
        setCallCount += 1
        entityRecords.append(contentsOf: entities)
        writeContextRecords.append(context)
        guard let result = setResultStub else {
            XCTFail("Expected result stub to be set.")
            completion(.failure(.notSupported))
            return
        }
        if let asynchronousQueue = stubAsynchronousCompletionQueue {
            asynchronousQueue.asyncAfter(deadline: .now() + .milliseconds(20)) {
                completion(result.any)
            }
        } else {
            completion(result.any)
        }
    }

    open func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {
        removeAllCallCount += 1
        queryRecords.append(query)
        writeContextRecords.append(context)
        guard let result = removeAllResultStub else {
            XCTFail("Expected result stub to be set.")
            completion(.failure(.notSupported))
            return
        }
        if let asynchronousQueue = stubAsynchronousCompletionQueue {
            asynchronousQueue.asyncAfter(deadline: .now() + .milliseconds(20)) {
                completion(result.any)
            }
        } else {
            completion(result.any)
        }
    }

    open func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {
        removeCallCount += 1
        identifierRecords.append(contentsOf: identifiers)
        writeContextRecords.append(context)
        guard let result = removeResultStub else {
            XCTFail("Expected result stub to be set.")
            completion(.failure(.notSupported))
            return
        }
        if let asynchronousQueue = stubAsynchronousCompletionQueue {
            asynchronousQueue.asyncAfter(deadline: .now() + .milliseconds(20)) {
                completion(result)
            }
        } else {
            completion(result)
        }
    }
}

#endif
