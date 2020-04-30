//
//  StoreSpy.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 12/10/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import XCTest

@testable import Lucid

open class StoreSpy<E: Entity>: StoringConvertible {

    // MARK: - Stubs
    
    var levelStub: StoreLevel = .memory
    
    var getResultStub: Result<QueryResult<E>, StoreError>?

    var searchResultStub: Result<QueryResult<E>, StoreError>?

    var setResultStub: Result<[E], StoreError>?

    var removeAllResultStub: Result<[E.Identifier], StoreError>?

    var removeResultStub: Result<Void, StoreError>?

    // MARK: - Records
    
    private(set) var getCallCount = 0
    
    private(set) var searchCallCount = 0

    private(set) var setCallCount = 0

    private(set) var removeAllCallCount = 0

    private(set) var removeCallCount = 0
    
    private(set) var identifierRecords = [E.Identifier]()
    
    private(set) var readContextRecords = [ReadContext<E>]()

    private(set) var writeContextRecords = [WriteContext<E>]()

    private(set) var entityRecords = [E]()
    
    private(set) var queryRecords = [Query<E>]()

    // MARK: - Asynchronous Timing
    
    var stubAsynchronousCompletionQueue: DispatchQueue?
    
    // MARK: - API

    open var level: StoreLevel {
        return levelStub
    }
    
    open func get(byID identifier: E.Identifier, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        getCallCount += 1
        identifierRecords.append(identifier)
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
