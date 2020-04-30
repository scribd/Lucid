//
//  Descriptions.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 12/4/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import LucidCodeGen
import PathKit

// MARK: - Descriptions

final class Descriptions: LucidCodeGen.Descriptions {
    
    let subtypes: [Subtype]
    let entities: [Entity]
    let endpoints: [EndpointPayload]
    
    let subtypesByName: [String: Subtype]
    let entitiesByName: [String: Entity]
    let endpointsByName: [String: EndpointPayload]
    
    let persistedEntitiesByName: [String: Entity]
    
    let targets: Targets
    
    private init(subtypes: [Subtype],
                 entities: [Entity],
                 endpoints: [EndpointPayload],
                 targets: Targets) {
        
        self.subtypes = subtypes
        self.entities = entities
        self.endpoints = endpoints
        
        self.subtypesByName = subtypes.reduce(into: [:]) { $0[$1.name] = $1 }
        self.entitiesByName = entities.reduce(into: [:]) { $0[$1.name] = $1 }
        self.endpointsByName = endpoints.reduce(into: [:]) { $0[$1.name] = $1 }
        
        persistedEntitiesByName = entitiesByName
            .values
            .filter { $0.persist }
            .reduce(into: [:]) { $0[$1.name] = $1 }

        self.targets = targets
    }
    
    fileprivate convenience init(_ parser: DescriptionsParser, _ targets: Targets) throws {
        let subtypes: [Subtype] = try parser.parseDescription(.subtypes).sorted { $0.name < $1.name }
        let entities: [Entity] = try (parser.parseDescription(.entities) + parser.parseDescription(.localEntities) + parser.parseDescription(.compositeEntities)).sorted { $0.name < $1.name }
        let endpoints: [EndpointPayload] = try (parser.parseDescription(.endpointPayloads) + parser.parseDescription(.alternateEndpointPayloads)).sorted { $0.name < $1.name }

        self.init(subtypes: subtypes, entities: entities, endpoints: endpoints, targets: targets)
    }
    
    func variant(for platform: Platform) -> Descriptions {
        
        let entities = self.entities
            .filter { $0.platforms.isEmpty || $0.platforms.contains(platform) }
            .map { entity -> Entity in
                var entity = entity
                entity.properties = entity.properties.filter { property in
                    property.platforms.isEmpty || property.platforms.contains(platform)
                }
                return entity
            }
        
        let subtypes = self.subtypes
            .filter { $0.platforms.isEmpty || $0.platforms.contains(platform) }
            .map { subtype -> Subtype in
                var subtype = subtype
                switch subtype.items {
                case .properties(let properties):
                    subtype.items = .properties(properties.filter { property in
                        property.platforms.isEmpty || property.platforms.contains(platform)
                    })
                case .cases,
                     .options:
                    break
                }
                return subtype
            }
        
        let endpoints = self.endpoints.filter { endpoint in
            guard let entity = self.entitiesByName[endpoint.entity.entityName] else {
                return false
            }
            return entity.platforms.isEmpty || entity.platforms.contains(platform)
        }
        
        return Descriptions(
            subtypes: subtypes,
            entities: entities,
            endpoints: endpoints,
            targets: targets
        )
    }

    var platforms: [Platform] {
        return Set(entities.flatMap { $0.platforms + $0.properties.flatMap { $0.platforms } }).sorted()
    }
}

// MARK: - Sequence

extension Descriptions: Sequence {

    typealias Iterator = DescriptionsIterator
    
    func makeIterator() -> DescriptionsIterator {
        return DescriptionsIterator(self)
    }
}

struct DescriptionsIterator: IteratorProtocol {
    
    typealias Element = Description
    
    private let descriptions: Descriptions
    
    private var all = false
    private var subtypeIndex = 0
    private var entityIndex = 0
    private var endpointIndex = 0
    
    fileprivate init(_ descriptions: Descriptions) {
        self.descriptions = descriptions
    }
    
    mutating func next() -> Description? {
        if all == false {
            all = true
            return .all
        } else if subtypeIndex < descriptions.subtypes.count {
            defer { subtypeIndex += 1 }
            return .subtype(descriptions.subtypes[subtypeIndex].name)
        } else if entityIndex < descriptions.entities.count {
            defer { entityIndex += 1 }
            return .entity(descriptions.entities[entityIndex].name)
        } else if endpointIndex < descriptions.endpoints.count {
            defer { endpointIndex += 1 }
            return .endpoint(descriptions.endpoints[endpointIndex].name)
        } else {
            return nil
        }
    }
}

// MARK: - Parser

final class DescriptionsParser {

    private let inputPath: Path
    
    private let targets: TargetConfigurations
    
    private let logger: Logger
    
    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonDecoder
    }()
    
    init(inputPath: Path, targets: TargetConfigurations = TargetConfigurations(), logger: Logger) {
        self.inputPath = inputPath
        self.targets = targets
        self.logger = logger
    }
    
    func parse() throws -> Descriptions {
        logger.moveToChild("Parsing Descriptions.")
        let descriptions = try Descriptions(self, targets)
        logger.moveToParent()
        return descriptions
    }
    
    fileprivate func parseDescription<D: Decodable>(_ directory: OutputDirectory) throws -> [D] {
        
        let directory = directory.path(appModuleName: targets.app.moduleName)
        logger.moveToChild("Parsing \(directory.string).")
        
        let files = (inputPath + directory)
            .glob("*.json")
            .sorted { $0.string < $1.string }
        
        let descriptions: [D] = try files.map { file in
            do {
                let content: Data = try file.read()
                let description = try jsonDecoder.decode(D.self, from: content)
                logger.done("Parsed \(file).")
                return description
            }
        }
        
        logger.moveToParent()
        return descriptions
    }
}

// MARK: - CustomString

extension Description: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .all:
            return "_"
        case .endpoint(let name),
             .entity(let name),
             .subtype(let name):
            return name
        }
    }
}
