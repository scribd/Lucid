//
//  RequestConfig.swift
//  Sample
//
//  Created by Théophane Rupin on 6/18/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import Lucid

extension Query.Order {
    var requestValue: String? {
        switch self {
        case .asc(let property):
            return "\(property.requestValue).asc"
        case .desc(let property):
            return "\(property.requestValue).desc"
        case .identifiers,
             .natural:
            return nil
        }
    }
}

extension Query {
    var page: Int? {
        return offset.flatMap { offset in
            return limit.flatMap { limit in
                guard limit != 0 else { return nil }
                return (offset / limit) + 1
            }
        }
    }
}
