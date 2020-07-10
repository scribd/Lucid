//
//  Movie+Lucid.swift
//  Sample
//
//  Created by Théophane Rupin on 6/12/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import Lucid

public enum MovieQueryContext: Equatable {
    case discover
}

extension Movie {

    public static func requestConfig(for remotePath: RemotePath<Movie>) -> APIRequestConfig? {
        switch remotePath {
        case .get(let identifier, _):
            return APIRequestConfig(method: .get, path: .path("movie") / identifier)
        case .search(let query) where query.context == .discover:
            return APIRequestConfig(
                method: .get,
                path: .path("discover") / "movie",
                query: [("page", .optionalInt(query.page))]
            )
        default:
            return nil
        }
    }

    public static func endpoint(for remotePath: RemotePath<Movie>) -> EndpointResultPayload.Endpoint? {
        switch remotePath {
        case .get:
            return .movie
        case .search(let query) where query.context == .discover:
            return .discoverMovie
        default:
            return nil
        }
    }
}
