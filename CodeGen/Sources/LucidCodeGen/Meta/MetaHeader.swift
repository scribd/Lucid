//
//  Header.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 3/20/19.
//

import Meta
import LucidCodeGenCore

struct MetaHeader {
    
    let filename: String
    
    var meta: [Comment] {
        return [
            .empty,
            .comment(filename),
            .empty,
            .comment("Generated automatically."),
            .comment("Copyright © Scribd. All rights reserved."),
            .empty
        ]
    }
}
