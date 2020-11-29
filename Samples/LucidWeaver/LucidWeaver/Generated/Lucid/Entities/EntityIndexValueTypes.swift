//
// EntityIndexValueTypes.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid

// MARK: - EntityRelationshipIdentifier

public enum EntityRelationshipIdentifier: AnyCoreDataRelationshipIdentifier {
    case genre(GenreIdentifier)
    case movie(MovieIdentifier)
}

// MARK: - Comparable

extension EntityRelationshipIdentifier {

    public static func < (lhs: EntityRelationshipIdentifier,
                          rhs: EntityRelationshipIdentifier) -> Bool {
        switch (lhs, rhs) {
        case (.genre(let lhs), .genre(let rhs)):
            return lhs < rhs
        case (.movie(let lhs), .movie(let rhs)):
            return lhs < rhs
        default:
            return false
        }
    }
}

// MARK: - DualHashable

extension EntityRelationshipIdentifier {

    public func hash(into hasher: inout DualHasher) {
        switch self {
        case .genre(let identifier):
            hasher.combine(identifier)
        case .movie(let identifier):
            hasher.combine(identifier)
        }
    }
}

// MARK: - Conversions

extension EntityRelationshipIdentifier {

    public func toRelationshipID<ID>() -> Optional<ID> where ID : EntityIdentifier {
        switch self {
        case .genre(let genre as ID):
            return genre
        case .genre:
            return nil
        case .movie(let movie as ID):
            return movie
        case .movie:
            return nil
        }
    }

    public var coreDataIdentifierValue: CoreDataRelationshipIdentifierValueType {
        switch self {
        case .genre(let genre):
            return genre.coreDataIdentifierValue
        case .movie(let movie):
            return movie.coreDataIdentifierValue
        }
    }

    public var identifierTypeID: String {
        switch self {
        case .genre(let genre):
            return genre.identifierTypeID
        case .movie(let movie):
            return movie.identifierTypeID
        }
    }

    public static var entityTypeUID: String {
        return ""
    }

    public var entityTypeUID: String {
        switch self {
        case .genre(let genre):
            return genre.entityTypeUID
        case .movie(let movie):
            return movie.entityTypeUID
        }
    }

    public var description: String {
        switch self {
        case .genre(let genre):
            return genre.description
        case .movie(let movie):
            return movie.description
        }
    }
}

// MARK: - EntitySubtype

public enum EntitySubtype: AnyCoreDataSubtype {
}

// MARK: - Conversions

extension EntitySubtype {

    public var predicateValue: Optional<Any> {
        switch self {
        }
    }
}

// MARK: - Comparable

extension EntitySubtype: Comparable {

    public static func < (lhs: EntitySubtype,
                          rhs: EntitySubtype) -> Bool {
        switch (lhs, rhs) {
        default:
            return false
        }
    }
}
