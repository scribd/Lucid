//
//  CoreDataStore.swift
//  Lucid
//
//  Created by Théophane Rupin on 11/21/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import CoreData

// MARK: - CoreManager

public final class CoreDataManager: NSObject {

    // MARK: - State

    fileprivate enum State {
        case unloaded
        case loaded(NSPersistentContainer, NSManagedObjectContext)
        case loading([() -> Void])
        case failed(NSError?)
    }

    // MARK: - Migration

    public enum MigrationVersion {
        case legacy(Int)
        case appVersion(String)

        var isAppVersion: Bool {
            switch self {
            case .legacy: return false
            case .appVersion: return true
            }
        }
    }

    /// A struct that defines a migration of data.
    /// - Parameters:
    ///     - version: A unique incremental identifier. This value will be cached so that future updates don't perform redundant migrations.
    ///     - execute: A closure containing the migration action. This can contain multiple migration actions if they are happening for the same update.
    public struct Migration {
        public let version: MigrationVersion
        public let execute: (NSManagedObjectContext) -> Result<Void, StoreError>

        public init(version: MigrationVersion,
                    execute: @escaping (NSManagedObjectContext) -> Result<Void, StoreError>) {
            self.version = version
            self.execute = execute
        }
    }

    // MARK: - Configuration

    enum Configuration {
        static let modelName = "Lucid"
        static let bundle = Bundle(for: CoreDataManager.self)
        static let forceMigration = false
        static let storeType: StoreType = .sqlite

        static var stateDispatchQueue: DispatchQueue {
            return DispatchQueue(label: "\(CoreDataManager.self)")
        }

        static var isTestTarget: Bool {
            return NSClassFromString("XCTest") != nil
        }
    }

    // MARK: - StoreType

    public enum StoreType {
        case sqlite
        case memory

        var descriptionType: String {
            switch self {
            case .sqlite:
                return NSSQLiteStoreType
            case .memory:
                return NSInMemoryStoreType
            }
        }
    }

    // MARK: - Testing

    /// CoreData quietly holds a reference to every NSManagedObjectModel loaded. So if multiple tests are creating their
    /// own CoreDataManagers, we keep creating more and more models in memory and it adds a lot of logging as loading an
    /// entity must compare conflicts in multiple models. This logging can slow down the tests and cause errors.
    /// Solved using: https://stackoverflow.com/questions/51851485/multiple-nsentitydescriptions-claim-nsmanagedobject-subclass
    private static var _testingManagedObjectModel: NSManagedObjectModel?

    // MARK: - Dependencies

    private var _state: State = .unloaded
    private let stateDispatchQueue: DispatchQueue
    private let forceMigration: Bool
    private let userDefaults: UserDefaults

    public let modelURL: URL
    public let persistentStoreURL: URL
    private let migrations: [Migration]
    private let storeType: StoreType

    init(modelURL: URL,
         persistentStoreURL: URL,
         migrations: [Migration] = [],
         storeType: StoreType = Configuration.storeType,
         dispatchQueue: DispatchQueue = Configuration.stateDispatchQueue,
         forceMigration: Bool = Configuration.forceMigration,
         userDefaults: UserDefaults = .standard) {

        self.modelURL = modelURL
        self.persistentStoreURL = persistentStoreURL
        self.migrations = migrations
        self.storeType = storeType
        self.userDefaults = userDefaults
        self.stateDispatchQueue = dispatchQueue
        self.forceMigration = forceMigration
    }

    public convenience init(modelName: String,
                            in bundle: Bundle,
                            migrations: [Migration] = [],
                            storeType: StoreType = .sqlite) {

        let modelURL: URL = {
            guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd") else {
                Logger.log(.error, "\(CoreDataManager.self): Could not find model named \(modelName) in bundle.", assert: true)
                return URL(fileURLWithPath: "")
            }
            return modelURL
        }()

        let persistentStoreURL: URL = {
            guard let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first else {
                Logger.log(.error, "\(CoreDataManager.self): Could not find app support directory URL.", assert: true)
                return URL(fileURLWithPath: "")
            }
            return URL(fileURLWithPath: "\(appSupportDirectory)/\(modelName).sqlite")
        }()

        self.init(modelURL: modelURL, persistentStoreURL: persistentStoreURL, migrations: migrations, storeType: storeType)
    }

    deinit {
        unloadPersistentStore(sync: true)
    }

    // MARK: - API

    private var modelName: String {
        return modelURL.lastPathComponent
            .replacingOccurrences(of: ".momd", with: "")
            .replacingOccurrences(of: ".mom", with: "")
    }

    func backupPersistentStore(to destinationURL: URL, completion: @escaping (Bool) -> Void) {
        stateDispatchQueue.async {
            self._persistentContainer {
                guard let (persistentContainer, _) = self._state.loadedValues else {
                    completion(false)
                    return
                }

                let success = persistentContainer.persistentStoreCoordinator.backupPersistentStore(to: destinationURL)
                if success {
                    Logger.log(.info, "\(CoreDataManager.self): Persistent store was successfully exported to: \(destinationURL.path).")
                }
                completion(success)
            }
        }
    }

    func makeContext(_ completion: @escaping (NSManagedObjectContext?) -> Void) {
        stateDispatchQueue.async {
            self._persistentContainer {
                completion(self._state.loadedValues?.context)
            }
        }
    }

    fileprivate func clearDatabase(_ descriptions: [NSEntityDescription], _ completion: @escaping (Bool, NSError?) -> Void) {
        makeContext { _ in
            guard let (_, context) = self._state.loadedValues else {
                completion(false, nil)
                return
            }

            let entityNames = descriptions.compactMap { $0.name }

            context.perform {
                do {
                    for name in entityNames {
                        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                        let request = NSBatchDeleteRequest(fetchRequest: fetch)
                        try context.execute(request)
                    }

                    try context.save()
                    Logger.log(.info, "\(CoreDataManager.self): The database is now cleared.")
                    completion(true, nil)
                } catch {
                    Logger.log(.error, "\(CoreDataManager.self): Could not clear database: \(error)", assert: true)
                    completion(false, error as NSError)
                }
            }
        }
    }

    func clearDatabase(_ completion: @escaping (Bool) -> Void) {
        makeContext { _ in
            guard let (persistentContainer, _) = self._state.loadedValues else {
                completion(false)
                return
            }

            let entityDescriptions = persistentContainer
                .persistentStoreCoordinator
                .managedObjectModel
                .entities

            self.clearDatabase(entityDescriptions, { success, _ in
                completion(success)
            })
        }
    }

    private func unloadPersistentStore(sync: Bool = false) {
        let action = {
            self._state.loadedValues?.containter.persistentStoreDescriptions = []
            self._state = .unloaded
        }

        sync ? stateDispatchQueue.sync(execute: action) : stateDispatchQueue.async(execute: action)
    }

    private func _persistentContainer(_ completion: @escaping () -> Void) {
        switch _state {
        case .unloaded:
            _state = .loading([])
            _loadPersistentContainer(completion)
        case .loading(let completionBlocks):
            _state = .loading(completionBlocks + [completion])
        case .failed(let error):
            Logger.log(.error, "\(CoreDataManager.self): Could not load persistent store: \(error?.description ?? "_").", assert: true)
            completion()
        case .loaded:
            completion()
        }
    }

    private func _loadManagedObjectModel(_ completion: @escaping () -> Void) -> NSManagedObjectModel? {

        switch storeType {
        case .memory:
            if Configuration.isTestTarget == false {
                Logger.log(.error, "\(CoreDataManager.self): Should not be using a memory store for release builds.", assert: true)
            }
            if let model = CoreDataManager._testingManagedObjectModel {
                return model
            }
        case .sqlite:
            break
        }

        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            Logger.log(.error, "\(CoreDataManager.self): Could not create a managed object model with url: \(modelURL).", assert: true)
            let completionBlocks = self._state.completionBlocks(completion)
            self._state = .failed(nil)
            completionBlocks.forEach { $0() }
            return nil
        }

        switch storeType {
        case .memory:
            CoreDataManager._testingManagedObjectModel = managedObjectModel
        case .sqlite:
            break
        }

        return managedObjectModel
    }

    private func _loadPersistentContainer(recovering: Bool = false, _ completion: @escaping () -> Void) {

        guard let managedObjectModel = _loadManagedObjectModel(completion) else { return }

        Logger.log(.info, "\(CoreDataManager.self): Loading persistent stores.")

        let persistentContainer = NSPersistentContainer(name: modelName, managedObjectModel: managedObjectModel)

        let description = NSPersistentStoreDescription(url: persistentStoreURL)
        description.shouldAddStoreAsynchronously = true
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.type = storeType.descriptionType
        persistentContainer.persistentStoreDescriptions = [description]

        persistentContainer.loadPersistentStores { description, error in

            self.stateDispatchQueue.async {

                if let error = error {
                    Logger.log(.error, "\(CoreDataManager.self): Error while loading persistent stores: \(error).")

                    if recovering == false {
                        Logger.log(.warning, "\(CoreDataManager.self): Deleting persistent stores and reloading.")
                        self.removePersistentStore()
                        self._loadPersistentContainer(recovering: true, completion)
                    } else {
                        Logger.log(.error, "\(CoreDataManager.self): Persistent stores failed to load and won't be recovered.")
                        let completionBlocks = self._state.completionBlocks(completion)
                        self._state = .failed(error as NSError)
                        completionBlocks.forEach { $0() }
                    }
                    return
                }

                Logger.log(.info, "\(CoreDataManager.self): Persistent stores loaded successfully.")
                Logger.log(.info, "\(CoreDataManager.self): \(description.url?.path.replacingOccurrences(of: " ", with: "\\ ") ?? "_")")

                let context = persistentContainer.newBackgroundContext()
                context.automaticallyMergesChangesFromParent = true

                self._executeMigrations(in: context) {
                    self.stateDispatchQueue.async {
                        let completionBlocks = self._state.completionBlocks(completion)
                        self._state = .loaded(persistentContainer, context)
                        completionBlocks.forEach { $0() }
                    }
                }
            }
        }
    }

    private func _executeMigrations(in context: NSManagedObjectContext, completion: @escaping () -> Void) {

        let legacyKey = "\(CoreDataManager.self):last_migration_version"
        let key = "\(CoreDataManager.self):last_migration_app_version"

        let lastLegacyMigrationVersion: Int
        let lastMigrationVersion: Version
        if forceMigration {
            lastLegacyMigrationVersion = -1
            lastMigrationVersion = .oldestVersion
        } else {
            lastLegacyMigrationVersion = (userDefaults.object(forKey: legacyKey) as? Int) ?? -1
            let defaultsVersion: Version? = try? Version(userDefaults.object(forKey: key) as? String ?? "9.5.0")
            lastMigrationVersion = defaultsVersion ?? .oldestVersion
        }

        context.perform {

            let shouldMigrate: (MigrationVersion) -> Bool = { version in
                switch version {
                case .legacy(let legacyVersion):
                    return legacyVersion > lastLegacyMigrationVersion
                case .appVersion(let versionString):
                    do {
                        let version = try Version(versionString)
                        return version > lastMigrationVersion
                    } catch {
                        Logger.log(.error, "\(CoreDataManager.self) could not parse version number from string '\(versionString)'.", assert: true)
                        return false
                    }
                }
            }

            for migration in self.migrations where shouldMigrate(migration.version) {
                if let error = migration.execute(context).error {
                    Logger.log(.error, "\(CoreDataManager.self): Migration \(migration.version) failed. The database might be in an unstable state: \(error)", assert: true)
                } else {
                    Logger.log(.info, "\(CoreDataManager.self): Migration \(migration.version) successfully executed.")
                }
            }

            do {
                try context.save()
                Logger.log(.info, "\(CoreDataManager.self): Migrations successfully saved to disk.")
            } catch {
                Logger.log(.error, "\(CoreDataManager.self): Migrations failed to save. The database might be in an unstable state: \(error)", assert: true)
            }

            let writeDefaults: (MigrationVersion) -> Void = { version in
                switch version {
                case .legacy(let lastLegacyMigrationVersion):
                    self.userDefaults.set(lastLegacyMigrationVersion, forKey: legacyKey)
                case .appVersion(let lastMigrationVersion):
                    self.userDefaults.set(lastMigrationVersion.description, forKey: key)
                }
            }

            if let latestLegacyMigration = self.migrations.filter({ $0.version.isAppVersion == false }).last {
                writeDefaults(latestLegacyMigration.version)
            }

            if let latestMigration = self.migrations.filter({ $0.version.isAppVersion }).last {
                writeDefaults(latestMigration.version)
            }

            completion()
        }
    }

    private func removePersistentStore() {
        Logger.log(.warning, "\(CoreDataManager.self): Destroying persistent store at: \(persistentStoreURL.path).")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: persistentStoreURL.path) {
            do {
                try fileManager.removeItem(at: persistentStoreURL)
            } catch {
                Logger.log(.error, "\(CoreDataManager.self): Could not delete persistent store: \(error)", assert: true)
            }
        }
    }
}

private extension CoreDataManager.State {

    var loadedValues: (containter: NSPersistentContainer, context: NSManagedObjectContext)? {
        switch self {
        case .loaded(let values):
            return values
        case .failed,
             .loading,
             .unloaded:
            return nil
        }
    }

    func completionBlocks(_ completion: @escaping () -> Void) -> [() -> Void] {
        switch self {
        case .loading(let pendingCompletionBlocks):
            return [completion] + pendingCompletionBlocks
        case .failed,
             .unloaded,
             .loaded:
            return [completion]
        }
    }
}

// MARK: - Store

public final class CoreDataStore<E>: StoringConvertible where E: CoreDataEntity {

    public let level: StoreLevel = .disk

    private let coreDataManager: CoreDataManager

    public init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    public func get(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        guard let identifier = query.identifier else {
            completion(.failure(.identifierNotFound))
            return
        }

        coreDataManager.makeContext { managedObjectContext in
            guard let managedObjectContext = managedObjectContext else {
                completion(.failure(.invalidCoreDataState))
                return
            }

            managedObjectContext.perform {
                switch CoreDataStore._get(byID: identifier, in: managedObjectContext) {
                case .success(.some(let coreDataEntity)):
                    guard let entity = E.entity(from: coreDataEntity) else {
                        completion(.failure(.invalidCoreDataEntity))
                        return
                    }
                    completion(.success(QueryResult(from: entity)))
                case .success:
                    completion(.success(.empty()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {

        coreDataManager.makeContext { managedObjectContext in
            guard let managedObjectContext = managedObjectContext else {
                completion(.failure(.invalidCoreDataState))
                return
            }

            managedObjectContext.perform {
                switch CoreDataStore._search(withQuery: query, in: managedObjectContext) {
                case .success(let coreDataEntities):
                    var entities = coreDataEntities.compactMap { E.entity(from: $0) }
                    if query.order.contains(where: { $0.isByIdentifiers }) {
                        entities = entities.order(with: query.order)
                    }
                    let result = QueryResult(fromProcessedEntities: entities, for: query)
                    completion(.success(result))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {

        coreDataManager.makeContext { managedObjectContext in
            guard let managedObjectContext = managedObjectContext else {
                completion(.failure(.invalidCoreDataState))
                return
            }

            managedObjectContext.perform {
                var mergedEntities: [E] = []
                for entity in entities {
                    switch CoreDataStore._get(byID: entity.identifier, in: managedObjectContext, loggingContext: "SET") {
                    case .success(.some(let coreDataEntity)):
                        if let identifier = coreDataEntity.identifierValueType(E.Identifier.self) {
                            entity.identifier.update(with: identifier)
                        }
                        var mergedEntity = entity
                        if let existingEntity = E.entity(from: coreDataEntity) {
                            mergedEntity = existingEntity.merging(entity)
                            mergedEntity.merge(into: coreDataEntity)
                        } else {
                            entity.merge(into: coreDataEntity)
                        }
                        mergedEntities.append(mergedEntity)
                    case .success:
                        let coreDataEntity = E.CoreDataObject(context: managedObjectContext)
                        entity.merge(into: coreDataEntity)
                        mergedEntities.append(entity)
                    case .failure(let error):
                        Logger.log(.verbose, "\(CoreDataStore.self): SET error.")
                        completion(.failure(error))
                        return
                    }
                }

                do {
                    try managedObjectContext.save()
                    completion(.success(mergedEntities.any))
                } catch {
                    Logger.log(.verbose, "\(CoreDataStore.self): SET error: \(error).")
                    completion(.failure(.coreData(error as NSError)))
                }
            }
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {

        coreDataManager.makeContext { managedObjectContext in
            guard let managedObjectContext = managedObjectContext else {
                completion(.failure(.invalidCoreDataState))
                return
            }

            managedObjectContext.perform {
                switch CoreDataStore._search(withQuery: query, in: managedObjectContext, loggingContext: "REMOVE ALL") {
                case .success(let coreDataEntities) where coreDataEntities.isEmpty:
                    completion(.success(.empty))
                case .success(let coreDataEntities) where query.filter == .all:
                    let identifiers = coreDataEntities.compactMap { E.entity(from: $0)?.identifier }
                    self.coreDataManager.clearDatabase([E.CoreDataObject.entity()]) { success, error in
                        if success {
                            completion(.success(identifiers.any))
                        } else {
                            if let error = error {
                                completion(.failure(.coreData(error)))
                            } else {
                                completion(.failure(.invalidCoreDataState))
                            }
                        }
                    }
                case .success(let coreDataEntities):
                    let identifiers = coreDataEntities.compactMap { E.entity(from: $0)?.identifier }
                    coreDataEntities.forEach { coreDataEntity in
                        managedObjectContext.delete(coreDataEntity)
                    }
                    do {
                        try managedObjectContext.save()
                        completion(.success(identifiers.any))
                    } catch {
                        Logger.log(.verbose, "\(CoreDataStore.self): REMOVE ALL failure: \(error).")
                        completion(.failure(.coreData(error as NSError)))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {

        coreDataManager.makeContext { managedObjectContext in
            guard let managedObjectContext = managedObjectContext else {
                completion(.failure(.invalidCoreDataState))
                return
            }

            managedObjectContext.perform {
                for identifier in identifiers {
                    switch CoreDataStore._get(byID: identifier, in: managedObjectContext, loggingContext: "REMOVE") {
                    case .success(.some(let coreDataEntity)):
                        managedObjectContext.delete(coreDataEntity)
                    case .success:
                        break
                    case .failure(let error):
                        completion(.failure(error))
                        return
                    }
                }

                do {
                    try managedObjectContext.save()
                    completion(.success(()))
                } catch {
                    Logger.log(.verbose, "\(CoreDataStore.self): REMOVE failure: \(error).")
                    completion(.failure(.coreData(error as NSError)))
                }
            }
        }
    }
}

// MARK: - Store Utils

public extension CoreDataStore {

    static func _get(byID identifier: E.Identifier, in context: NSManagedObjectContext, loggingContext: String? = nil) -> Result<E.CoreDataObject?, StoreError> {

        let loggingContext = loggingContext.flatMap { "\($0) - " } ?? String()

        let fetchRequest = E.CoreDataObject.fetchRequest()
        guard let filter = CoreDataQuery<E>.Filter(.identifier == .identifier(identifier)) else {
            return .failure(.notSupported)
        }
        fetchRequest.predicate = filter.predicate

        do {
            guard let results = try context.fetch(fetchRequest) as? [E.CoreDataObject] else {
                return .failure(.invalidCoreDataState)
            }
            return .success(results.first)
        } catch {
            Logger.log(.verbose, "\(CoreDataStore.self): \(loggingContext)GET failure - \(fetchRequest): \(error).")
            return .failure(.coreData(error as NSError))
        }
    }

    static func _search(withQuery query: Query<E>, in context: NSManagedObjectContext, loggingContext: String? = nil) -> Result<AnySequence<E.CoreDataObject>, StoreError> {

        let loggingContext = loggingContext.flatMap { "\($0) - " } ?? String()

        let fetchRequest = E.CoreDataObject.fetchRequest()

        if let predicate = query.predicate {
            switch predicate {
            case .success(let predicate):
                fetchRequest.predicate = predicate
            case .failure(let error):
                return.failure(error)
            }
        }

        fetchRequest.sortDescriptors = query.order.flatMap { $0.sortDescriptors }

        if let limit = query.limit {
            fetchRequest.fetchLimit = limit
        }

        if let offset = query.offset {
            fetchRequest.fetchOffset = offset
        }

        do {
            guard let results = try context.fetch(fetchRequest) as? [E.CoreDataObject] else {
                return .failure(.invalidCoreDataState)
            }
            return .success(results.any)
        } catch {
            Logger.log(.verbose, "\(CoreDataStore.self): \(loggingContext)SEARCH failure - \(fetchRequest): \(error).")
            return .failure(.coreData(error as NSError))
        }
    }
}

// MARK: - CoreDataQuery

private enum CoreDataQuery<E> where E: CoreDataEntity {

    indirect enum Filter {
        case property(Property)
        case value(Value)
        case values(AnySequence<Value>)
        case negated(Filter)
        case binary(Filter, Query<E>.Operator, Filter)
    }

    enum Value {
        case identifier(Any)
        case index(EntityIndexValue)
        case bool(Bool)
    }

    enum Property {
        case localIdentifier
        case remoteIdentifier
        case identifierTypeID
        case localRelationship(E.IndexName)
        case remoteRelationship(E.IndexName)
        case typeUIDRelationship(E.IndexName)
        case index(E.IndexName)
    }

    enum EntityIndexValue {
        case string(String)
        case int(Int)
        case double(Double)
        case float(Float)
        case relationship(E.RelationshipIdentifier)
        case subtype(E.Subtype)
        case void
        case regex(NSRegularExpression)
        case date(Date)
        case bool(Bool)
        case time(Time)
        case url(URL)
        case color(Color)
        case none
        indirect case array(AnySequence<EntityIndexValue>)
    }
}

// MARK: - Query -> CoreDataQuery Conversions

private extension CoreDataQuery.Filter {

    init?(_ filter: Query<E>.Filter) {
        switch filter {
        case .binary(.property(.identifier), .equalTo, .value(let value)),
             .binary(.value(let value), .equalTo, .property(.identifier)):

            guard let identifier = value.identifier else {
                Logger.log(.error, "Invalid filter. Value should be an identifier.", assert: true)
                return nil
            }

            switch identifier.value {
            case .local(let value):
                self = .binary(
                    .binary(.property(.identifierTypeID), .equalTo, .value(.index(.string(identifier.identifierTypeID)))),
                    .and,
                    .binary(.property(.localIdentifier), .equalTo, .value(.identifier(value.predicateValue)))
                )
            case .remote(let value, nil):
                self = .binary(
                    .binary(.property(.identifierTypeID), .equalTo, .value(.index(.string(identifier.identifierTypeID)))),
                    .and,
                    .binary(.property(.remoteIdentifier), .equalTo, .value(.identifier(value.predicateValue)))
                )
            case .remote(let remoteValue, .some(let localValue)):
                self = .binary(
                    .binary(.property(.identifierTypeID), .equalTo, .value(.index(.string(identifier.identifierTypeID)))),
                    .and,
                    .binary(
                        .binary(.property(.remoteIdentifier), .equalTo, .value(.identifier(remoteValue.predicateValue))),
                        .or,
                        .binary(.property(.localIdentifier), .equalTo, .value(.identifier(localValue.predicateValue)))
                    )
                )
            }

        case .binary(.property(.identifier), .containedIn, .values(let values)),
             .binary(.values(let values), .containedIn, .property(.identifier)):

            guard values.isEmpty == false else {
                self = .binary(.property(.remoteIdentifier), .containedIn, .values([].any))
                return
            }

            if values.filter({ $0.isIdentifier }).count != values.count {
                Logger.log(.error, "Invalid filter. Values should only contain identifiers.", assert: true)
                return nil
            }

            let (remoteIdentifiers, localIdentifiers) = CoreDataQuery.Filter.decomposeIdentifiers(for: values)

            let localIdentifiersBinary = localIdentifiers.keys.sorted().reduce(nil) { (binary, entityTypeUID) -> CoreDataQuery<E>.Filter? in
                guard let localIdentifiers = localIdentifiers[entityTypeUID] else { return binary }
                let newBinary: CoreDataQuery<E>.Filter = .binary(
                    .binary(.property(.identifierTypeID), .equalTo, .value(.index(.string(entityTypeUID)))),
                    .and,
                    .binary(.property(.localIdentifier), .containedIn, .values(localIdentifiers.any))
                )
                if let binary = binary {
                    return .binary(binary, .or, newBinary)
                } else {
                    return newBinary
                }
            }

            let remoteIdentifiersBinary = remoteIdentifiers.keys.sorted().reduce(nil) { (binary, entityTypeUID) -> CoreDataQuery<E>.Filter? in
                guard let remoteIdentifiers = remoteIdentifiers[entityTypeUID] else { return binary }
                let newBinary: CoreDataQuery<E>.Filter = .binary(
                    .binary(.property(.identifierTypeID), .equalTo, .value(.index(.string(entityTypeUID)))),
                    .and,
                    .binary(.property(.remoteIdentifier), .containedIn, .values(remoteIdentifiers.lazy.map { $0 }.any))
                )
                if let binary = binary {
                    return .binary(binary, .or, newBinary)
                } else {
                    return newBinary
                }
            }

            switch (localIdentifiersBinary, remoteIdentifiersBinary) {
            case (.some(let binary), nil),
                 (nil, .some(let binary)):
                self = binary
            case (.some(let lhs), .some(let rhs)):
                self = .binary(lhs, .or, rhs)
            case (nil, nil):
                Logger.log(.error, "Invalid filter. Values should only contain identifiers.", assert: true)
                return nil
            }

        case .binary(.property(.index(let index)), .equalTo, .value(let value)) where index.isOneToOneRelationship,
             .binary(.value(let value), .equalTo, .property(.index(let index))) where index.isOneToOneRelationship:

            guard let relationshipIdentifier = value.relationshipIdentifier else {
                Logger.log(.error, "Invalid filter. Value should be a relationship identifier.", assert: true)
                return nil
            }

            switch relationshipIdentifier.coreDataIdentifierValue {
            case .local(let value):
                self = .binary(
                    .binary(.property(.typeUIDRelationship(index)), .equalTo, .value(.index(.string(relationshipIdentifier.identifierTypeID)))),
                    .and,
                    .binary(.property(.localRelationship(index)), .equalTo, .value(.identifier(value.predicateValue)))
                )
            case .remote(let value, nil):
                self = .binary(
                    .binary(.property(.typeUIDRelationship(index)), .equalTo, .value(.index(.string(relationshipIdentifier.identifierTypeID)))),
                    .and,
                    .binary(.property(.remoteRelationship(index)), .equalTo, .value(.identifier(value.predicateValue)))
                )
            case .remote(let remoteValue, .some(let localValue)):
                self = .binary(
                    .binary(.property(.typeUIDRelationship(index)), .equalTo, .value(.index(.string(relationshipIdentifier.identifierTypeID)))),
                    .and,
                    .binary(
                        .binary(.property(.remoteRelationship(index)), .equalTo, .value(.identifier(remoteValue.predicateValue))),
                        .or,
                        .binary(.property(.localRelationship(index)), .equalTo, .value(.identifier(localValue.predicateValue)))
                    )
                )
            case .none:
                Logger.log(.error, "Invalid filter. Only relationships with CoreDataIdentifiers can be filtered on.", assert: true)
                return nil
            }

        case .binary(.property(.index(let index)), .containedIn, .values(let values)) where index.isOneToOneRelationship,
             .binary(.values(let values), .containedIn, .property(.index(let index))) where index.isOneToOneRelationship:

            guard values.isEmpty == false else {
                self = .binary(.property(.index(index)), .containedIn, .values([].any))
                return
            }

            if values.contains(where: { $0.isRelationshipIdentifier == false }) {
                Logger.log(.error, "Invalid filter. Values should only contain identifiers.", assert: true)
                return nil
            }

            let (remoteIdentifiers, localIdentifiers) = CoreDataQuery<E>.Filter.decomposeIdentifiers(for: values, relationships: true)

            let localIdentifiersBinary = localIdentifiers.keys.sorted().reduce(nil) { (binary, entityTypeUID) -> CoreDataQuery<E>.Filter? in
                guard let localIdentifiers = localIdentifiers[entityTypeUID] else { return binary }
                let newBinary = CoreDataQuery<E>.Filter.binary(
                    .binary(.property(.typeUIDRelationship(index)), .equalTo, .value(.index(.string(entityTypeUID)))),
                    .and,
                    .binary(.property(.localRelationship(index)), .containedIn, .values(localIdentifiers.any))
                )
                if let binary = binary {
                    return .binary(binary, .or, newBinary)
                } else {
                    return newBinary
                }
            }

            let remoteIdentifiersBinary = remoteIdentifiers.keys.sorted().reduce(nil) { (binary, entityTypeUID) -> CoreDataQuery<E>.Filter? in
                guard let remoteIdentifiers = remoteIdentifiers[entityTypeUID] else { return binary }
                let newBinary = CoreDataQuery<E>.Filter.binary(
                    .binary(.property(.typeUIDRelationship(index)), .equalTo, .value(.index(.string(entityTypeUID)))),
                    .and,
                    .binary(.property(.remoteRelationship(index)), .containedIn, .values(remoteIdentifiers.any))
                )
                if let binary = binary {
                    return .binary(binary, .or, newBinary)
                } else {
                    return newBinary
                }
            }

            switch (localIdentifiersBinary, remoteIdentifiersBinary) {
            case (.some(let binary), nil),
                 (nil, .some(let binary)):
                self = binary
            case (.some(let lhs), .some(let rhs)):
                self = .binary(lhs, .or, rhs)
            case (nil, nil):
                Logger.log(.error, "Invalid filter. Values should only contain identifiers.", assert: true)
                return nil
            }

        case .binary(.binary, .equalTo, .binary),
             .binary(.binary, .containedIn, .binary),
             .binary(.binary, .match, .binary),
             .binary(.binary, .greaterThan, .binary),
             .binary(.binary, .greaterThanOrEqual, .binary),
             .binary(.binary, .lessThan, .binary),
             .binary(.binary, .lessThanOrEqual, .binary):
            Logger.log(.error, "Invalid filter. Cannot use .equalTo, .containedIn, .match, .greaterThan, .greaterThanOrEqual, .lessThan and .lessThanOrEqual operators with .binary.", assert: true)
            return nil

        case .binary(let lhs, let op, let rhs):
            guard let lhs = CoreDataQuery<E>.Filter(lhs), let rhs = CoreDataQuery<E>.Filter(rhs) else { return nil }
            self = .binary(lhs, op, rhs)

        case .negated(let filter):
            guard let filter = CoreDataQuery<E>.Filter(filter) else { return nil }
            self = .negated(filter)

        case .property(let property):
            guard let property = CoreDataQuery<E>.Property(property) else { return nil }
            self = .property(property)

        case .value(let value):
            guard let value = CoreDataQuery<E>.Value(value) else { return nil }
            self = .value(value)

        case .values(let values):
            self = .values(values.lazy.compactMap { CoreDataQuery<E>.Value($0) }.any)
        }
    }

    private static func decomposeIdentifiers(for values: DualHashSet<Query<E>.Value>, relationships: Bool = false) -> (remoteIdentifiers: [String: [CoreDataQuery<E>.Value]], localIdentifiers: [String: [CoreDataQuery<E>.Value]]) {
        let result: (remoteIdentifiers: [String: [CoreDataQuery<E>.Value]], localIdentifiers: [String: [CoreDataQuery<E>.Value]]) = values.reduce(into: ([:], [:])) { identifiers, value in
            guard let entityTypeUID = relationships ? value.relationshipIdentifier?.identifierTypeID : value.identifier?.identifierTypeID else {
                Logger.log(.error, "\(CoreDataQuery.Filter.self): Could not extract entity type UID from \(value)", assert: true)
                return
            }

            let remoteValue = relationships ? value.relationshipIdentifier?.coreDataIdentifierValue.remoteValue?.predicateValue : value.identifier?.value.remoteValue?.predicateValue
            if let remoteValue = remoteValue {
                var newIdentifiers: [CoreDataQuery<E>.Value] = identifiers.0[entityTypeUID] ?? []
                newIdentifiers.append(.identifier(remoteValue))
                identifiers.0[entityTypeUID] = newIdentifiers
            }

            let localValue = relationships ? value.relationshipIdentifier?.coreDataIdentifierValue.localValue?.predicateValue : value.identifier?.value.localValue?.predicateValue
            if let localValue = localValue {
                var newIdentifiers: [CoreDataQuery<E>.Value] = identifiers.1[entityTypeUID] ?? []
                newIdentifiers.append(.identifier(localValue))
                identifiers.1[entityTypeUID] = newIdentifiers
            }
        }
        return result
    }
}

extension CoreDataQuery.Value {

    init?(_ value: Query<E>.Value) {
        switch value {
        case .bool(let value):
            self = .bool(value)
        case .index(let index):
            guard let index = CoreDataQuery.EntityIndexValue(index) else { return nil }
            self = .index(index)
        case .identifier:
            Logger.log(.error, "\(CoreDataQuery.Value.self): Unsupported conversion: \(value)", assert: true)
            return nil
        }
    }
}

extension CoreDataQuery.Property {

    init?(_ property: Query<E>.Property) {
        switch property {
        case .index(let name):
            self = .index(name)
        case .identifier:
            Logger.log(.error, "\(CoreDataQuery.Property.self): Unsupported conversion: \(property)", assert: true)
            return nil
        }
    }
}

extension CoreDataQuery.EntityIndexValue {

    init?(_ indexValue: EntityIndexValue<E.RelationshipIdentifier, E.Subtype>) {
        switch indexValue {
        case .string(let value):
            self = .string(value)
        case .int(let value):
            self = .int(value)
        case .double(let value):
            self = .double(value)
        case .float(let value):
            self = .float(value)
        case .relationship(let value):
            self = .relationship(value)
        case .subtype(let value):
            self = .subtype(value)
        case .void:
            self = .void
        case .regex(let value):
            self = .regex(value)
        case .date(let value):
            self = .date(value)
        case .bool(let value):
            self = .bool(value)
        case .time(let value):
            self = .time(value)
        case .url(let value):
            self = .url(value)
        case .color(let value):
            self = .color(value)
        case .none:
            self = .none
        case .array(let values):
            self = .array(values.lazy.compactMap { CoreDataQuery.EntityIndexValue($0) }.any)
        }
    }
}

// MARK: - CoreDataQuery --> NSPredicate Conversions

private extension Query where E: CoreDataEntity {

    var predicate: Result<NSPredicate?, StoreError>? {
        return filter.flatMap {
            guard let predicate = CoreDataQuery<E>.Filter($0)?.predicate else {
                return .failure(.notSupported)
            }
            return .success(predicate)
        }
    }
}

private extension CoreDataQuery.Filter {

    var predicate: NSPredicate? {
        guard let predicateString = predicateString else { return nil }
        return NSPredicate(format: predicateString, argumentArray: predicateValues)
    }
}

private extension CoreDataQuery.Filter {

    var predicateString: String? {
        switch self {
        case .binary(let filter, .equalTo, .value(.bool(let value))),
             .binary(.value(.bool(let value)), .equalTo, let filter):
            if value {
                return filter.predicateString
            } else {
                return CoreDataQuery<E>.Filter.negated(filter).predicateString
            }
        case .binary(let lhs, let op, let rhs):
            guard let lhs = lhs.predicateString, let rhs = rhs.predicateString else {
                return nil
            }
            return "(\(lhs) \(op.predicateString) \(rhs))"
        case .negated(let filter):
            guard let filter = filter.predicateString else { return nil }
            return "(NOT \(filter))"
        case .property(let property):
            return property.predicateString
        case .value,
             .values:
            return "%@"
        }
    }

    var isBinary: Bool {
        switch self {
        case .binary:
            return true
        case .negated,
             .property,
             .value,
             .values:
            return false
        }
    }
}

private extension CoreDataQuery.Filter {

    var predicateValues: [Any] {
        switch self {
        case .binary(let lhs, _, let rhs):
            return lhs.predicateValues + rhs.predicateValues
        case .negated(let filter):
            return filter.predicateValues
        case .property:
            return []
        case .value(let value):
            return [value.predicateValue].compactMap { $0 }
        case .values(let values):
            return [values.compactMap { $0.predicateValue }]
        }
    }
}

private extension Query.Operator {

    var predicateString: String {
        switch self {
        case .and:
            return "AND"
        case .or:
            return "OR"
        case .equalTo:
            return "=="
        case .match:
            return "MATCHES"
        case .containedIn:
            return "IN"
        case .lessThan:
            return "<"
        case .lessThanOrEqual:
            return "<="
        case .greaterThan:
            return ">"
        case .greaterThanOrEqual:
            return ">="
        }
    }
}

private extension CoreDataQuery.Property {

    var predicateString: String? {
        switch self {
        case .localIdentifier:
            return E.Identifier.localPredicateString
        case .remoteIdentifier:
            return E.Identifier.remotePredicateString
        case .identifierTypeID:
            return E.Identifier.identifierTypeIDPredicateString
        case .localRelationship(let indexName):
            return indexName.localRelationshipPredicateString
        case .remoteRelationship(let indexName):
            return indexName.remoteRelationshipPredicateString
        case .typeUIDRelationship(let indexName):
            return indexName.identifierTypeIDRelationshipPredicateString
        case .index(let indexName):
            return indexName.predicateString
        }
    }
}

private extension CoreDataQuery.Value {

    var predicateValue: Any? {
        switch self {
        case .bool(let value):
            return value as NSNumber
        case .identifier(let value):
            return value
        case .index(let indexValue):
            return indexValue.predicateValue
        }
    }
}

private extension CoreDataQuery.EntityIndexValue {

    var predicateValue: Any? {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value as NSNumber
        case .double(let value):
            return value as NSNumber
        case .float(let value):
            return value as NSNumber
        case .relationship:
            Logger.log(.error, "\(CoreDataQuery.EntityIndexValue.self): Relationships must be built manually, testing both remote and local identifier values.", assert: true)
            return nil
        case .subtype(let subtype):
            return subtype.predicateValue
        case .void:
            return nil
        case .regex(let regex):
            return regex.pattern
        case .date(let value):
            return value as NSDate
        case .bool(let value):
            return value.coreDataValue() as NSNumber
        case .time(let value):
            return value.coreDataValue() as NSNumber
        case .url(let value):
            return value.coreDataValue()
        case .color(let value):
            return value.coreDataValue()
        case .none:
            return "nil"
        case .array(let array):
            return array.compactMap { $0.predicateValue }
        }
    }
}

// MARK: - Query --> NSSortDescriptor Conversions

private extension Query.Order where E: CoreDataEntity {

    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .asc(let property):
            return property.sortDescriptors(ascending: true)
        case .desc(let property):
            return property.sortDescriptors(ascending: false)
        case .identifiers:
            return []
        case .natural:
            return []
        }
    }
}

private extension Query.Property where E: CoreDataEntity {

    func sortDescriptors(ascending: Bool) -> [NSSortDescriptor] {
        switch self {
        case .identifier:
            return [
                NSSortDescriptor(key: E.Identifier.remotePredicateString, ascending: ascending),
                NSSortDescriptor(key: E.Identifier.localPredicateString, ascending: ascending)
            ]
        case .index(let indexName) where indexName.isOneToOneRelationship:
            return [
                NSSortDescriptor(key: indexName.remoteRelationshipPredicateString, ascending: ascending),
                NSSortDescriptor(key: indexName.localRelationshipPredicateString, ascending: ascending)
            ].compactMap { $0 }
        case .index(let indexName):
            return [
                NSSortDescriptor(key: indexName.predicateString, ascending: ascending)
            ]
        }
    }
}

// MARK: - CoreData Utils

private extension NSPersistentStoreCoordinator {

    /// Inspired of https://oleb.net/blog/2018/03/core-data-sqlite-backup/
    func backupPersistentStore(to destinationURL: URL, fileManager: FileManager = .default) -> Bool {

        guard let sourceStore = persistentStores.first else {
            Logger.log(.error, "\(NSPersistentStoreCoordinator.self): Could not find persistent store.", assert: true)
            return false
        }

        let backupCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

        let intermediateStoreOptions = (sourceStore.options ?? [:]).merging([NSReadOnlyPersistentStoreOption: true]) { $1 }
        let intermediateStore: NSPersistentStore
        do {
            intermediateStore = try backupCoordinator.addPersistentStore(
                ofType: sourceStore.type,
                configurationName: sourceStore.configurationName,
                at: sourceStore.url,
                options: intermediateStoreOptions
            )
        } catch {
            Logger.log(.error, "\(NSPersistentStoreCoordinator.self): Could not add persistent store: \(error).", assert: true)
            return false
        }

        let backupStoreOptions: [AnyHashable: Any] = [
            NSReadOnlyPersistentStoreOption: true,
            // Disable write-ahead logging. Benefit: the entire store will be
            // contained in a single file. No need to handle -wal/-shm files.
            // https://developer.apple.com/library/content/qa/qa1809/_index.html
            NSSQLitePragmasOption: ["journal_mode": "DELETE"],
            // Minimize file size
            NSSQLiteManualVacuumOption: true
        ]

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(atPath: destinationURL.path)
            } else if !fileManager.fileExists(atPath: destinationURL.deletingLastPathComponent().path) {
                try fileManager.createDirectory(atPath: destinationURL.deletingLastPathComponent().path,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
            }
            try backupCoordinator.migratePersistentStore(intermediateStore,
                                                         to: destinationURL,
                                                         options: backupStoreOptions,
                                                         withType: NSSQLiteStoreType)
            return true
        } catch {
            Logger.log(.error, "\(NSPersistentStoreCoordinator.self): Could not export sqlite file: \(error).", assert: true)
            return false
        }
    }
}

public extension CoreDataManager {

    static func migrate(from oldObject: NSManagedObject,
                        to newObject: NSManagedObject,
                        mappingBlock: (String, Any?) -> (key: String, value: Any?)?) -> Bool {

        let attributeNames = Set(newObject.entity.attributesByName.keys)
            .intersection(oldObject.entity.attributesByName.keys)

        for attributeName in attributeNames {
            let oldValue = oldObject.primitiveValue(forKey: attributeName)
            guard let (newAttributeName, newValue) = mappingBlock(attributeName, oldValue) else {
                return false
            }
            newObject.setPrimitiveValue(newValue, forKey: newAttributeName)
        }

        return true
    }
}
