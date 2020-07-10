//
//  DiskQueue.swift
//  Lucid
//
//  Created by Théophane Rupin on 3/1/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

public final class DiskQueue<Element> where Element: Codable {

    // MARK: - Dependencies

    private let lock = NSRecursiveLock(name: "\(DiskQueue.self):lock")

    private let _diskCache: DiskCaching<Element>

    private(set) var _headKey: UInt
    private(set) var _tailKey: UInt

    // MARK: - Inits

    public init(diskCache: DiskCaching<Element>) {
        self._diskCache = diskCache

        let keys = diskCache.keysAtInitialization()
        if keys.isEmpty {
            _headKey = UInt.max / 2
            _tailKey = UInt.max / 2
        } else {
            _headKey = UInt.max
            _tailKey = UInt.min
            for key in keys {
                if let key = UInt(key) {
                    _headKey = min(key, _headKey)
                    _tailKey = max(key, _tailKey)
                } else {
                    Logger.log(.error, "\(DiskQueue.self): Incompatible key: \(key). Removing from cache.")
                    diskCache[key] = nil
                }
            }
            _tailKey += 1
        }
    }

    // MARK: - API

    public func append(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }

        let (tailKey, didOverflow) = _tailKey.addingReportingOverflow(1)

        guard didOverflow == false else {
            Logger.log(.error, "\(DiskQueue.self): Full on its right side, cannot append anymore.", assert: true)
            return
        }

        guard _diskCache.set(_tailKey.description, element) else {
            return
        }

        _tailKey = tailKey
    }

    public func prepend(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }

        let (key, didOverflow) = _headKey.subtractingReportingOverflow(1)
        guard didOverflow == false else {
            Logger.log(.error, "\(DiskQueue.self): Full on its left side, cannot prepend anymore.", assert: true)
            return
        }

        guard _diskCache.set(key.description, element) else {
            return
        }

        _headKey = key
    }

    public func dropFirst() -> Element? {
        lock.lock()
        defer { lock.unlock() }

        let element = _diskCache[_headKey.description]
        _diskCache[_headKey.description] = nil

        if element != nil {
            let (key, didOverflow) = _headKey.addingReportingOverflow(1)
            guard didOverflow == false else {
                Logger.log(.error, "\(DiskQueue.self): Unexpected overflow of the head key.", assert: true)
                return element
            }
            _headKey = key
        }

        return element
    }

    public var count: UInt {
        lock.lock()
        defer { lock.unlock() }
        return _tailKey.subtractingReportingOverflow(_headKey).partialValue
    }

    public func map(_ transform: (Element) -> Element) {
        lock.lock()
        defer { lock.unlock() }

        for index in 0..<count {
            let key = _headKey.addingReportingOverflow(index).partialValue
            guard let element = _diskCache[key.description] else { continue }
            let newElement = transform(element)
            _diskCache[key.description] = newElement
        }
    }

    public func filter(isIncluded: (Element) -> Bool) {
        lock.lock()
        defer { lock.unlock() }

        var openIndex: UInt?
        let originalHeadKey = _headKey

        // filter
        for index in 0..<count {
            let key = originalHeadKey.addingReportingOverflow(index).partialValue
            guard let element = _diskCache[key.description] else { continue }
            if isIncluded(element) == false {
                if openIndex == nil { openIndex = index }
                _diskCache[key.description] = nil
            } else if let open = openIndex {
                // if we have removed elements, then we need to re-compress the queue
                let openKey = originalHeadKey.addingReportingOverflow(open).partialValue
                if openKey == originalHeadKey {
                    _headKey = key
                    openIndex = nil
                } else {
                    _diskCache[key.description] = nil
                    _diskCache[openKey.description] = element
                    openIndex = (openIndex ?? _headKey) + 1
                }
            }
        }

        if let openIndex = openIndex {
            _tailKey = originalHeadKey.addingReportingOverflow(openIndex).partialValue
        }
    }
}
