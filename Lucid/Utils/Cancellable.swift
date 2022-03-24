//
//  Cancellable.swift
//  Lucid
//
//  Created by Stephane Magne on 3/23/22.
//  Copyright © 2022 Scribd. All rights reserved.
//

import Combine
import Foundation

public final class CancellableBox {

    private var cancellables = Set<AnyCancellable>()

    private let storeLock = NSRecursiveLock(name: "cancellable_store_lock")

    public init() { }

    public func cancel() {
        storeLock.lock()
        defer { storeLock.unlock() }
        cancellables.forEach { $0.cancel() }
    }

    fileprivate func hold(_ anyCancellable: AnyCancellable) {
        storeLock.lock()
        defer { storeLock.unlock() }
        anyCancellable.store(in: &cancellables)
    }
}

public final actor CancellableActor {

    private var cancellables = Set<AnyCancellable>()

    public init() { }

    public func cancel() {
        cancellables.forEach { $0.cancel() }
    }

    fileprivate func hold(_ anyCancellable: AnyCancellable) {
        anyCancellable.store(in: &cancellables)
    }
}

public extension AnyCancellable {

    func store(in cancellable: CancellableBox) {
        cancellable.hold(self)
    }

    func store(in cancellable: CancellableActor) async {
        await cancellable.hold(self)
    }
}
