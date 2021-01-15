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

        var genres = OrderedDualHashDictionary<GenreIdentifier, Genre>(optimizeWriteOperation: true)
        var movies = OrderedDualHashDictionary<MovieIdentifier, Movie>(optimizeWriteOperation: true)
        let entities: AnySequence<AppAnyEntity>

        switch endpoint {
        case .discoverMovie:
            decoder.setExcludedPaths(DiscoverMovieEndpointReadPayload.excludedPaths)
            let payload = try decoder.decode(DiscoverMovieEndpointReadPayload.self, from: data)
            entities = payload.allEntities
            metadata = EndpointResultMetadata(
                endpoint: payload.endpointMetadata,
                entity: payload.entityMetadata.lazy.map { $0 as Optional<EntityMetadata> }.any
            )
        case .genreMovieList:
            decoder.setExcludedPaths(GenreMovieListEndpointReadPayload.excludedPaths)
            let payload = try decoder.decode(GenreMovieListEndpointReadPayload.self, from: data)
            entities = payload.allEntities
            metadata = EndpointResultMetadata(
                endpoint: payload.endpointMetadata,
                entity: payload.entityMetadata.lazy.map { $0 as Optional<EntityMetadata> }.any
            )
        case .movie:
            decoder.setExcludedPaths(MovieEndpointReadPayload.excludedPaths)
            let payload = try decoder.decode(MovieEndpointReadPayload.self, from: data)
            entities = payload.allEntities
            metadata = EndpointResultMetadata(
                endpoint: payload.endpointMetadata,
                entity: payload.entityMetadata.lazy.map { $0 as Optional<EntityMetadata> }.any
            )
        }

        for entity in entities {
            switch entity {
            case .genre(let value):
                genres[value.identifier] = value
            case .movie(let value):
                movies[value.identifier] = value
            }
        }

        self.genres = genres
        self.movies = movies
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
            return genres.orderedValues.any as? AnySequence<E> ?? [].any
        case is Movie.Type:
            return movies.orderedValues.any as? AnySequence<E> ?? [].any
        default:
            return [].any
        }
    }
}
