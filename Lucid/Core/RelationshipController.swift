//
//  RelationshipController.swift
//  Lucid
//
//  Created by Théophane Rupin on 1/31/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import ReactiveKit

#if !LUCID_REACTIVE_KIT
import Combine
#endif

private enum Constants {
    static let isDebugModeOn = ProcessInfo.processInfo.environment["RELATIONSHIP_CONTROLLER_DEBUG"] == "1"
    static let processingIntervalThreshold: TimeInterval = 0.5
}

/// Mutable graph object
public protocol MutableGraph: AnyObject {

    associatedtype AnyEntity: EntityIndexing, EntityConvertible

    /// Initialize an empty graph
    init()

    /// Set root entities
    /// - Parameter entities: entities to set
    func setRoot<S>(_ entities: S) where S: Sequence, S.Element == AnyEntity

    /// Insert any entities
    /// - Parameter entities: entities to insert
    func insert<S>(_ entities: S) where S: Sequence, S.Element == AnyEntity

    /// Indicates if the given entity identifier is contained in the graph or not.
    /// - Parameter entity: entity identifier to check on.
    func contains(_ identifier: AnyRelationshipIdentifierConvertible) -> Bool
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
    #if LUCID_REACTIVE_KIT
    func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
             entityType: String,
             in context: _ReadContext<ResultPayload>) -> Signal<AnySequence<AnyEntity>, ManagerError>
    #else
    func get(byIDs identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
             entityType: String,
             in context: _ReadContext<ResultPayload>) -> AnyPublisher<AnySequence<AnyEntity>, ManagerError>
    #endif
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

    public var value: SafeSignal<Graph> {
        return SafeSignal { observer in
            self.dispatchQueue.async {
                observer.receive(lastElement: self._value)
            }
            return SimpleDisposable()
        }
    }

    public init() {
        _value = Graph()
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

    private let rootEntities: Signal<AnySequence<Graph.AnyEntity>, ManagerError>

    private let relationshipContext: ReadContext

    private let relationshipManager: RelationshipManager?

    private let relationshipFetcher: RelationshipFetcher

    public init(rootEntities: Signal<AnySequence<Graph.AnyEntity>, ManagerError>,
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

    #if LUCID_REACTIVE_KIT
    public convenience init<E>(rootEntities: Signal<AnySequence<E>, ManagerError>,
                               relationshipContext: ReadContext,
                               relationshipManager: RelationshipManager,
                               relationshipFetcher: RelationshipFetcher = .none)
        where E: Entity, E.ResultPayload == RelationshipManager.ResultPayload {

            self.init(rootEntities: rootEntities.map { $0.lazy.compactMap { Graph.AnyEntity($0) }.any },
                      relationshipContext: relationshipContext,
                      relationshipManager: relationshipManager,
                      relationshipFetcher: relationshipFetcher)
    }
    #else
    public convenience init<E>(rootEntities: AnyPublisher<AnySequence<E>, ManagerError>,
                               relationshipContext: ReadContext,
                               relationshipManager: RelationshipManager,
                               relationshipFetcher: RelationshipFetcher = .none)
        where E: Entity, E.ResultPayload == RelationshipManager.ResultPayload {

            self.init(rootEntities: rootEntities.map { $0.lazy.compactMap { Graph.AnyEntity($0) }.any }.toSignal(),
                      relationshipContext: relationshipContext,
                      relationshipManager: relationshipManager,
                      relationshipFetcher: relationshipFetcher)
    }
    #endif

    private func _buildGraph() -> Signal<Graph, ManagerError> {

        let createdAt = Date()
        Logger.log(.debug, "\(RelationshipController.self): Creating graph for \(relationshipContext).")

        let graph = ThreadSafeGraph<Graph>()
        return self._fill(graph).flatMapLatest { _ -> Signal<Graph, ManagerError> in
            let processingInterval = Date().timeIntervalSince(createdAt)

            Logger.log(.debug, "\(RelationshipController.self): Took \(processingInterval)s to build graph for \(self.relationshipContext.debugDescription).")
            if self.relationshipContext.remoteContextAfterMakingLocalRequest != nil {
                graph.logPerformanceAnomaly(prefix: "\(RelationshipController.self)")
            }

            return graph.value.castError()
        }
    }

    #if LUCID_REACTIVE_KIT
    public func buildGraph() -> Signal<Graph, ManagerError> {
        return _buildGraph()
    }
    #else
    public func buildGraph() -> AnyPublisher<Graph, ManagerError> {
        return _buildGraph().toPublisher().eraseToAnyPublisher()
    }
    #endif

    private func _fill(_ graph: ThreadSafeGraph<Graph>, path: [String] = []) -> Signal<(), ManagerError> {

        return rootEntities.flatMapLatest { (entities: AnySequence<Graph.AnyEntity>) -> Signal<(), ManagerError>  in
            let entities = entities.array

            if path.isEmpty {
                graph.setRoot(entities)
            }
            graph.insert(entities)

            let relationshipIdentifiers: [String: [AnyRelationshipIdentifierConvertible]] = entities.reduce(into: [:]) { identifiers, entity in
                for relationshipTypeUID in entity.entityRelationshipEntityTypeUIDs {
                    identifiers[relationshipTypeUID] = identifiers[relationshipTypeUID] ?? []
                }
                for relationshipIndex in entity.entityRelationshipIndices {
                    for relationshipIdentifier in entity.entityIndexValue(for: relationshipIndex).toRelationshipTypeIdentifiers {
                        var _identifiers = identifiers[relationshipIdentifier.entityTypeUID] ?? []
                        _identifiers.append(relationshipIdentifier)
                        identifiers[relationshipIdentifier.entityTypeUID] = _identifiers
                    }
                }
            }

            guard relationshipIdentifiers.isEmpty == false else {
                return Signal(just: ())
            }

            return Signal(
                combiningLatest: relationshipIdentifiers.keys.sorted()
                    .compactMap { entityType -> Signal<(), ManagerError>? in
                        guard let _identifiers = relationshipIdentifiers[entityType] else { return nil }
                        let identifiers = graph.filterOutContainedIDs(of: _identifiers)

                        let automaticallyFetchRelationships = { (
                            identifiers: AnySequence<AnyRelationshipIdentifierConvertible>,
                            recursiveMethod: RelationshipFetcher.RecursiveMethod,
                            context: ReadContext
                        ) -> Signal<(), ManagerError> in

                            guard identifiers.isEmpty == false else {
                                return Signal(just: ())
                            }

                            let depth = path.count

                            let entities = self.relationshipManager?.get(
                                byIDs: identifiers.any,
                                entityType: entityType,
                                in: context.updateForRelationshipController(at: depth, deltaStrategy: .retainExtraLocalData)
                            ).toSignal() ?? Signal(just: [].any)

                            let recurse = {
                                return RelationshipController(
                                    rootEntities: entities,
                                    relationshipContext: context,
                                    relationshipManager: self.relationshipManager,
                                    relationshipFetcher: self.relationshipFetcher
                                )._fill(graph, path: path + [entityType])
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
                            }
                        }

                        switch self.relationshipFetcher.fetch(path + [entityType], identifiers.any, graph) {
                        case .custom(let signal):
                            return signal.toSignal()
                        case .all(let recursive, let context):
                            return automaticallyFetchRelationships(identifiers.any, recursive, context ?? self.relationshipContext)
                        case .filtered(let identifiers, let recursive, let context):
                            return automaticallyFetchRelationships(identifiers.any, recursive, context ?? self.relationshipContext)
                        case .none:
                            return Signal(just: ())
                        }
                }
            ) { _ in () }
        }
    }

    #if LUCID_REACTIVE_KIT
    public func fill(_ graph: ThreadSafeGraph<Graph>, path: [String] = []) -> Signal<(), ManagerError> {
        return _fill(graph, path: path)
    }
    #else
    public func fill(_ graph: ThreadSafeGraph<Graph>, path: [String] = []) -> AnyPublisher<(), ManagerError> {
        return _fill(graph, path: path).toPublisher().eraseToAnyPublisher()
    }
    #endif
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
            #if LUCID_REACTIVE_KIT
            case custom(Signal<(), ManagerError>)
            #else
            case custom(AnyPublisher<(), ManagerError>)
            #endif
            case none
        }

        public typealias Fetch = (
            _ entityTypePath: [String],
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

// MARK: - RelationshipPath

public struct RelationshipPath {

    private let entityTypeUID: String?

    private let children: [RelationshipPath]

    public static func path<E>(_ entityType: E.Type, _ children: [RelationshipPath] = []) -> RelationshipPath where E: Entity {
        return RelationshipPath(entityTypeUID: entityType.Identifier.entityTypeUID, children: children)
    }

    public static func path<E>(_ entityType: E.Type, _ path: RelationshipPath) -> RelationshipPath where E: Entity {
        return .path(entityType, [path])
    }

    public static func path<E1, E2>(_ entityType1: E1.Type, _ entityType2: E2.Type) -> RelationshipPath where E1: Entity, E2: Entity {
        return .path(entityType1, [.path(entityType2)])
    }

    public static func root(_ children: [RelationshipPath]) -> RelationshipPath {
        return RelationshipPath(entityTypeUID: nil, children: children)
    }

    fileprivate var buildPaths: [[String]] {
        return (entityTypeUID.flatMap { [[$0]] } ?? []) + children.flatMap { child -> [[String]] in
            child.buildPaths.map { paths -> [String] in
                (entityTypeUID.flatMap { [$0] } ?? []) + paths
            }
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

    final class RelationshipQuery {

        private var includeAll: (value: Bool, recursive: RelationshipFetcher.RecursiveMethod) = (false, .full)

        private var fetchers = [[String]: RelationshipFetcher?]()

        private var mainContext: ReadContext
        private var contexts = [[String]: ReadContext?]()

        private let rootEntities: (
            once: Signal<AnySequence<Graph.AnyEntity>, ManagerError>,
            continuous: SafeSignal<AnySequence<Graph.AnyEntity>>
        )

        private let relationshipManager: RelationshipManager?

        private init<E>(_ rootEntities: (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>),
                        in mainContext: ReadContext,
                        relationshipManager: RelationshipManager?)
            where E: Entity, E.ResultPayload == RelationshipManager.ResultPayload {

                self.rootEntities = (
                    rootEntities.once.map { $0.lazy.compactMap { Graph.AnyEntity($0) }.any },
                    rootEntities.continuous.map {
                        $0.lazy.compactMap { Graph.AnyEntity($0) }.any
                    }
                )
                self.mainContext = mainContext
                self.relationshipManager = relationshipManager
        }

        #if LUCID_REACTIVE_KIT
        public convenience init<E>(rootEntities: (once: Signal<QueryResult<E>, ManagerError>, continuous: SafeSignal<QueryResult<E>>),
                                   in mainContext: ReadContext,
                                   relationshipManager: RelationshipManager?)
            where E: Entity, E.ResultPayload == RelationshipManager.ResultPayload {

            self.init(rootEntities, in: mainContext, relationshipManager: relationshipManager)
        }
        #else
        public convenience init<E>(rootEntities: (once: AnyPublisher<QueryResult<E>, ManagerError>, continuous: AnyPublisher<QueryResult<E>, Never>),
                                   in mainContext: ReadContext,
                                   relationshipManager: RelationshipManager?)
            where E: Entity, E.ResultPayload == RelationshipManager.ResultPayload {

                self.init((rootEntities.once.toSignal(), rootEntities.continuous.toSignal()),
                          in: mainContext,
                          relationshipManager: relationshipManager)
        }
        #endif

        private func controller(for rootEntities: AnySequence<Graph.AnyEntity>, context: ReadContext) -> RelationshipController<RelationshipManager, Graph> {
            return RelationshipController(
                rootEntities: Signal(just: rootEntities),
                relationshipContext: context,
                relationshipManager: self.relationshipManager,
                relationshipFetcher: .fetcher { path, identifiers, graph in
                    if let fetcher = self.fetchers[path] {
                        return fetcher?.fetch(path, identifiers, graph) ?? .none
                    } else {
                        if Constants.isDebugModeOn {
                            Logger.log(.debug, "\(RelationshipController.self): Including path: \(path).")
                        }
                        return self.includeAll.value ? .all(recursive: self.includeAll.recursive, context: nil) : .none
                    }
                }
            )
        }

        private func _perform(_: Graph.Type) -> (once: Signal<Graph, ManagerError>, continuous: Signal<Graph, ManagerError>) {

            let dispatchQueue = DispatchQueue(label: "\(RelationshipQuery.self):first_graph")
            var eventCount = 0
            var firstGraph: Signal<Graph, ManagerError>?

            return (
                rootEntities
                    .once
                    .receive(on: dispatchQueue)
                    .flatMapLatest { entities -> Signal<Graph, ManagerError> in
                        if let graph = firstGraph {
                            return graph
                        } else {
                            let graph = self.controller(for: entities, context: self.mainContext).buildGraph().toSignal()
                            firstGraph = graph
                            return graph
                        }
                    },
                rootEntities
                    .continuous
                    .mapError { _ in ManagerError.notSupported }
                    .receive(on: dispatchQueue)
                    .flatMapLatest { entities -> Signal<Graph, ManagerError> in
                        defer { eventCount += 1 }
                        if let graph = firstGraph, eventCount == 0 {
                            return graph
                        } else {
                            let graph = self.controller(
                                for: entities,
                                context: eventCount == 0 ? self.mainContext : self.mainContext.discardingRemoteStoreCache.transformedForRelationshipFetching
                            ).buildGraph().toSignal()
                            firstGraph = graph
                            return graph
                        }
                    }
            )
        }

        #if LUCID_REACTIVE_KIT
        public func perform(_ graphType: Graph.Type) -> (once: Signal<Graph, ManagerError>, continuous: Signal<Graph, ManagerError>) {
            return _perform(graphType)
        }
        #else
        public func perform(_ graphType: Graph.Type) -> (once: AnyPublisher<Graph, ManagerError>, continuous: AnyPublisher<Graph, ManagerError>) {
            let signals = _perform(graphType)
            return (
                signals.once.toPublisher().eraseToAnyPublisher(),
                signals.continuous.toPublisher().eraseToAnyPublisher()
            )
        }
        #endif

        private func _fill(_ graph: ThreadSafeGraph<Graph>, path: [String] = []) -> Signal<(), ManagerError> {
            return rootEntities.once.flatMapLatest { entities -> Signal<(), ManagerError> in
                self.controller(for: entities, context: self.mainContext).fill(graph, path: path).toSignal()
            }
        }

        #if LUCID_REACTIVE_KIT
        public func fill(_ graph: ThreadSafeGraph<Graph>, path: [String] = []) -> Signal<(), ManagerError> {
            return _fill(graph, path: path)
        }
        #else
        public func fill(_ graph: ThreadSafeGraph<Graph>, path: [String] = []) -> AnyPublisher<(), ManagerError> {
            return _fill(graph, path: path).toPublisher().eraseToAnyPublisher()
        }
        #endif

        // MARK: - Fetcher

        private func with(fetcher: RelationshipFetcher, forPath path: [String]) -> RelationshipQuery {
            fetchers[path] = fetcher
            return self
        }

        public func with<E>(fetcher: RelationshipFetcher, forPath entityType: E.Type) -> RelationshipQuery where E: Entity {
            return with(fetcher: fetcher, forPath: [entityType.Identifier.entityTypeUID])
        }

        public func with<E1, E2>(fetcher: RelationshipFetcher, forPath entityType1: E1.Type, _ entityType2: E2.Type) -> RelationshipQuery where E1: Entity, E2: Entity {
            return with(fetcher: fetcher, forPath: [entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID])
        }

        public func with<E1, E2, E3>(fetcher: RelationshipFetcher, forPath entityType1: E1.Type, _ entityType2: E2.Type, _ entityType3: E3.Type) -> RelationshipQuery where E1: Entity, E2: Entity, E3: Entity {
            return with(fetcher: fetcher, forPath: [entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID, entityType3.Identifier.entityTypeUID])
        }

        public func with<E1, E2, E3, E4>(fetcher: RelationshipFetcher, forPath entityType1: E1.Type, _ entityType2: E2.Type, _ entityType3: E3.Type, _ entityType4: E4.Type) -> RelationshipQuery where E1: Entity, E2: Entity, E3: Entity, E4: Entity {
            return with(fetcher: fetcher, forPath: [entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID, entityType3.Identifier.entityTypeUID, entityType4.Identifier.entityTypeUID])
        }

        // MARK: - Exclusions

        @discardableResult
        private func excluding(path: [String]) -> RelationshipQuery {
            fetchers[path] = .some(nil)
            return self
        }

        public func excluding(_ tree: RelationshipPath) -> RelationshipQuery {
            for path in tree.buildPaths {
                excluding(path: path)
            }
            return self
        }

        public func excluding<E>(path entityType: E.Type) -> RelationshipQuery where E: Entity {
            return excluding(path: [entityType.Identifier.entityTypeUID])
        }

        public func excluding<E1, E2>(path entityType1: E1.Type, _ entityType2: E2.Type) -> RelationshipQuery where E1: Entity, E2: Entity {
            return excluding(path: [entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID])
        }

        public func excluding<E1, E2, E3>(path entityType1: E1.Type, _ entityType2: E2.Type, _ entityType3: E3.Type) -> RelationshipQuery where E1: Entity, E2: Entity, E3: Entity {
            return excluding(path: [entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID, entityType3.Identifier.entityTypeUID])
        }

        public func excluding<E1, E2, E3, E4>(path entityType1: E1.Type, _ entityType2: E2.Type, _ entityType3: E3.Type, _ entityType4: E4.Type) -> RelationshipQuery where E1: Entity, E2: Entity, E3: Entity, E4: Entity {
            return excluding(path: [entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID, entityType3.Identifier.entityTypeUID, entityType4.Identifier.entityTypeUID])
        }

        // MARK: - Inclusions

        public func includingAllRelationships(recursive: RelationshipFetcher.RecursiveMethod) -> RelationshipQuery {
            includeAll = (true, recursive)
            return self
        }

        @discardableResult
        private func including(path: [String],
                               recursive: RelationshipFetcher.RecursiveMethod,
                               in context: ReadContext? = nil) -> RelationshipQuery {

            fetchers[path] = .all(recursive: recursive, context: context ?? mainContext)
            return self
        }

        public func including(_ tree: RelationshipPath,
                              recursive: RelationshipFetcher.RecursiveMethod = .none,
                              in context: ReadContext? = nil) -> RelationshipQuery {

            for path in tree.buildPaths {
                including(path: path, recursive: recursive, in: context)
            }
            return self
        }

        public func including<E>(path entityType: E.Type,
                                 recursive: RelationshipFetcher.RecursiveMethod = .none,
                                 in context: ReadContext? = nil) -> RelationshipQuery where E: Entity {

            return including(
                path: [entityType.Identifier.entityTypeUID],
                recursive: recursive,
                in: context
            )
        }

        public func including<E1, E2>(path entityType1: E1.Type, _ entityType2: E2.Type,
                                      recursive: RelationshipFetcher.RecursiveMethod = .none,
                                      in context: ReadContext? = nil) -> RelationshipQuery where E1: Entity, E2: Entity {

            return including(
                path: [entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID],
                recursive: recursive,
                in: context
            )
        }

        public func including<E1, E2, E3>(path entityType1: E1.Type, _ entityType2: E2.Type, _ entityType3: E3.Type,
                                          recursive: RelationshipFetcher.RecursiveMethod = .none,
                                          in context: ReadContext? = nil) -> RelationshipQuery where E1: Entity, E2: Entity, E3: Entity {

            return including(
                path: [entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID, entityType3.Identifier.entityTypeUID],
                recursive: recursive,
                in: context
            )
        }

        public func including<E1, E2, E3, E4>(path entityType1: E1.Type, _ entityType2: E2.Type, _ entityType3: E3.Type, _ entityType4: E4.Type,
                                              recursive: RelationshipFetcher.RecursiveMethod = .none,
                                              in context: ReadContext? = nil) -> RelationshipQuery where E1: Entity, E2: Entity, E3: Entity, E4: Entity {

            return including(
                path: [entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID, entityType3.Identifier.entityTypeUID, entityType4.Identifier.entityTypeUID],
                recursive: recursive,
                in: context
            )
        }

        public func including(_ tree: RelationshipPath, with fetcher: RelationshipFetcher) -> RelationshipQuery {
            for path in tree.buildPaths {
                fetchers[path] = fetcher
            }
            return self
        }

        public func including<E>(path entityType: E.Type, with fetcher: RelationshipFetcher) -> RelationshipQuery where E: Entity {
            fetchers[[entityType.Identifier.entityTypeUID]] = fetcher
            return self
        }

        public func including<E1, E2>(path entityType1: E1.Type, _ entityType2: E2.Type, with fetcher: RelationshipFetcher) -> RelationshipQuery where E1: Entity, E2: Entity {
            fetchers[[entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID]] = fetcher
            return self
        }

        public func including<E1, E2, E3>(path entityType1: E1.Type, _ entityType2: E2.Type, _ entityType3: E3.Type, with fetcher: RelationshipFetcher) -> RelationshipQuery where E1: Entity, E2: Entity, E3: Entity {
            fetchers[[entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID, entityType3.Identifier.entityTypeUID]] = fetcher
            return self
        }

        public func including<E1, E2, E3, E4>(path entityType1: E1.Type, _ entityType2: E2.Type, _ entityType3: E3.Type, _ entityType4: E4.Type, with fetcher: RelationshipFetcher) -> RelationshipQuery where E1: Entity, E2: Entity, E3: Entity, E4: Entity {
            fetchers[[entityType1.Identifier.entityTypeUID, entityType2.Identifier.entityTypeUID, entityType3.Identifier.entityTypeUID, entityType4.Identifier.entityTypeUID]] = fetcher
            return self
        }

        // MARK: - Context

        public func with(relationshipsContext: ReadContext) -> RelationshipQuery {
            self.mainContext = relationshipsContext
            return self
        }
    }
}

#if LUCID_REACTIVE_KIT
extension Signal where Element: QueryResultInterface, Error == ManagerError {

    func relationships<Manager, Graph>(from relationshipManager: Manager?,
                                       in context: RelationshipController<Manager, Graph>.ReadContext? = nil) -> RelationshipController<Manager, Graph>.RelationshipQuery
        where Manager: RelationshipCoreManaging, Graph: MutableGraph, Graph.AnyEntity == Manager.AnyEntity, Manager.ResultPayload == Element.E.ResultPayload {

            return RelationshipController<Manager, Graph>.RelationshipQuery(rootEntities: (map { $0.materialized }, PassthroughSubject().toSignal()),
                                                                            in: context ?? RelationshipController<Manager, Graph>.ReadContext(),
                                                                            relationshipManager: relationshipManager)
    }

    public func relationships<Manager, Graph>(from relationshipManager: Manager, in context: RelationshipController<Manager, Graph>.ReadContext? = nil) -> RelationshipController<Manager, Graph>.RelationshipQuery
        where Manager: RelationshipCoreManaging, Graph: MutableGraph, Graph.AnyEntity == Manager.AnyEntity, Manager.ResultPayload == Element.E.ResultPayload {

            return relationships(from: .some(relationshipManager), in: context)
    }
}
#else
extension Publisher where Output: QueryResultInterface, Failure == ManagerError {

    func relationships<Manager, Graph>(from relationshipManager: Manager?,
                                       in context: RelationshipController<Manager, Graph>.ReadContext? = nil) -> RelationshipController<Manager, Graph>.RelationshipQuery
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

    public func relationships<Manager, Graph>(from relationshipManager: Manager, in context: RelationshipController<Manager, Graph>.ReadContext? = nil) -> RelationshipController<Manager, Graph>.RelationshipQuery
        where Manager: RelationshipCoreManaging, Graph: MutableGraph, Graph.AnyEntity == Manager.AnyEntity, Manager.ResultPayload == Output.E.ResultPayload {

            return relationships(from: .some(relationshipManager), in: context)
    }
}
#endif

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
