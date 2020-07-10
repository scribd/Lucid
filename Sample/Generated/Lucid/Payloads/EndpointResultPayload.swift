//
// EndpointResultPayload.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid

public final class EndpointResultPayload: ResultPayloadConvertible {

    // MARK: - Content

    public enum Endpoint {
        case discoverMovie
        case genreMovieList
        case movie
    }

    // MARK: - Precached Entities

    public let genres: OrderedDualHashDictionary<GenreIdentifier, Genre>
    public let movies: OrderedDualHashDictionary<MovieIdentifier, Movie>

    // MARK: - Metadata

    public let metadata: EndpointResultMetadata

    // MARK: - Init

    public init(from data: Data,
                endpoint: Endpoint,
                decoder: JSONDecoder) throws {

        switch endpoint {
        case .discoverMovie:
            let payload = try decoder.decode(DiscoverMovieEndpointPayload.self, from: data)
            genres = payload.genres.byIdentifier
            movies = payload.movies.byIdentifier
            metadata = EndpointResultMetadata(
                endpoint: payload.endpointMetadata,
                entity: payload.entityMetadata.lazy.map { $0 as Optional<EntityMetadata> }.any
            )
        case .genreMovieList:
            let payload = try decoder.decode(GenreMovieListEndpointPayload.self, from: data)
            genres = payload.genres.byIdentifier
            movies = OrderedDualHashDictionary()
            metadata = EndpointResultMetadata(
                endpoint: payload.endpointMetadata,
                entity: payload.entityMetadata.lazy.map { $0 as Optional<EntityMetadata> }.any
            )
        case .movie:
            let payload = try decoder.decode(MovieEndpointPayload.self, from: data)
            genres = payload.genres.byIdentifier
            movies = payload.movies.byIdentifier
            metadata = EndpointResultMetadata(
                endpoint: payload.endpointMetadata,
                entity: payload.entityMetadata.lazy.map { $0 as Optional<EntityMetadata> }.any
            )
        }
    }

    public func getEntity<E>(for identifier: E.Identifier) -> Optional<E> where E : Entity {

        switch identifier {
        case let entityIdentifier as GenreIdentifier:
            return genres[entityIdentifier] as? E
        case let entityIdentifier as MovieIdentifier:
            return movies[entityIdentifier] as? E
        default:
            return nil
        }
    }

    public func allEntities<E>() -> AnySequence<E> where E : Entity {

        switch E.self {
        case is Genre.Type:
            return genres.orderedKeyValues.map { $0.1 }.any as? AnySequence<E> ?? [].any
        case is Movie.Type:
            return movies.orderedKeyValues.map { $0.1 }.any as? AnySequence<E> ?? [].any
        default:
            return [].any
        }
    }
}
