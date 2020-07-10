//
//  DiskCache.swift
//  Lucid
//
//  Created by Théophane Rupin on 10/17/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

public struct DiskCacheItemInfo {
    public let pathURL: URL
    public let accessDate: Date
    public let fileSize: UInt64
}

// MARK: - Disk Caching

public final class DiskCaching<DataType> {

    public typealias Getter = (_ identifier: String) -> DataType?
    let get: Getter

    public typealias Setter = (_ identifier: String, _ data: DataType?) -> Bool
    let set: Setter

    public typealias AsyncSetter = (_ identifier: String, _ data: DataType?) -> Void
    private let asyncSet: AsyncSetter

    public typealias Keys = () -> [String]
    let keys: Keys
    /// - Note: It is not thread-safe to call this at any time other than initialization
    let keysAtInitialization: Keys

    init(get: @escaping Getter,
         set: @escaping Setter,
         asyncSet: @escaping AsyncSetter,
         keys: @escaping Keys,
         keysAtInitialization: @escaping Keys) {

        self.get = get
        self.set = set
        self.asyncSet = asyncSet
        self.keys = keys
        self.keysAtInitialization = keysAtInitialization
    }

    public subscript(identifier: String) -> DataType? {
        get {
            return get(identifier)
        }
        set {
            _ = asyncSet(identifier, newValue)
        }
    }
}

public extension DiskCaching {

    func map(_ transform: (_ key: String, _ value: DataType) -> DataType) {
        for key in keys() {
            if let value = self[key] {
                self[key] = transform(key, value)
            }
        }
    }

    func dropFirst() -> DataType? {
        guard let key = keys().first, let value = self[key] else {
            return nil
        }
        self[key] = nil
        return value
    }
}

public final class DiskCache<DataType> where DataType: Codable {

    enum DispatchRule {
        case currentThread
        case sync
        case async
    }

    private let rootURL: URL

    private let localURL: URL

    private let fileManager: FileManager

    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    private let dispatchQueue = DispatchQueue(label: "\(DiskCache.self):queue")

    public init(basePath: String,
                searchPathDirectory: FileManager.SearchPathDirectory = .applicationSupportDirectory,
                codingContext: CodingContext? = nil,
                fileManager: FileManager = .default) {

        let rootURL: URL = {
            let directory = fileManager.urls(for: searchPathDirectory, in: .userDomainMask).last
            precondition(directory != nil)
            guard let rootURL = directory else {
                Logger.log(.error, "\(DiskCache<DataType>.self): Could not find a valid search path directory", assert: true)
                return URL(fileURLWithPath: "/")
            }
            return rootURL
        }()
        self.rootURL = rootURL
        self.fileManager = fileManager

        localURL = rootURL.appendingPathComponent(basePath, isDirectory: true)

        var isDirectory: ObjCBool = true
        let localDirectoryExists = fileManager.fileExists(atPath: localURL.absoluteString, isDirectory: &isDirectory)
        if localDirectoryExists == false {
            do {
                try fileManager.createDirectory(at: localURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                Logger.log(.error, "\(DiskCache<DataType>.self): Could not create directory: \(localURL.absoluteString): \(error)", assert: true)
            }
        }

        if let context = codingContext {
            jsonEncoder.set(context: context)
            jsonDecoder.set(context: context)
        }
    }

    // MARK: - Interface

    public var caching: DiskCaching<DataType> {
        return DiskCaching(get: get, set: set, asyncSet: asyncSet, keys: keys, keysAtInitialization: keysAtInitialization)
    }

    public func get(_ identifier: String) -> DataType? {
        let fileURL = localURL.appendingPathComponent(identifier)
        return read(at: fileURL)
    }

    @discardableResult
    public func set(_ identifier: String, _ data: DataType?) -> Bool {
        return _set(identifier, data, dispatchRule: .sync)
    }

    private func asyncSet(_ identifier: String, _ data: DataType?) {
        _set(identifier, data, dispatchRule: .async)
    }

    @discardableResult
    private func _set(_ identifier: String, _ data: DataType?, dispatchRule: DispatchRule) -> Bool {
        let fileURL = localURL.appendingPathComponent(identifier)
        return write(entry: data, at: fileURL, dispatchRule: dispatchRule)
    }

    public func clear() {
        clear(fileURLs: [localURL])
    }

    public func clear(fileURLs: [URL]) {
        dispatchQueue.sync {
            for fileURL in fileURLs {
                guard fileManager.fileExists(atPath: fileURL.path) else {
                    return
                }

                do {
                    try fileManager.removeItem(at: fileURL)
                } catch {
                    Logger.log(.error, "\(DiskCache<DataType>.self): Could not delete directory: \(fileURL.absoluteString): \(error)", assert: true)
                }
            }
        }
    }

}

// MARK: - Public Utils

public extension DiskCache {

    func currentCacheSize() -> UInt64 {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: localURL, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles)

            var currentFileSize: UInt64 = 0

            for fileURL in fileURLs {
                guard let fileResourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                    let fileSize = fileResourceValues.fileSize else {
                            Logger.log(.error, "\(DiskCache.self): File size attribute could not be retrieved from \(fileURL)", assert: true)
                        continue
                }

                currentFileSize += UInt64(fileSize)
            }

            return currentFileSize
        } catch {
            Logger.log(.error, "\(DiskCache.self): Could not access contents of cached directory ", assert: true)
            return 0
        }
    }

    func cachedItems() -> [DiskCacheItemInfo]? {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: localURL, includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey], options: .skipsHiddenFiles)

            var diskCacheItems = [DiskCacheItemInfo]()

            for fileURL in fileURLs {
                guard let fileResourceValues = try? fileURL.resourceValues(forKeys: [.contentAccessDateKey, .fileSizeKey]),
                    let fileAccessDate = fileResourceValues.contentAccessDate,
                    let fileSize = fileResourceValues.fileSize else {
                            Logger.log(.error, "\(DiskCache.self): File size and access date attributes could not be retrieved from \(fileURL)", assert: true)
                        continue
                }
                    let itemInfo = DiskCacheItemInfo(pathURL: fileURL, accessDate: fileAccessDate, fileSize: UInt64(fileSize))
                    diskCacheItems.append(itemInfo)
                }

            return diskCacheItems
        } catch {
            Logger.log(.error, "\(DiskCache.self): Could not access contents of cached directory ", assert: true)
            return nil
        }
    }
}

// MARK: - Private Utils

private extension DiskCache {

    func read(at fileURL: URL) -> DataType? {
        return dispatchQueue.sync {
            do {
                try _ensureDirectoryExists(for: localURL)
                return try fileManager.contents(atPath: fileURL.path).flatMap {
                    try JSONDecoder().decode(DataType.self, from: $0)
                }
            } catch {
                Logger.log(.error, "\(DiskCache<DataType>.self): Could not read content of file '\(fileURL.absoluteString)': \(error)", assert: true)
                write(entry: nil, at: fileURL, dispatchRule: .currentThread)
                return nil
            }
        }
    }

    @discardableResult
    func write(entry: DataType?, at fileURL: URL, dispatchRule: DispatchRule) -> Bool {
        let writeEntry: () -> Bool = {
            do {
                try self._ensureDirectoryExists(for: self.localURL)

                if self.fileManager.fileExists(atPath: fileURL.path) {
                    try self.fileManager.removeItem(at: fileURL)
                }

                if let entry = entry {
                    let entryData = try JSONEncoder().encode(entry)
                    self.fileManager.createFile(atPath: fileURL.path, contents: entryData, attributes: nil)
                }
                return true
            } catch {
                Logger.log(.error, "\(DiskCache<DataType>.self): Could not write item to disk: \(String(describing: entry)): \(error)", assert: true)
                return false
            }
        }

        switch dispatchRule {
        case .currentThread:
            return writeEntry()
        case .sync:
            return dispatchQueue.sync(execute: writeEntry)
        case .async:
            dispatchQueue.async { _ = writeEntry() }
            return true
        }
    }

    func keys() -> [String] {
        return _keys(dispatchRule: .sync)
    }

    func keysAtInitialization() -> [String] {
        return _keys(dispatchRule: .currentThread)
    }

    private func _keys(dispatchRule: DispatchRule) -> [String] {
        let getKeys: () -> [String] = {
            do {
                try self._ensureDirectoryExists(for: self.localURL)
                return try self.fileManager.contentsOfDirectory(atPath: self.localURL.path)
            } catch {
                Logger.log(.error, "\(DiskCache<DataType>.self): Could not read directory: \(self.localURL.absoluteString): \(error)", assert: true)
                return []
            }
        }

        switch dispatchRule {
        case .currentThread:
            return getKeys()
        case .sync:
            return dispatchQueue.sync(execute: getKeys)
        case .async:
            Logger.log(.error, "\(DiskCache<DataType>.self): Requesting keys with preference .async is not supported.", assert: true)
            return []
        }

    }

    func _ensureDirectoryExists(for localURL: URL) throws {
        guard fileManager.fileExists(atPath: localURL.path) == false else {
            return
        }
        try fileManager.createDirectory(at: localURL, withIntermediateDirectories: true, attributes: nil)
    }
}
