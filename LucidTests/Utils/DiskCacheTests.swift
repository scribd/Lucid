//
//  DiskCacheTests.swift
//  LucidTests
//
//  Created by Mr Escobar on 1/28/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import XCTest

@testable import Lucid
@testable import LucidTestKit

final class DiskCacheTests: XCTestCase {

    var fileManager: FileManager!
    var diskCache: DiskCache<URL>!
    let searchPathDirectory: FileManager.SearchPathDirectory = .cachesDirectory
    let pathComponents = "path/to/test"

    override func setUp() {
        super.setUp()
        fileManager = FileManager()
        Logger.shared = LoggerMock()
    }

    override func tearDown() {
        defer { super.tearDown() }
        let basePath = fileManager.urls(for: searchPathDirectory, in: .userDomainMask).last!
        do {
            try fileManager.removeItem(at: basePath)
        } catch {
            Logger.shared?.log(.warning, "Could not delete the folder \(basePath)", domain: "test")
        }
        fileManager = nil
        diskCache = nil
    }

    func testDirectoryCreation() {

        let basePath = fileManager.urls(for: searchPathDirectory, in: .userDomainMask).last
        let pathURL = basePath!.appendingPathComponent("path")
        let pathToURL = pathURL.appendingPathComponent("to")
        let pathToTestURL = pathToURL.appendingPathComponent("test")

        var isDirectory: ObjCBool = true

        XCTAssertFalse(fileManager.fileExists(atPath: pathURL.path, isDirectory: &isDirectory), "\(pathURL) does not exist")
        XCTAssertFalse(fileManager.fileExists(atPath: pathToURL.path, isDirectory: &isDirectory), "\(pathToURL) does not exist")
        XCTAssertFalse(fileManager.fileExists(atPath: pathToTestURL.path, isDirectory: &isDirectory), "\(pathToTestURL) does not exist")

        diskCache = DiskCache(basePath: pathComponents, searchPathDirectory: searchPathDirectory, fileManager: fileManager)

        XCTAssertTrue(fileManager.fileExists(atPath: pathURL.path, isDirectory: &isDirectory), "\(pathURL) does not exist")
        XCTAssertTrue(fileManager.fileExists(atPath: pathToURL.path, isDirectory: &isDirectory), "\(pathToURL) does not exist")
        XCTAssertTrue(fileManager.fileExists(atPath: pathToTestURL.path, isDirectory: &isDirectory), "\(pathToTestURL) does not exist")
    }

    func testCurrentCacheSize() {

        diskCache = DiskCache(basePath: pathComponents, searchPathDirectory: searchPathDirectory, fileManager: fileManager)

        var basePath = fileManager.urls(for: searchPathDirectory, in: .userDomainMask).last!
        basePath.appendPathComponent(pathComponents)

        var isDirectory: ObjCBool = true
        XCTAssertTrue(fileManager.fileExists(atPath: basePath.path, isDirectory: &isDirectory), "\(basePath) does not exist")

        XCTAssertEqual(diskCache.currentCacheSize(), 0)

        let fileURL = basePath.appendingPathComponent("test.txt")
        let fileContents = "This is the data to be written in test.txt".data(using: .utf8)
        if fileManager.createFile(atPath: fileURL.path, contents: fileContents, attributes: [.size: index]) == false {
            XCTAssert(true, "File could not be created")
        }

        XCTAssertEqual(diskCache.currentCacheSize(), 42) // 42 is the size of the file with the content: "This is the data to be written in test.txt"
    }
}
