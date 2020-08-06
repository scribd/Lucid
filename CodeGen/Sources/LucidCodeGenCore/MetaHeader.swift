//
//  MetaHeader.swift
//  LucidCodeGenCore
//
//  Created by Théophane Rupin on 3/20/19.
//

import Meta

public struct MetaHeader {
    
    public let filename: String

    public let companyName: String

    public init(filename: String,
                companyName: String) {
        self.filename = filename
        self.companyName = companyName
    }

    public var meta: [Comment] {
        return [
            .empty,
            .comment(filename),
            .empty,
            .comment("Generated automatically."),
            .comment("Copyright © \(companyName). All rights reserved."),
            .empty
        ]
    }
}
