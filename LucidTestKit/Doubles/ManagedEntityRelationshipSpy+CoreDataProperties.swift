//
//  ManagedEntityRelationshipSpy+CoreDataProperties.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 1/28/21.
//  Copyright © 2021 Scribd. All rights reserved.
//
//

import Foundation
import CoreData


extension ManagedEntityRelationshipSpy {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ManagedEntityRelationshipSpy> {
        return NSFetchRequest<ManagedEntityRelationshipSpy>(entityName: "EntityRelationshipSpy")
    }

    @NSManaged public var __identifier: String?
    @NSManaged public var __type_uid: String?
    @NSManaged public var _identifier: Int64
    @NSManaged public var _title: String?
    @NSManaged public var _relationships: Data?

}

extension ManagedEntityRelationshipSpy : Identifiable {

}
