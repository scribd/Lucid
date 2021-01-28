//
//  ManagedEntitySpy+CoreDataProperties.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 1/28/21.
//  Copyright © 2021 Scribd. All rights reserved.
//
//

import Foundation
import CoreData


extension ManagedEntitySpy {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ManagedEntitySpy> {
        return NSFetchRequest<ManagedEntitySpy>(entityName: "EntitySpy")
    }

    @NSManaged public var __lazyLazyFlag: Int64
    @NSManaged public var __identifier: String?
    @NSManaged public var __oneRelationship: String?
    @NSManaged public var __oneRelationshipTypeUID: String?
    @NSManaged public var __type_uid: String?
    @NSManaged public var _lazy: Int64
    @NSManaged public var _identifier: Int64
    @NSManaged public var _manyRelationships: Data?
    @NSManaged public var _oneRelationship: Int64
    @NSManaged public var _title: String?
    @NSManaged public var _subtitle: String?

}

extension ManagedEntitySpy : Identifiable {

}
