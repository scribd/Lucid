//
//  MovieManager.swift
//  Sample
//
//  Created by Théophane Rupin on 6/15/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import Lucid
import Combine

// MARK: - Remote Config

public enum MovieQueryContext: Equatable {
    case discover
}

extension Movie {
    
    public static func requestConfig(for remotePath: RemotePath<Movie>) -> APIRequestConfig? {
        switch remotePath {
        case .get(let identifier):
            return APIRequestConfig(method: .get, path: .path("movie") / identifier)
        case .search(let query) where query.context == .discover:
            return APIRequestConfig(
                method: .get,
                path: .path("discover") / "movie",
                query: [
                    ("page", .value(query.page?.description)),
                    ("order", .value(query.order.first?.requestValue))
                ]
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

// MARK: - Graph

struct MovieGraph {

    let movie: Movie
    
    let genres: [Genre]
    
    fileprivate init?(for movieID: MovieIdentifiable, in graph: EntityGraph) {
        guard let movie = graph.movies[movieID.movieIdentifier] else { return nil }
        self.movie = movie
        genres = movie.genres.value(logError: true)?.compactMap { graph.genres[$0] } ?? []
    }
}

// MARK: - Manager

final class MovieManager {
    
    @Weaver(.reference)
    private var coreManagers: MovieCoreManagerProviding

    init(injecting _: MovieManagerDependencyResolver) {
        // no-op
    }
    
    func movie(for movieID: MovieIdentifiable) -> AnyPublisher<MovieGraph?, ManagerError> {
        let context = ReadContext<Movie>(dataSource: .remoteOrLocal())
        return coreManagers.movieManager
            .rootEntity(byID: movieID.movieIdentifier, in: context)
            .including([.genres])
            .perform()
            .once
            .map { MovieGraph(for: movieID, in: $0) }
            .eraseToAnyPublisher()
    }

    func discoverMovies(at offset: Int = 0) -> AnyPublisher<(movies: [Movie], metadata: DiscoverMovieMetadata?), ManagerError> {
        return coreManagers.movieManager
            .search(
                withQuery: Query(order: [.desc(by: .index(.popularity))], offset: offset, limit: 20, context: .discover),
                in: ReadContext<Movie>(dataSource: .remoteOrLocal(trustRemoteFiltering: true))
            )
            .once
            .map { ($0.array, $0.metadata?.endpoint as? DiscoverMovieMetadata) }
            .eraseToAnyPublisher()
    }
}
