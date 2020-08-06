//
//  MetaHeader.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 3/20/19.
//

import Meta

public struct MetaHeader {
    
    public let filename: String

    public let organizationName: String

    public init(filename: String,
                organizationName: String) {
        self.filename = filename
        self.organizationName = organizationName
    }

    public var meta: [Comment] {
        return [
            .empty,
            .comment(filename),
            .empty,
            .comment("Generated automatically."),
            .comment("Copyright © \(organizationName). All rights reserved."),
            .empty
        ]
    }
}
