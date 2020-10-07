//
// MovieEndpointPayload.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid

// MARK: - Endpoint Payload

public struct MovieEndpointPayload {

    let moviePayload: DefaultEndpointMoviePayload

    let endpointMetadata: VoidMetadata

    var entityMetadata: AnySequence<Optional<MovieMetadata>> {
        return Array(arrayLiteral: moviePayload.entityMetadata).lazy.map { $0 }.any
    }

    public static var excludedPaths: Array<String> {
        return []
    }
}

// MARK: - Decodable

extension MovieEndpointPayload: Decodable {

    public init(from decoder: Decoder) throws {
        self.moviePayload = try DefaultEndpointMoviePayload(from: decoder)
        self.endpointMetadata = VoidMetadata()
    }
}

// MARK: - Accessors

extension MovieEndpointPayload {

    var genres: AnySequence<Genre> {
        return Array(arrayLiteral: moviePayload.values().lazy.flatMap { $0.rootPayload.genres }.any).joined().any
    }

    var movies: AnySequence<Movie> {
        return Array(
            arrayLiteral: moviePayload.values().lazy.map { Movie(payload: $0.rootPayload) }.any
        ).joined().any
    }
}
