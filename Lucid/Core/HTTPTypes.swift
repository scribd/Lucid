//
//  HTTPTypes.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/19/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

// MARK: - ContentType

public enum HTTPContentType: String {
    case textHTML = "text/html"
    case json = "application/json"
    case mpegURL = "application/x-mpegURL"
    case binaryStream = "binary/octet-stream"
}

// MARK: - Methods

public enum HTTPMethod: String, Codable, Equatable {
    case delete
    case get
    case head
    case post
    case put
}
