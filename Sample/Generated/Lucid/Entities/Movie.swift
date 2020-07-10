//
// Movie.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid
import CoreData

// MARK: - Identifier

public final class MovieIdentifier: Codable, CoreDataIdentifier, RemoteIdentifier {

    public typealias LocalValueType = String
    public typealias RemoteValueType = Int

    public let _remoteSynchronizationState: PropertyBox<RemoteSynchronizationState>

    fileprivate let property: PropertyBox<IdentifierValueType<String, Int>>
    public var value: IdentifierValueType<String, Int> {
        return property.value
    }

    public static let entityTypeUID = "movie"
    public let identifierTypeID: String

    public init(from decoder: Decoder) throws {
        _remoteSynchronizationState = PropertyBox(.synced, atomic: false)
        switch decoder.context {
        case .payload, .clientQueueRequest:
            let container = try decoder.singleValueContainer()
            property = PropertyBox(try container.decode(IdentifierValueType<String, Int>.self), atomic: false)
            identifierTypeID = Movie.identifierTypeID
        case .coreDataRelationship:
            let container = try decoder.container(keyedBy: EntityIdentifierCodingKeys.self)
            property = PropertyBox(
                try container.decode(IdentifierValueType<String, Int>.self, forKey: .value),
                atomic: false
            )
            identifierTypeID = try container.decode(String.self, forKey: .identifierTypeID)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch encoder.context {
        case .payload, .clientQueueRequest:
            var container = encoder.singleValueContainer()
            try container.encode(property.value)
        case .coreDataRelationship:
            var container = encoder.container(keyedBy: EntityIdentifierCodingKeys.self)
            try container.encode(property.value, forKey: .value)
            try container.encode(identifierTypeID, forKey: .identifierTypeID)
        }
    }

    public convenience init(value: IdentifierValueType<String, Int>,
                            identifierTypeID: Optional<String> = nil,
                            remoteSynchronizationState: Optional<RemoteSynchronizationState> = nil) {
        self.init(
            value: value,
            identifierTypeID: identifierTypeID,
            remoteSynchronizationState: remoteSynchronizationState ?? .synced
        )
    }

    public init(value: IdentifierValueType<String, Int>,
                identifierTypeID: Optional<String>,
                remoteSynchronizationState: RemoteSynchronizationState) {
        property = PropertyBox(value, atomic: false)
        self.identifierTypeID = identifierTypeID ?? Movie.identifierTypeID
        self._remoteSynchronizationState = PropertyBox(remoteSynchronizationState, atomic: false)
    }

    public static func == (_ lhs: MovieIdentifier,
                           _ rhs: MovieIdentifier) -> Bool { return lhs.value == rhs.value && lhs.identifierTypeID == rhs.identifierTypeID }

    public func hash(into hasher: inout DualHasher) {
        hasher.combine(value)
        hasher.combine(identifierTypeID)
    }

    public var description: String {
        return "\(identifierTypeID):\(value.description)"
    }
}

// MARK: - Identifiable

public protocol MovieIdentifiable {
    var movieIdentifier: MovieIdentifier { get }
}

extension MovieIdentifier: MovieIdentifiable {
    public var movieIdentifier: MovieIdentifier {
        return self
    }
}

// MARK: - Movie

public final class Movie: Codable {

    public typealias Metadata = MovieMetadata
    public typealias ResultPayload = EndpointResultPayload
    public typealias RelationshipIdentifier = EntityRelationshipIdentifier
    public typealias Subtype = EntitySubtype
    public typealias QueryContext = MovieQueryContext

    // IdentifierTypeID
    public static let identifierTypeID = "movie"

    // identifier
    public let identifier: MovieIdentifier

    // properties
    public let overview: String

    public let popularity: Double

    public let posterPath: URL

    public let title: String

    // relationships
    public let genres: Extra<AnySequence<GenreIdentifier>>

    init(identifier: MovieIdentifiable,
         overview: String,
         popularity: Double,
         posterPath: URL,
         title: String,
         genres: Extra<AnySequence<GenreIdentifier>>) {

        self.identifier = identifier.movieIdentifier
        self.overview = overview
        self.popularity = popularity
        self.posterPath = posterPath
        self.title = title
        self.genres = genres
    }
}

// MARK: - MoviePayload Initializer

extension Movie {
    convenience init(payload: MoviePayload) {
        self.init(
            identifier: payload.identifier,
            overview: payload.overview,
            popularity: payload.popularity,
            posterPath: payload.posterPath,
            title: payload.title,
            genres: payload.genrePayloads.identifiers()
        )
    }
}

// MARK: - LocalEntiy, RemoteEntity

extension Movie: LocalEntity, RemoteEntity {

    public typealias ExtrasIndexName = MovieExtrasIndexName

    public func entityIndexValue(for indexName: MovieIndexName) -> EntityIndexValue<EntityRelationshipIdentifier, EntitySubtype> {
        switch indexName {
        case .genres:
            return genres.extraValue().flatMap { (genres) in .optional(.array(genres.lazy.map { .relationship(.genre($0)) }.any)) } ?? .none
        case .overview:
            return .string(overview)
        case .popularity:
            return .double(popularity)
        case .posterPath:
            return .url(posterPath)
        case .title:
            return .string(title)
        }
    }

    public var entityRelationshipIndices: Array<MovieIndexName> {
        return [.genres]
    }

    public var entityRelationshipEntityTypeUIDs: Array<String> {
        return [GenreIdentifier.entityTypeUID]
    }

    public static func == (lhs: Movie,
                           rhs: Movie) -> Bool {
        guard lhs.overview == rhs.overview else {
            return false
        }
        guard lhs.popularity == rhs.popularity else {
            return false
        }
        guard lhs.posterPath == rhs.posterPath else {
            return false
        }
        guard lhs.title == rhs.title else {
            return false
        }
        guard lhs.genres == rhs.genres else {
            return false
        }
        return true
    }
}

// MARK: - CoreDataIndexName

extension MovieIndexName: CoreDataIndexName {

    public var predicateString: String {
        switch self {
        case .genres:
            return "_genres"
        case .overview:
            return "_overview"
        case .popularity:
            return "_popularity"
        case .posterPath:
            return "_poster_path"
        case .title:
            return "_title"
        }
    }

    public var isOneToOneRelationship: Bool {
        switch self {
        case .genres:
            return false
        case .overview:
            return false
        case .popularity:
            return false
        case .posterPath:
            return false
        case .title:
            return false
        }
    }

    public var identifierTypeIDRelationshipPredicateString: Optional<String> {
        switch self {
        case .genres:
            return nil
        case .overview:
            return nil
        case .popularity:
            return nil
        case .posterPath:
            return nil
        case .title:
            return nil
        }
    }
}

// MARK: - CoreDataEntity

extension Movie: CoreDataEntity {

    public static func entity(from coreDataEntity: ManagedMovie_1_0_0) -> Optional<Movie> {
        do {
            return try Movie(coreDataEntity: coreDataEntity)
        } catch {
            Logger.log(.error, "\(Movie.self): \(error)", domain: "Lucid", assert: true)
            return nil
        }
    }

    public func merge(into coreDataEntity: ManagedMovie_1_0_0) {
        coreDataEntity.setProperty(MovieIdentifier.remotePredicateString, value: identifier.remoteCoreDataValue())
        coreDataEntity.setProperty(MovieIdentifier.localPredicateString, value: identifier.localCoreDataValue())
        coreDataEntity.__type_uid = identifier.identifierTypeID
        coreDataEntity._remote_synchronization_state = identifier._remoteSynchronizationState.value.coreDataValue()
        coreDataEntity._overview = overview.coreDataValue()
        coreDataEntity._popularity = popularity.coreDataValue()
        coreDataEntity._poster_path = posterPath.coreDataValue()
        coreDataEntity._title = title.coreDataValue()
        coreDataEntity._genres = genres.extraValue().coreDataValue()
        coreDataEntity.setProperty("__genres_extra_flag", value: genres.coreDataFlagValue)
    }

    private convenience init(coreDataEntity: ManagedMovie_1_0_0) throws {
        self.init(
            identifier: try coreDataEntity.identifierValueType(
                MovieIdentifier.self,
                identifierTypeID: coreDataEntity.__type_uid,
                remoteSynchronizationState: coreDataEntity._remote_synchronization_state?.synchronizationStateValue
            ),
            overview: try coreDataEntity._overview.stringValue(propertyName: "_overview"),
            popularity: coreDataEntity._popularity.doubleValue(),
            posterPath: try coreDataEntity._poster_path.urlValue(propertyName: "_posterPath"),
            title: try coreDataEntity._title.stringValue(propertyName: "_title"),
            genres: try Extra(
                value: coreDataEntity._genres.genreArrayValue(),
                requested: coreDataEntity.boolValue(propertyName: "__genres_extra_flag")
            )
        )
    }
}

// MARK: - Cross Entities CoreData Conversion Utils

extension Data {
    func movieArrayValue() -> Optional<AnySequence<MovieIdentifier>> {
        guard let values: AnySequence<IdentifierValueType<String, Int>> = identifierValueTypeArrayValue(MovieIdentifier.self) else {
            return nil
        }
        return values.lazy.map { MovieIdentifier(value: $0) }.any
    }
}

extension Optional where Wrapped == Data {
    func movieArrayValue(propertyName: String) throws -> AnySequence<MovieIdentifier> {
        guard let values = self?.movieArrayValue() else {
            throw CoreDataConversionError.corruptedProperty(name: propertyName)
        }
        return values
    }

    func movieArrayValue() -> Optional<AnySequence<MovieIdentifier>> { return self?.movieArrayValue() }
}

// MARK: - Entity Merging

extension Movie {
    public func merging(_ updated: Movie) -> Movie {
        return Movie(
            identifier: updated.identifier,
            overview: updated.overview,
            popularity: updated.popularity,
            posterPath: updated.posterPath,
            title: updated.title,
            genres: genres.merging(with: updated.genres)
        )
    }
}

// MARK: - IndexName

public enum MovieIndexName {
    case genres
    case overview
    case popularity
    case posterPath
    case title
}

extension MovieIndexName: QueryResultConvertible {
    public var requestValue: String {
        switch self {
        case .genres:
            return "genres"
        case .overview:
            return "overview"
        case .popularity:
            return "popularity"
        case .posterPath:
            return "poster_path"
        case .title:
            return "title"
        }
    }
}

// MARK: - ExtrasIndexName

public indirect enum MovieExtrasIndexName: Hashable {
    case genres
}

extension MovieExtrasIndexName: RemoteEntityExtrasIndexName {
    public var requestValue: String {
        switch self {
        case .genres:
            return "genres"
        }
    }
}

extension Movie {

    public static var shouldValidate: Bool {
        return true
    }

    public func isEntityValid(for query: Query<Movie>) -> Bool {
        guard let requestedExtras = query.extras else { return true }

        for requestedExtra in requestedExtras {
            switch requestedExtra {
            case .genres:
                if genres.wasRequested == false { return false }
            }
        }

        return true
    }
}
