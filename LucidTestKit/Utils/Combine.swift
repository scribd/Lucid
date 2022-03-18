//
//  Combine.swift
//  LucidTestKit
//
//  Created by Théophane Rupin on 11/5/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Combine
import Foundation

public extension Future {

    convenience init(just output: Output) {
        self.init { fulfill in
            fulfill(.success(output))
        }
    }

    convenience init(failed error: Failure) {
        self.init { fulfill in
            fulfill(.failure(error))
        }
    }
}
