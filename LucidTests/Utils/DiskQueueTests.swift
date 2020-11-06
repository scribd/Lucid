//
//  DiskQueueTests.swift
//  LucidTests
//
//  Created by Théophane Rupin on 8/5/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import XCTest

@testable import Lucid
@testable import LucidTestKit

final class DiskQueueUnitTests: XCTestCase {

    private var diskCacheSpy: DiskCacheSpy<TestData>!

    private var diskQueue: DiskQueue<TestData>!

    override func setUp() {
        super.setUp()

        LucidConfiguration.logger = LoggerMock()

        diskCacheSpy = DiskCacheSpy<TestData>()
        diskQueue = DiskQueue(diskCache: diskCacheSpy.caching)
    }

    override func tearDown() {
        defer { super.tearDown() }

        diskCacheSpy = nil
        diskQueue = nil
        LucidConfiguration.logger = nil
    }

    func test_should_prepend_elements_in_the_queue() {

        diskQueue.prepend(TestData(name: "first_element"))
        diskQueue.prepend(TestData(name: "second_element"))
        diskQueue.prepend(TestData(name: "third_element"))

        XCTAssertEqual(diskCacheSpy.setInvocations.count, 3)
        XCTAssertEqual(diskCacheSpy.setInvocations[0].0, "9223372036854775806")
        XCTAssertEqual(diskCacheSpy.setInvocations[0].1?.name, "first_element")
        XCTAssertEqual(diskCacheSpy.setInvocations[1].0, "9223372036854775805")
        XCTAssertEqual(diskCacheSpy.setInvocations[1].1?.name, "second_element")
        XCTAssertEqual(diskCacheSpy.setInvocations[2].0, "9223372036854775804")
        XCTAssertEqual(diskCacheSpy.setInvocations[2].1?.name, "third_element")
    }

    func test_should_append_elements_in_the_queue() {

        diskQueue.append(TestData(name: "first_element"))
        diskQueue.append(TestData(name: "second_element"))
        diskQueue.append(TestData(name: "third_element"))

        XCTAssertEqual(diskCacheSpy.setInvocations.count, 3)
        XCTAssertEqual(diskCacheSpy.setInvocations[0].0, "9223372036854775807")
        XCTAssertEqual(diskCacheSpy.setInvocations[0].1?.name, "first_element")
        XCTAssertEqual(diskCacheSpy.setInvocations[1].0, "9223372036854775808")
        XCTAssertEqual(diskCacheSpy.setInvocations[1].1?.name, "second_element")
        XCTAssertEqual(diskCacheSpy.setInvocations[2].0, "9223372036854775809")
        XCTAssertEqual(diskCacheSpy.setInvocations[2].1?.name, "third_element")
    }

    func test_queue_should_initialize_from_a_previous_state() {

        diskCacheSpy.values["10"] = TestData(name: "first_element")
        diskCacheSpy.values["11"] = TestData(name: "second_element")
        diskCacheSpy.values["12"] = TestData(name: "third_element")

        diskQueue = DiskQueue(diskCache: diskCacheSpy.caching)

        XCTAssertEqual(diskQueue.count, 3)
    }

    func test_should_drop_first_elements_from_queue() {
        diskCacheSpy.values["10"] = TestData(name: "first_element")
        diskCacheSpy.values["11"] = TestData(name: "second_element")
        diskCacheSpy.values["12"] = TestData(name: "third_element")

        diskQueue = DiskQueue(diskCache: diskCacheSpy.caching)

        XCTAssertEqual(diskQueue.dropFirst()?.name, "first_element")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "second_element")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "third_element")

        XCTAssertNil(diskCacheSpy.values["10"])
        XCTAssertNil(diskCacheSpy.values["11"])
        XCTAssertNil(diskCacheSpy.values["12"])
    }

    // MARK: filtering

    func test_queue_should_filter_items_from_front_and_shift_head() {

        diskQueue.append(TestData(name: "Z: first_element"))
        diskQueue.append(TestData(name: "A: second_element"))
        diskQueue.append(TestData(name: "A: third_element"))

        XCTAssertEqual(diskQueue.count, 3)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 3)

        diskQueue.filter(isIncluded: { $0.name.contains("A") })

        XCTAssertEqual(diskQueue.count, 2)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2 + 1)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 3)
    }

    func test_queue_should_filter_items_from_end_and_shift_tail() {

        diskQueue.append(TestData(name: "A: first_element"))
        diskQueue.append(TestData(name: "A: second_element"))
        diskQueue.append(TestData(name: "Z: third_element"))

        XCTAssertEqual(diskQueue.count, 3)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 3)

        diskQueue.filter(isIncluded: { $0.name.contains("A") })

        XCTAssertEqual(diskQueue.count, 2)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 2)
    }

    func test_queue_should_filter_out_items_from_middle() {

        diskQueue.append(TestData(name: "A: first_element"))
        diskQueue.append(TestData(name: "Z: second_element"))
        diskQueue.append(TestData(name: "Z: third_element"))
        diskQueue.append(TestData(name: "Z: fourth_element"))
        diskQueue.append(TestData(name: "A: fifth_element"))

        XCTAssertEqual(diskQueue.count, 5)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 5)

        diskQueue.filter(isIncluded: { $0.name.contains("A") })

        XCTAssertEqual(diskQueue.count, 2)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 2)
    }

    func test_queue_should_filter_out_items_from_front_and_middle_and_shift_head() {

        diskQueue.append(TestData(name: "Z: first_element"))
        diskQueue.append(TestData(name: "A: second_element"))
        diskQueue.append(TestData(name: "Z: third_element"))
        diskQueue.append(TestData(name: "Z: fourth_element"))
        diskQueue.append(TestData(name: "A: fifth_element"))

        XCTAssertEqual(diskQueue.count, 5)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 5)

        diskQueue.filter(isIncluded: { $0.name.contains("A") })

        XCTAssertEqual(diskQueue.count, 2)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2 + 1)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 3)
    }

    func test_queue_should_filter_out_items_from_middle_and_end_and_shift_tail() {

        diskQueue.append(TestData(name: "A: first_element"))
        diskQueue.append(TestData(name: "Z: second_element"))
        diskQueue.append(TestData(name: "A: third_element"))
        diskQueue.append(TestData(name: "Z: fourth_element"))
        diskQueue.append(TestData(name: "Z: fifth_element"))

        XCTAssertEqual(diskQueue.count, 5)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 5)

        diskQueue.filter(isIncluded: { $0.name.contains("A") })

        XCTAssertEqual(diskQueue.count, 2)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 2)
    }

    func test_queue_should_filter_out_items_from_front_middle_and_end_and_shift_head_and_tail() {

        diskQueue.append(TestData(name: "Z: first_element"))
        diskQueue.append(TestData(name: "A: second_element"))
        diskQueue.append(TestData(name: "Z: third_element"))
        diskQueue.append(TestData(name: "A: fourth_element"))
        diskQueue.append(TestData(name: "Z: fifth_element"))

        XCTAssertEqual(diskQueue.count, 5)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 5)

        diskQueue.filter(isIncluded: { $0.name.contains("A") })

        XCTAssertEqual(diskQueue.count, 2)
        XCTAssertEqual(diskQueue._headKey, UInt.max/2 + 1)
        XCTAssertEqual(diskQueue._tailKey, UInt.max/2 + 3)
    }
}

final class DiskQueueIntegrationTests: XCTestCase {

    private var diskCache: DiskCache<TestData>!

    private var diskQueue: DiskQueue<TestData>!

    override func setUp() {
        super.setUp()

        LucidConfiguration.logger = LoggerMock()

        diskCache = DiskCache(basePath: "\(DiskQueueIntegrationTests.self)")
        diskCache.clear()
        diskQueue = DiskQueue(diskCache: diskCache.caching)
    }

    override func tearDown() {
        defer { super.tearDown() }

        diskCache.clear()
        diskCache = nil
        diskQueue = nil
        LucidConfiguration.logger = nil
    }

    func test_should_prepend_elements_in_the_queue_then_drop_them_in_order() {

        diskQueue.prepend(TestData(name: "first_element"))
        diskQueue.prepend(TestData(name: "second_element"))
        diskQueue.prepend(TestData(name: "third_element"))

        XCTAssertEqual(diskQueue.dropFirst()?.name, "third_element")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "second_element")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "first_element")
    }

    func test_should_append_elements_in_the_queue_then_drop_them_in_order() {

        diskQueue.append(TestData(name: "first_element"))
        diskQueue.append(TestData(name: "second_element"))
        diskQueue.append(TestData(name: "third_element"))

        XCTAssertEqual(diskQueue.dropFirst()?.name, "first_element")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "second_element")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "third_element")
    }

    func test_should_prepend_and_append_elements_in_the_queue_then_drop_them_in_order() {

        diskQueue.append(TestData(name: "first_element"))
        diskQueue.prepend(TestData(name: "second_element"))
        diskQueue.append(TestData(name: "third_element"))

        XCTAssertEqual(diskQueue.dropFirst()?.name, "second_element")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "first_element")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "third_element")
    }

    func test_should_prepend_and_append_elements_in_the_queue_then_have_the_right_count() {

        diskQueue.append(TestData(name: "first_element"))
        diskQueue.prepend(TestData(name: "second_element"))
        diskQueue.append(TestData(name: "third_element"))

        XCTAssertEqual(diskQueue.count, 3)
    }

    func test_should_add_elements_in_the_queue_and_drop_them_then_have_the_right_count() {

        diskQueue.append(TestData(name: "first_element"))
        diskQueue.prepend(TestData(name: "second_element"))
        diskQueue.append(TestData(name: "third_element"))

        _ = diskQueue.dropFirst()
        _ = diskQueue.dropFirst()
        _ = diskQueue.dropFirst()

        XCTAssertEqual(diskQueue.count, 0)
    }

    func test_should_drop_inexistant_element_from_the_queue_then_have_the_right_count() {
        XCTAssertNil(diskQueue.dropFirst())
        XCTAssertEqual(diskQueue.count, 0)
    }

    func test_should_prepend_and_append_elements_in_the_queue_them_map_them() {

        diskQueue.append(TestData(name: "first_element"))
        diskQueue.prepend(TestData(name: "second_element"))
        diskQueue.append(TestData(name: "third_element"))

        diskQueue!.map { element in TestData(name: "\(element.name)_mapped") }

        XCTAssertEqual(diskQueue.dropFirst()?.name, "second_element_mapped")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "first_element_mapped")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "third_element_mapped")
    }

    func test_queue_should_initialize_from_a_previous_state() {

        diskQueue.append(TestData(name: "first_element"))
        diskQueue.prepend(TestData(name: "second_element"))
        diskQueue.append(TestData(name: "third_element"))

        diskQueue = DiskQueue(diskCache: diskCache.caching)

        XCTAssertEqual(diskQueue.dropFirst()?.name, "second_element")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "first_element")
        XCTAssertEqual(diskQueue.dropFirst()?.name, "third_element")
    }
}

private struct TestData: Codable {
    let name: String
}
