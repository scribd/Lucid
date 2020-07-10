//
//  MockCoreDataManager.swift
//  LucidTests
//
//  Created by Stephane Magne on 4/5/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

#if LUCID_REACTIVE_KIT
@testable import Lucid_ReactiveKit
#else
@testable import Lucid
#endif

final class StubCoreDataManagerFactory {

    private enum Defaults {
        private static let modelName = "StubCoreDataModel"

        static var modelURL: URL {
            let bundle = Bundle(for: StubCoreDataManagerFactory.self)
            guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd") else {
                return URL(fileURLWithPath: "")
            }
            return modelURL
        }

        static var persistentStoreURL: URL {
            guard let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first else {
                return URL(fileURLWithPath: "")
            }
            return URL(fileURLWithPath: "\(appSupportDirectory)/\(modelName).sqlite")
        }

        static var stubDispatchQueue: DispatchQueue {
            return DispatchQueue(label: "\(StubCoreDataManagerFactory.self)")
        }
    }

    static let stubDispatchQueue: DispatchQueue = Defaults.stubDispatchQueue

    static let shared: CoreDataManager = CoreDataManager(modelURL: Defaults.modelURL,
                                                         persistentStoreURL: Defaults.persistentStoreURL,
                                                         dispatchQueue: stubDispatchQueue)
}
