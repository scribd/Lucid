//
//  Configuration.swift
//  Sample
//
//  Created by Théophane Rupin on 6/26/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation

public enum LucidConfiguration {

    /// - Warning: Only use if also using `useCoreDataLegacyNaming` option for generating the code.
    public static var useCoreDataLegacyNaming = false

    /// Depth limit for which `RelationshipController` won't go beyond in any scenario.
    public static var relationshipControllerMaxRecursionDepth = 10

    /// - Warning: Non thread-safe.
    public static var logger: Logging?
}
