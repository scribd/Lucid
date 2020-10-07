//
// DiscoverMovieEndpointPayload.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid

// MARK: - Endpoint Payload

public struct DiscoverMovieEndpointPayload {

    let moviePayloads: AnySequence<DefaultEndpointMoviePayload>

    let endpointMetadata: DiscoverMovieMetadata

    var entityMetadata: AnySequence<Optional<MovieMetadata>> {
        return moviePayloads.lazy.map { $0.entityMetadata }.any
    }

    public static var excludedPaths: Array<String> {
        return []
    }
}

// MARK: - Decodable

extension DiscoverMovieEndpointPayload: Decodable {

    private enum Keys: String, CodingKey {
        case results
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        self.moviePayloads = try container.decode(Array<FailableValue<DefaultEndpointMoviePayload>>.self, forKey: .results).lazy.compactMap { $0.value() }.any
        let singleValueContainer = try decoder.singleValueContainer()
        self.endpointMetadata = try singleValueContainer.decode(DiscoverMovieMetadata.self)
    }
}

// MARK: - Metadata

public struct DiscoverMovieMetadata: Decodable, EndpointMetadata {
    public let totalResults: Int

    private enum Keys: String, CodingKey {
        case totalResults
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        totalResults = try container.decode(Int.self, forKey: .totalResults)
    }
}

// MARK: - Accessors

extension DiscoverMovieEndpointPayload {

    var genres: AnySequence<Genre> {
        return Array(arrayLiteral: moviePayloads.lazy.flatMap { $0.rootPayload.genres }.any).joined().any
    }

    var movies: AnySequence<Movie> {
        return Array(arrayLiteral: moviePayloads.lazy.map { Movie(payload: $0.rootPayload) }.any).joined().any
    }
}
