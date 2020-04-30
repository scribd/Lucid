//
//  Metadata.swift
//  Lucid
//
//  Created by Stephane Magne on 2/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

public protocol EntityMetadata {
    func entityIdentifier<ID>() -> ID? where ID: EntityIdentifier
}

public extension EntityMetadata {
    func entityIdentifier<ID>() -> ID? where ID: EntityIdentifier {
        return nil
    }
}

public extension EntityMetadata where Self: EntityIdentifiable {
    func entityIdentifier<ID>() -> ID? where ID: EntityIdentifier {
        return identifier as? ID
    }
}

public protocol EndpointMetadata {}

public struct VoidMetadata: Decodable, EntityMetadata, EndpointMetadata {
    
    public init() {
        // no-op
    }
}

public struct EndpointResultMetadata {
    public let endpoint: EndpointMetadata?
    public let entity: AnySequence<EntityMetadata?>
    
    public init(endpoint: EndpointMetadata?,
                entity: AnySequence<EntityMetadata?>) {
        self.endpoint = endpoint
        self.entity = entity
    }
}

public extension EndpointResultMetadata {
    static var empty: EndpointResultMetadata {
        return EndpointResultMetadata(endpoint: nil, entity: .empty)
    }
}

public struct Metadata<E: Entity> {
    
    private enum Container {
        case array(AnySequence<E.Metadata>)
        case orderedDictionary(OrderedDualHashDictionary<E.Identifier, E.Metadata>)
    }
    
    public let endpoint: EndpointMetadata?
    private let container: Container
    
    private init(endpoint: EndpointMetadata?, container: Container) {
        self.endpoint = endpoint
        self.container = container
    }
}

public extension Metadata {
    
    init(_ metadata: EndpointResultMetadata) {
        endpoint = metadata.endpoint
        container = .array(metadata
            .entity
            .lazy
            .compactMap { $0 }
            .compactMap { $0 as? E.Metadata }
            .any)
    }
    
    var allItems: AnySequence<E.Metadata>? {
        switch container {
        case .array(let array):
            return array
        case .orderedDictionary(let dictionary):
            return dictionary.orderedKeyValues.lazy.map { $0.1 }.any
        }
    }

    var first: E.Metadata? {
        return allItems?.first
    }
}

public extension Metadata where E.Metadata: EntityIdentifiable, E.Identifier == E.Metadata.Identifier {
    
    init(_ metadata: EndpointResultMetadata) {
        endpoint = metadata.endpoint
        container = .orderedDictionary(OrderedDualHashDictionary(
            metadata.entity
                .lazy
                .compactMap { $0 }
                .compactMap { $0 as? E.Metadata }
                .map { ($0.identifier, $0) }
                .any
        ))
    }
    
    func item(for identifier: E.Identifier) -> E.Metadata? {
        switch container {
        case .array(let array):
            return array.first { $0.identifier == identifier }
        case .orderedDictionary(let dictionary):
            return dictionary[identifier]
        }
    }
}

