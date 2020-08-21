//
// MoviePayloads.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid

final class MoviePayload: ArrayConvertable {

    // identifier
    let id: Int

    // properties
    let overview: String
    let popularity: Double
    let posterPath: URL
    let title: String

    // relationships
    let genrePayloads: Lazy<AnySequence<PayloadRelationship<DefaultEndpointGenrePayload>>>

    init(id: Int,
         overview: String,
         popularity: Double,
         posterPath: URL,
         title: String,
         genrePayloads: Lazy<AnySequence<PayloadRelationship<DefaultEndpointGenrePayload>>>) {

        self.id = id
        self.overview = overview
        self.popularity = popularity
        self.posterPath = posterPath
        self.title = title
        self.genrePayloads = genrePayloads
    }
}

extension MoviePayload: PayloadIdentifierDecodableKeyProvider {

    static let identifierKey = "id"
    var identifier: MovieIdentifier {
        return MovieIdentifier(value: .remote(id, nil))
    }
}

// MARK: - Metadata

public final class MovieMetadata: Decodable, EntityMetadata {

    public let id: Int

    private enum Keys: CodingKey {
        case id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        id = try container.decode(Int.self, forKey: .id, defaultValue: nil, logError: true)
    }
}

extension MovieMetadata: EntityIdentifiable {

    public var identifier: MovieIdentifier {
        return MovieIdentifier(value: .remote(id, nil))
    }
}

// MARK: - Default Endpoint Payload

final class DefaultEndpointMoviePayload: Decodable, PayloadConvertable, ArrayConvertable {

    let rootPayload: MoviePayload
    let entityMetadata: Optional<MovieMetadata>

    private enum Keys: String, CodingKey {
        case id
        case overview
        case popularity
        case posterPath
        case title
        case genres
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let rootPayload = MoviePayload(
            id: try container.decode(Int.self, forKey: .id, defaultValue: nil, logError: true),
            overview: try container.decode(String.self, forKeys: [.overview], defaultValue: nil, logError: true),
            popularity: try container.decode(Double.self, forKeys: [.popularity], defaultValue: nil, logError: true),
            posterPath: try container.decode(URL.self, forKeys: [.posterPath], defaultValue: nil, logError: true),
            title: try container.decode(String.self, forKeys: [.title], defaultValue: nil, logError: true),
            genrePayloads: try container.decodeSequence(
                AnySequence<DefaultEndpointGenrePayload>.self,
                forKeys: [.genres],
                logError: true
            )
        )
        let entityMetadata = try FailableValue<MovieMetadata>(from: decoder).value()
        self.rootPayload = rootPayload
        self.entityMetadata = entityMetadata
    }
}

extension DefaultEndpointMoviePayload: PayloadIdentifierDecodableKeyProvider {

    static let identifierKey = MoviePayload.identifierKey
    var identifier: MovieIdentifier {
        return rootPayload.identifier
    }
}

// MARK: - Relationship Entities Accessors

extension MoviePayload {
    var genres: AnySequence<Genre> {
        let genrePayloads = self.genrePayloads.extraValue().values().lazy.map { Genre(payload: $0.rootPayload) }.any
        return Array(arrayLiteral: genrePayloads).joined().any
    }
}
