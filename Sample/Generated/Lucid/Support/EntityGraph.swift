//
// EntityGraph.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid
import Combine

typealias AppRelationshipController = RelationshipController<CoreManagerContainer, EntityGraph>

public enum AppAnyEntity: EntityIndexing, EntityConvertible {
    case genre(Genre)
    case movie(Movie)

    public var entityRelationshipIndices: Array<AppAnyEntityIndexName> {
        switch self {
        case .genre(let entity):
            return entity.entityRelationshipIndices.map { .genre($0) }
        case .movie(let entity):
            return entity.entityRelationshipIndices.map { .movie($0) }
        }
    }

    public func entityIndexValue(for indexName: AppAnyEntityIndexName) -> EntityIndexValue<EntityRelationshipIdentifier, EntitySubtype> {
        switch (self, indexName) {
        case (.genre(let entity), .genre(let indexName)):
            return entity.entityIndexValue(for: indexName)
        case (.movie(let entity), .movie(let indexName)):
            return entity.entityIndexValue(for: indexName)
        default:
            return .none
        }
    }

    public init?<E>(_ entity: E) where E: Entity {
        switch entity {
        case let entity as Genre:
            self = .genre(entity)
        case let entity as Movie:
            self = .movie(entity)
        default:
            return nil
        }
    }

    public var description: String {
        switch self {
        case .genre(let entity):
            return entity.identifier.description
        case .movie(let entity):
            return entity.identifier.description
        }
    }
}

extension Sequence where Element: Entity {
    var anyEntities: Array<AppAnyEntity> {
        return compactMap(AppAnyEntity.init)
    }
}

public enum AppAnyEntityIndexName: Hashable, QueryResultConvertible {
    case genre(Genre.IndexName)
    case movie(Movie.IndexName)

    public var requestValue: String {
        switch self {
        case .genre(let index):
            return index.requestValue
        case .movie(let index):
            return index.requestValue
        }
    }
}

final class EntityGraph: MutableGraph {

    typealias AnyEntity = AppAnyEntity

    let isDataRemote: Bool

    private(set) var rootEntities: Array<AppAnyEntity>

    private(set) var _metadata: Optional<EndpointResultMetadata>
    private(set) var genres = OrderedDualHashDictionary<GenreIdentifier, Genre>()
    private(set) var movies = OrderedDualHashDictionary<MovieIdentifier, Movie>()

    convenience init() { self.init(isDataRemote: false) }

    convenience init<P>(context: _ReadContext<P>) where P: ResultPayloadConvertible { self.init(isDataRemote: context.responseHeader != nil) }

    private init(isDataRemote: Bool) {
        self.isDataRemote = isDataRemote
        self.rootEntities = []
        self._metadata = nil
    }

    func setRoot<S>(_ entities: S) where S: Sequence, S.Element == AppAnyEntity { rootEntities = entities.array }

    func insert<S>(_ entities: S) where S: Sequence, S.Element == AppAnyEntity {
        entities.forEach {
            switch $0 {
            case .genre(let entity):
                genres[entity.identifier] = entity
            case .movie(let entity):
                movies[entity.identifier] = movies[entity.identifier].flatMap { $0.merging(entity) } ?? entity
            }
        }
    }

    func contains(_ identifier: AnyRelationshipIdentifierConvertible) -> Bool {
        switch identifier as? EntityRelationshipIdentifier {
        case .genre(let identifier):
            return genres[identifier] != nil
        case .movie(let identifier):
            return movies[identifier] != nil
        case .none:
            return false
        }
    }

    func setEndpointResultMetadata(_ metadata: EndpointResultMetadata) { _metadata = metadata }

    func metadata<E>() -> Optional<Metadata<E>> where E : Entity { return _metadata.map { Metadata<E>($0) } }

    var entities: AnySequence<AppAnyEntity> {
        let genres = self.genres.lazy.elements.map { AppAnyEntity.genre($0.1) }.any
        let movies = self.movies.lazy.elements.map { AppAnyEntity.movie($0.1) }.any
        return Array(arrayLiteral: genres, movies).joined().any
    }

    func append(_ otherGraph: EntityGraph) {
        rootEntities.append(contentsOf: otherGraph.rootEntities)
        insert(otherGraph.entities)
    }
}

extension RelationshipController.RelationshipQuery where Graph == EntityGraph {
    func perform() -> (once: AnyPublisher<EntityGraph, ManagerError>, continuous: AnyPublisher<EntityGraph, ManagerError>) {
        let publishers = perform(EntityGraph.self)
        return (
            publishers.once.map { $0 as EntityGraph }.eraseToAnyPublisher(),
            publishers.continuous.map { $0 as EntityGraph }.eraseToAnyPublisher()
        )
    }
}
