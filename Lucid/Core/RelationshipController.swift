//
//  RelationshipController.swift
//  Lucid
//
//  Created by Théophane Rupin on 1/31/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Combine
import Foundation

private enum Constants {
    static let isDebugModeOn = ProcessInfo.processInfo.environment["RELATIONSHIP_CONTROLLER_DEBUG"] == "1"
    static let processingIntervalThreshold: TimeInterval = 0.5
}

public protocol RelationshipPathConvertible {

    associatedtype AnyEntity: EntityIndexing

    var paths: [[AnyEntity.IndexName]] { get }
}

/// Mutable graph object
public protocol MutableGraph: AnyObject {

    associatedtype AnyEntity: EntityIndexing, EntityConvertible

    /// Initialize an empty graph
    init()

    /// Initialize an empty graph from a context
    /// - Parameter context: The read context use to build the request. The header response will be tested to see if the data is remote or not.
    init<P>(context: _ReadContext<P>) where P: ResultPayloadConvertible

    /// Set root entities
    /// - Parameter entities: entities to set
    func setRoot<S>(_ entities: S) where S: Sequence, S.Element == AnyEntity

    /// Insert any entities
    /// - Parameter entities: entities to insert
    func insert<S>(_ entities: S) where S: Sequence, S.Element == AnyEntity

    /// Indicates if the given entity identifier is contained in the graph or not.
    /// - Parameter entity: entity identifier to check on.
    func contains(_ identifier: AnyRelationshipIdentifierConvertible) -> Bool

    /// Set the metadata related to the Entity object
    /// - Parameter metadata: the `EndpointResultMetadata` object
    func setEndpointResultMetadata(_ metadata: EndpointResultMetadata)

    /// Returns the metadata if available
    /// - Returns (optional) the requested `Metadata<E>` if available
    func metadata<E>() -> Metadata<E>? where E: Entity
}

/// Core manager able to retrieve relationship entities out of any relationship identifiers
public protocol RelationshipCoreManaging: AnyObject {

    associatedtype AnyEntity: EntityConvertible

    associatedtype ResultPayload: ResultPayloadConvertible

    /// Retrieve any relationship entity out of any relationship identifiers.
    ///
    /// - Parameters:
    ///   - identifiers: any relationship identifiers
    ///   - entityType: type of entity
    ///   - context: context used for fetching
    /// - Returns: A signal of any entities
    /// - Warning: Does not ensure ordering the result data set.
    func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
             entityType: String,
             in context: _ReadContext<ResultPayload>) -> AnyPublisher<AnySequence<AnyEntity>, ManagerError>
}

extension RelationshipCoreManaging {

    public typealias ReadContext = _ReadContext<ResultPayload>
}

/// ThreadSafeWrapper for a graph.
public final class ThreadSafeGraph<Graph>: MutableGraph where Graph: MutableGraph {

    public typealias AnyEntity = Graph.AnyEntity

    private let dispatchQueue = DispatchQueue(label: "\(ThreadSafeGraph.self)")

    private let _value: Graph

    private let createdAt = Date()

    private var _dates = [Set<String>: (requested: Date, inserted: Date?)]()
    private var _rootKey = Set<String>()

    public var value: Graph {
        return dispatchQueue.sync { _value }
    }

    public init() {
        _value = Graph()
    }

    public init<P>(context: _ReadContext<P>) where P: ResultPayloadConvertible {
        _value = Graph(context: context)
    }

    public func setRoot<S>(_ entities: S) where S: Sequence, Graph.AnyEntity == S.Element {
        dispatchQueue.async {
            if Constants.isDebugModeOn {
                self._rootKey = Set(entities.map { $0.description })
            }
            self._value.setRoot(entities)
        }
    }

    public func insert<S>(_ entities: S) where S: Sequence, Graph.AnyEntity == S.Element {
        dispatchQueue.async {
            if Constants.isDebugModeOn {
                let key = Set(entities.map { $0.description })
                if key != self._rootKey {
                    var dates = self._dates[key] ?? (self.createdAt, nil)
                    dates.inserted = Date()
                    self._dates[key] = dates
                }
            }
            self._value.insert(entities)
        }
    }

    public func contains(_ identifier: AnyRelationshipIdentifierConvertible) -> Bool {
        return dispatchQueue.sync { _value.contains(identifier) }
    }

    public func setEndpointResultMetadata(_ metadata: EndpointResultMetadata) {
        dispatchQueue.async {
            self._value.setEndpointResultMetadata(metadata)
        }
    }

    public func metadata<E>() -> Metadata<E>? where E : Entity {
        dispatchQueue.sync {
            return self._value.metadata()
        }
    }

    fileprivate func filterOutContainedIDs(of identifiers: [AnyRelationshipIdentifierConvertible]) -> [AnyRelationshipIdentifierConvertible] {
        return dispatchQueue.sync {
            let identifiers = identifiers.filter { identifier in
                _value.contains(identifier) == false
            }

            if Constants.isDebugModeOn {
                let key = Set(identifiers.map { $0.description })
                self._dates[key] = (Date(), nil)
            }

            return identifiers
        }
    }

    fileprivate func logPerformanceAnomaly(prefix: String) {
        guard Constants.isDebugModeOn else { return }

        let dates = dispatchQueue.sync { _dates }
        guard dates.isEmpty == false else { return }

        let intervals: [(
            identifiers: Set<String>,
            interval: TimeInterval
        )] = dates.compactMap { identifiers, dates in
            if let interval = dates.inserted?.timeIntervalSince(dates.requested) {
                return (identifiers, interval)
            } else {
                return nil
            }
        }

        let abnormalIntervals = intervals.filter { $0.interval > Constants.processingIntervalThreshold }

        for (identifiers, interval) in abnormalIntervals {
            Logger.log(.error, "\(prefix): Detected abnormaly long fetch: \(interval)s: \(identifiers.sorted())")
        }

        if abnormalIntervals.isEmpty == false {
            Logger.log(.error, "\(prefix): Detected abnormaly long fetch(es) while building graph, most likely caused by a local store bottleneck or an unwanted remote fetch.", assert: true)
        }
    }
}

/// Util object able to retrieve relationships from a set of root entities
public final class RelationshipController<RelationshipManager, Graph>
    where Graph: MutableGraph, RelationshipManager: RelationshipCoreManaging, Graph.AnyEntity == RelationshipManager.AnyEntity {

    public typealias ReadContext = RelationshipManager.ReadContext

    private let rootEntities: AnyPublisher<AnySequence<Graph.AnyEntity>, ManagerError>

    private let relationshipContext: ReadContext

    private let relationshipManager: RelationshipManager?

    private let relationshipFetcher: RelationshipFetcher

    public init(rootEntities: AnyPublisher<AnySequence<Graph.AnyEntity>, ManagerError>,
                relationshipContext: ReadContext,
                relationshipManager: RelationshipManager?,
                relationshipFetcher: RelationshipFetcher = .none) {

        self.rootEntities = rootEntities
        self.relationshipManager = relationshipManager
        self.relationshipFetcher = relationshipFetcher
        self.relationshipContext = relationshipContext

        if relationshipManager == nil {
           Logger.log(.error, "\(RelationshipController.self): \(RelationshipManager.self) is nil. The controller won't work correctly.", assert: true)
        }
    }

    public convenience init<E>(rootEntities: AnyPublisher<AnySequence<E>, ManagerError>,
                               relationshipContext: ReadContext,
                               relationshipManager: RelationshipManager,
                               relationshipFetcher: RelationshipFetcher = .none)
        where E: Entity, E.ResultPayload == RelationshipManager.ResultPayload {

            self.init(rootEntities: rootEntities.map { $0.lazy.compactMap { Graph.AnyEntity($0) }.any }.eraseToAnyPublisher(),
                      relationshipContext: relationshipContext,
                      relationshipManager: relationshipManager,
                      relationshipFetcher: relationshipFetcher)
    }

    private func _buildGraph() -> AnyPublisher<Graph, ManagerError> {

        let createdAt = Date()
        Logger.log(.debug, "\(RelationshipController.self): Creating graph for \(relationshipContext).")

        let graph = ThreadSafeGraph<Graph>(context: self.relationshipContext)
        return self.fill(graph, nestedContext: self.relationshipContext).flatMap { _ -> AnyPublisher<Graph, ManagerError> in
            let processingInterval = Date().timeIntervalSince(createdAt)

            Logger.log(.debug, "\(RelationshipController.self): Took \(processingInterval)s to build graph for \(self.relationshipContext.debugDescription).")
            if self.relationshipContext.remoteContextAfterMakingLocalRequest != nil {
                graph.logPerformanceAnomaly(prefix: "\(RelationshipController.self)")
            }

            return Just<Graph>(graph.value).setFailureType(to: ManagerError.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    public func buildGraph() -> AnyPublisher<Graph, ManagerError> {
        return _buildGraph().eraseToAnyPublisher()
    }

    public func fill(_ graph: ThreadSafeGraph<Graph>, nestedContext: ReadContext, path: [Graph.AnyEntity.IndexName] = []) -> AnyPublisher<Void, ManagerError> {

        return rootEntities.flatMap { (entities: AnySequence<Graph.AnyEntity>) -> AnyPublisher<Void, ManagerError>  in
            let entities = entities.array

            if path.isEmpty {
                graph.setRoot(entities)
                if let endpointResultMetadata = nestedContext.endpointResultMetadata {
                    graph.setEndpointResultMetadata(endpointResultMetadata)
                }
            }
            graph.insert(entities)

            let relationshipIdentifiersByIndex: [Graph.AnyEntity.IndexName: [AnyRelationshipIdentifierConvertible]] = entities.reduce(into: [:]) { identifiersByIndex, entity in
                for relationshipIndex in entity.entityRelationshipIndices {
                    var identifiers = identifiersByIndex[relationshipIndex] ?? []
                    identifiers.append(contentsOf: entity.entityIndexValue(for: relationshipIndex).toRelationshipTypeIdentifiers)
                    identifiersByIndex[relationshipIndex] = identifiers
                }
            }

            guard relationshipIdentifiersByIndex.isEmpty == false else {
                return Just<Void>(()).setFailureType(to: ManagerError.self).eraseToAnyPublisher()
            }

            let graphAtCurrentDepth = graph.value

            return Publishers.MergeMany(
                relationshipIdentifiersByIndex.keys.sorted { "\($0)" < "\($1)" }
                    .compactMap { indexName -> AnyPublisher<Void, ManagerError>? in
                        guard let _identifiers = relationshipIdentifiersByIndex[indexName] else { return nil }
                        let identifiers = graph.filterOutContainedIDs(of: _identifiers)

                        let pathAtCurrentDepth = path + [indexName]
                        let depth = pathAtCurrentDepth.count

                        let automaticallyFetchRelationships = { (
                            identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
                            recursiveMethod: RelationshipFetcher.RecursiveMethod,
                            context: ReadContext
                        ) -> AnyPublisher<Void, ManagerError> in

                            // Identifiers should all have the same type at this point
                            guard let entityTypeUID = identifiers.first?.entityTypeUID else {
                                return Just<Void>(()).setFailureType(to: ManagerError.self).eraseToAnyPublisher()
                            }

                            let updatedContext = context.updateForRelationshipController(at: pathAtCurrentDepth, graph: graphAtCurrentDepth, deltaStrategy: .retainExtraLocalData)

                            let entities = self.relationshipManager?.get(
                                byIDs: identifiers,
                                entityType: entityTypeUID,
                                in: updatedContext
                            ) ?? Just([].any).setFailureType(to: ManagerError.self).eraseToAnyPublisher()

                            let recurse = {
                                return RelationshipController(
                                    rootEntities: entities,
                                    relationshipContext: context,
                                    relationshipManager: self.relationshipManager,
                                    relationshipFetcher: self.relationshipFetcher
                                ).fill(graph, nestedContext: updatedContext, path: pathAtCurrentDepth)
                            }

                            let globalDepthLimit = LucidConfiguration.relationshipControllerMaxRecursionDepth

                            switch recursiveMethod {
                            case .depthLimit(let limit) where depth < limit && depth < globalDepthLimit:
                                return recurse()

                            case .full where depth < globalDepthLimit:
                                return recurse()

                            case .none,
                                 .depthLimit,
                                 .full:
                                if depth >= globalDepthLimit {
                                    Logger.log(.error, "\(RelationshipController.self): Recursion depth limit (\(globalDepthLimit)) has been reached.", assert: true)
                                }
                                return entities.map { entities in
                                    graph.insert(entities)
                                }
                                .eraseToAnyPublisher()
                            }
                        }

                        switch self.relationshipFetcher.fetch(pathAtCurrentDepth, identifiers.any, graph) {
                        case .custom(let publisher):
                            return publisher
                        case .all(let recursive, let context):
                            return automaticallyFetchRelationships(identifiers.any, recursive, context ?? nestedContext)
                        case .filtered(let identifiers, let recursive, let context):
                            return automaticallyFetchRelationships(identifiers.any, recursive, context ?? nestedContext)
                        case .none:
                            return Just<Void>(()).setFailureType(to: ManagerError.self).eraseToAnyPublisher()
                        }
                }
            )
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - RelationshipFetcher

public extension RelationshipController {

    struct RelationshipFetcher {

        public enum RecursiveMethod {
            case depthLimit(Int)
            case full
            case none
        }

        public enum RelationshipFetchingMethod {
            case all(recursive: RecursiveMethod, context: ReadContext?)
            case filtered(AnySequence<AnyRelationshipIdentifierConvertible>, recursive: RecursiveMethod, context: ReadContext?)
            case custom(AnyPublisher<Void, ManagerError>)
            case none
        }

        public typealias Fetch = (
            _ entityTypePath: [Graph.AnyEntity.IndexName],
            _ identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
            _ graph: ThreadSafeGraph<Graph>
        ) -> RelationshipFetchingMethod

        public let fetch: Fetch

        public static func fetcher(_ fetch: @escaping Fetch) -> RelationshipFetcher {
            return RelationshipFetcher(fetch: fetch)
        }

        public static var none: RelationshipFetcher {
            return fetcher { _, _, _ in .none }
        }

        public static func all(recursive: RelationshipFetcher.RecursiveMethod = .full, context: ReadContext? = nil) -> RelationshipFetcher {
            return fetcher { _, _, _ in .all(recursive: .full, context: context) }
        }
    }
}

// MARK: - Utils

private extension EntityIndexValue {

    var toRelationshipTypeIdentifiers: AnySequence<AnyRelationshipIdentifierConvertible> {
        switch self {
        case .relationship(let identifier):
            return [identifier].any
        case .array(let identifiers):
            return identifiers.flatMap { $0.toRelationshipTypeIdentifiers }.any
        default:
            return [].any
        }
    }
}

// MARK: - Syntactic Sugar

public extension RelationshipController {

    final class RelationshipQuery<E> where E: Entity, E.ResultPayload == RelationshipManager.ResultPayload, E.RelationshipIndexName.AnyEntity == RelationshipManager.AnyEntity {

        private var includeAll: (value: Bool, recursive: RelationshipFetcher.RecursiveMethod) = (false, .full)

        private var fetchers = [[Graph.AnyEntity.IndexName]: RelationshipFetcher?]()

        private var mainContext: ReadContext

        private let rootEntities: (
            once: AnyPublisher<AnySequence<Graph.AnyEntity>, ManagerError>,
            continuous: AnySafePublisher<AnySequence<Graph.AnyEntity>>
        )

        private let relationshipManager: RelationshipManager?

        public init(rootEntities: (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnySafePublisher<QueryResult<E>>),
                                in mainContext: ReadContext,
                                relationshipManager: RelationshipManager?) {

                self.rootEntities = (
                    rootEntities.once.map { $0.lazy.compactMap { Graph.AnyEntity($0) }.any }.eraseToAnyPublisher(),
                    rootEntities.continuous.map {
                        $0.lazy.compactMap { Graph.AnyEntity($0) }.any
                    }.eraseToAnyPublisher()
                )
                self.mainContext = mainContext
                self.relationshipManager = relationshipManager
        }

        private func controller(for rootEntities: AnySequence<Graph.AnyEntity>, context: ReadContext) -> RelationshipController<RelationshipManager, Graph> {
            return RelationshipController(
                rootEntities: Just(rootEntities).setFailureType(to: ManagerError.self).eraseToAnyPublisher(),
                relationshipContext: context,
                relationshipManager: self.relationshipManager,
                relationshipFetcher: .fetcher { path, identifiers, graph in
                    if let fetcher = self.fetchers[path] {
                        return fetcher?.fetch(path, identifiers, graph) ?? .none
                    } else {
                        if Constants.isDebugModeOn {
                            Logger.log(.debug, "\(RelationshipController.self): Fetching path: \(path.map { $0.requestValue }): in context: \(self.mainContext.debugDescription)")
                        }
                        return self.includeAll.value ? .all(recursive: self.includeAll.recursive, context: nil) : .none
                    }
                }
            )
        }

        public func perform(_ graphType: Graph.Type) -> (once: AnyPublisher<Graph, ManagerError>, continuous: AnyPublisher<Graph, ManagerError>) {

            let dispatchQueue = DispatchQueue(label: "\(RelationshipQuery.self):first_graph")
            var eventCount = 0
            var firstGraph: AnyPublisher<Graph, ManagerError>?

            return (
                rootEntities
                    .once
                    .receive(on: dispatchQueue)
                    .flatMap { entities -> AnyPublisher<Graph, ManagerError> in
                        if let graph = firstGraph {
                            return graph
                        } else {
                            let graph = self.controller(for: entities, context: self.mainContext).buildGraph()
                            firstGraph = graph
                            return graph
                        }
                    }
                    .eraseToAnyPublisher(),
                rootEntities
                    .continuous
                    .receive(on: dispatchQueue)
                    .setFailureType(to: ManagerError.self)
                    .flatMap { entities -> AnyPublisher<Graph, ManagerError> in
                        defer { eventCount += 1 }
                        if let graph = firstGraph, eventCount == 0 {
                            return graph
                        } else {
                            let graph = self.controller(
                                for: entities,
                                context: eventCount == 0 ? self.mainContext : self.mainContext.discardingRemoteStoreCache.transformedForRelationshipFetching
                            ).buildGraph()
                            firstGraph = graph
                            return graph
                        }
                    }
                    .eraseToAnyPublisher()
            )
        }

        public func fill(_ graph: ThreadSafeGraph<Graph>, context: ReadContext, path: [Graph.AnyEntity.IndexName] = []) -> AnyPublisher<Void, ManagerError> {
            return rootEntities.once.flatMap { entities -> AnyPublisher<Void, ManagerError> in
                self.controller(for: entities, context: self.mainContext).fill(graph, nestedContext: context, path: path)
            }
            .eraseToAnyPublisher()
        }

        // MARK: - Fetcher

        public func with(fetcher: RelationshipFetcher, forPath path: [Graph.AnyEntity.IndexName]) -> RelationshipQuery {
            fetchers[path] = fetcher
            return self
        }

        // MARK: - Exclusions

        @discardableResult
        public func excluding(path: [Graph.AnyEntity.IndexName]) -> RelationshipQuery {
            fetchers[path] = .some(nil)
            return self
        }

        public func excluding(_ relationships: [E.RelationshipIndexName]) -> RelationshipQuery {
            for path in relationships.flatMap({ $0.paths }) {
                excluding(path: path)
            }
            return self
        }

        // MARK: - Inclusions

        public func includingAllRelationships(recursive: RelationshipFetcher.RecursiveMethod) -> RelationshipQuery {
            includeAll = (true, recursive)
            return self
        }

        @discardableResult
        public func including(path: [Graph.AnyEntity.IndexName],
                              recursive: RelationshipFetcher.RecursiveMethod = .none,
                              in context: ReadContext? = nil) -> RelationshipQuery {

            fetchers[path] = .all(recursive: recursive, context: context)
            return self
        }

        public func including(_ relationships: [E.RelationshipIndexName],
                              recursive: RelationshipFetcher.RecursiveMethod = .none,
                              in context: ReadContext? = nil) -> RelationshipQuery {

            for path in relationships.flatMap({ $0.paths }) {
                including(path: path, recursive: recursive, in: context)
            }
            return self
        }

        public func including(_ relationships: [E.RelationshipIndexName], with fetcher: RelationshipFetcher) -> RelationshipQuery {
            for path in relationships.flatMap({ $0.paths }) {
                fetchers[path] = fetcher
            }
            return self
        }

        public func including(path: [Graph.AnyEntity.IndexName], with fetcher: RelationshipFetcher) -> RelationshipQuery {
            fetchers[path] = fetcher
            return self
        }

        // MARK: - Context

        public func with(relationshipsContext: ReadContext) -> RelationshipQuery {
            self.mainContext = relationshipsContext
            return self
        }
    }
}

extension Publisher where Output: QueryResultInterface, Failure == ManagerError {

    func relationships<Manager, Graph>(from relationshipManager: Manager?,
                                       in context: RelationshipController<Manager, Graph>.ReadContext? = nil) -> RelationshipController<Manager, Graph>.RelationshipQuery<Output.E>
        where Manager: RelationshipCoreManaging, Graph: MutableGraph, Graph.AnyEntity == Manager.AnyEntity, Manager.ResultPayload == Output.E.ResultPayload {

            return RelationshipController<Manager, Graph>.RelationshipQuery(
                rootEntities: (
                    map { $0.materialized }.eraseToAnyPublisher(),
                    PassthroughSubject().eraseToAnyPublisher()
                ),
                in: context ?? RelationshipController<Manager, Graph>.ReadContext(),
                relationshipManager: relationshipManager
            )
    }

    public func relationships<Manager, Graph>(from relationshipManager: Manager, in context: RelationshipController<Manager, Graph>.ReadContext? = nil) -> RelationshipController<Manager, Graph>.RelationshipQuery<Output.E>
        where Manager: RelationshipCoreManaging, Graph: MutableGraph, Graph.AnyEntity == Manager.AnyEntity, Manager.ResultPayload == Output.E.ResultPayload {

            return relationships(from: .some(relationshipManager), in: context)
    }
}

// MARK: - Context Utils

private extension _ReadContext {

    var transformedForRelationshipFetching: _ReadContext {
        return _ReadContext(dataSource: dataSource.transformedForRelationshipFetching,
                            contract: contract,
                            accessValidator: accessValidator,
                            remoteStoreCache: remoteStoreCache)
    }

    var discardingRemoteStoreCache: _ReadContext {
        return _ReadContext(dataSource: dataSource,
                            contract: contract,
                            accessValidator: accessValidator)
    }
}

private extension _ReadContext.DataSource {

    // Since fetching relationships from the remote systematically could be very heavy, we are limiting
    // relationships data source to `local` and `localOrRemote` data sources.
    var transformedForRelationshipFetching: _ReadContext.DataSource {
        switch self {
        case .localOr(._remote(let endpoint, let persistenceStrategy, _, let trustRemoteFiltering)),
             .localThen(._remote(let endpoint, let persistenceStrategy, _, let trustRemoteFiltering)),
             ._remote(let endpoint, let persistenceStrategy, _, let trustRemoteFiltering):
            return .localOr(.remote(endpoint: endpoint,
                                    persistenceStrategy: persistenceStrategy,
                                    trustRemoteFiltering: trustRemoteFiltering))

        case .local,
             .localThen,
             .localOr:
            return .local
        }
    }
}
