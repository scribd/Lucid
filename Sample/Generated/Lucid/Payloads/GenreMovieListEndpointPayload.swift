//
// GenreMovieListEndpointPayload.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid

// MARK: - Endpoint Read Payload

public struct GenreMovieListEndpointReadPayload {

    let genrePayloads: AnySequence<DefaultEndpointGenrePayload>

    let endpointMetadata: VoidMetadata

    var entityMetadata: AnySequence<Optional<VoidMetadata>> {
        return genrePayloads.lazy.map { $0.entityMetadata }.any
    }

    public static var excludedPaths: Array<String> {
        return []
    }
}

// MARK: - Decodable

extension GenreMovieListEndpointReadPayload: Decodable {

    private enum Keys: String, CodingKey {
        case genres
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        self.genrePayloads = try container.decode(Array<FailableValue<DefaultEndpointGenrePayload>>.self, forKey: .genres).lazy.compactMap { $0.value() }.any
        self.endpointMetadata = VoidMetadata()
    }
}

// MARK: - Accessors

extension GenreMovieListEndpointReadPayload {

    var genres: AnySequence<Genre> {
        return Array(arrayLiteral: genrePayloads.lazy.map { Genre(payload: $0.rootPayload) }.any).joined().any
    }

    var allEntities: AnySequence<AppAnyEntity> {
        let genres = self.genres.map { AppAnyEntity.genre($0) }.any
        return Array(arrayLiteral: genres).joined().any
    }
}
