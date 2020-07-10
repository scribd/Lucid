//
//  BatchManager.swift
//  Lucid
//
//  Created by Stephane Magne on 2/27/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

public final class BatchManager<E: BatchEntity> {

    private let batchSize: Int
    private let remoteStore: RemoteStore<E>
    private var objects: [E.BatchableObject] = []

    private let queue = DispatchQueue(label: "\(BatchManager.self)", qos: .utility)

    // MARK: Inits

    public init(batchSize: Int,
                remoteStore: RemoteStore<E>) {
        self.batchSize = batchSize
        self.remoteStore = remoteStore
    }
}

// MARK: - Interface

public extension BatchManager {

    func consume(_ object: E.BatchableObject) {
        queue.async {
            self._consume(object)
        }
    }

    func flush(completion: @escaping () -> Void) {
        queue.async {
            self._flush()
            completion()
        }
    }

    @discardableResult func flushSynchronously(minimumBatchSize: Int = 1) -> Bool {
        return queue.sync {
            self._flush(minimumBatchSize: minimumBatchSize)
        }
    }
}

// MARK: - Private

private extension BatchManager {

    func _consume(_ object: E.BatchableObject) {
        objects.append(object)
        if objects.count >= batchSize {
            _flush()
        }
    }

    @discardableResult func _flush(minimumBatchSize: Int = 1) -> Bool {
        guard objects.count >= minimumBatchSize else { return false }
        let entity = E.init(objects: objects)
        objects = []
        remoteStore.set(entity, in: WriteContext<E>(dataTarget: .remote(endpoint: .derivedFromEntityType))) { _ in }
        return true
    }
}
