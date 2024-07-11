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

    enum CoreDataManagerError: Error {
        case failedToBackupPersistentStore
    }

    // MARK: - State

    private let persistentContainerManager: PersistentContainerManager

    // MARK: - Configuration

    public enum Configuration {
        public static let modelName = "Lucid"
        public static let bundle = Bundle(for: CoreDataManager.self)
        public static let forceMigration = false
        public static let storeType: PersistentContainerManager.StoreType = .sqlite

        public static var isTestTarget: Bool {
            return NSClassFromString("XCTest") != nil
        }
    }

    // MARK: - Dependencies

    private let stateAsyncQueue: AsyncTaskQueue = AsyncTaskQueue(maxConcurrentTasks: 1)

    public init(modelURL: URL,
                persistentStoreURL: URL,
                migrations: [PersistentContainerManager.Migration] = [],
                storeType: PersistentContainerManager.StoreType = Configuration.storeType,
                forceMigration: Bool = Configuration.forceMigration,
                userDefaults: UserDefaults = .standard) {

        self.persistentContainerManager = PersistentContainerManager(storeType: storeType,
                                                                     modelURL: modelURL,
                                                                     persistentStoreURL: persistentStoreURL,
                                                                     migrations: migrations,
                                                                     forceMigration: forceMigration,
                                                                     userDefaults: userDefaults)
    }

    public convenience init(modelName: String,
                            in bundle: Bundle,
                            migrations: [PersistentContainerManager.Migration] = [],
                            storeType: PersistentContainerManager.StoreType = .sqlite) {

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

    func persistentData() async throws -> PersistentContainerManager.Data {
        return try await stateAsyncQueue.enqueue {
            return try await self.persistentContainerManager.data()
        }
    }

    // MARK: - API

    public func backupPersistentStore(to destinationURL: URL) async throws {
        let data = try await persistentData()

        let success = data.container.persistentStoreCoordinator.backupPersistentStore(to: destinationURL)
        if success {
            Logger.log(.info, "\(CoreDataManager.self): Persistent store was successfully exported to: \(destinationURL.path).")
        } else {
            throw CoreDataManagerError.failedToBackupPersistentStore
        }
    }

    fileprivate func clearDatabase(_ descriptions: [NSEntityDescription], in context: NSManagedObjectContext) -> (Bool, NSError?) {
        let entityNames = descriptions.compactMap { $0.name }

        var success = false
        var nsError: NSError?
        context.performAndWait {
            do {
                for name in entityNames {
                    let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                    let request = NSBatchDeleteRequest(fetchRequest: fetch)
                    try context.execute(request)
                }

                try context.save()
                Logger.log(.info, "\(CoreDataManager.self): The database is now cleared.")
                success = true
            } catch {
                Logger.log(.error, "\(CoreDataManager.self): Could not clear database: \(error)", assert: true)
                nsError = error as NSError
            }
        }
        return (success, nsError)
    }

    fileprivate func clearDatabase(_ descriptions: [NSEntityDescription]) async throws -> Bool {
        let context = try await persistentData().context
        return try await withCheckedThrowingContinuation { continuation in
            let (success, error) = self.clearDatabase(descriptions, in: context)
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: success)
            }
        }
    }

    public func clearDatabase() async -> Bool {
        guard let data = try? await persistentData() else {
            return false
        }

        let entityDescriptions = data.container
            .persistentStoreCoordinator
            .managedObjectModel
            .entities

        do {
            return try await self.clearDatabase(entityDescriptions)
        } catch {
            return false
        }
    }
}

// MARK: - PersistentStore

public final actor PersistentContainerManager {

    struct Data {
        let container: NSPersistentContainer
        let context: NSManagedObjectContext
    }

    enum PersistentContainerManagerError: Error {
        case couldNotLoadManagedObjectModel
    }

    // Setup

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

    let storeType: StoreType

    let modelURL: URL

    let persistentStoreURL: URL

    let migrations: [Migration]

    let forceMigration: Bool

    private let userDefaults: UserDefaults

    // Testing

    /// CoreData quietly holds a reference to every NSManagedObjectModel loaded. So if multiple tests are creating their
    /// own CoreDataManagers, we keep creating more and more models in memory and it adds a lot of logging as loading an
    /// entity must compare conflicts in multiple models. This logging can slow down the tests and cause errors.
    /// Solved using: https://stackoverflow.com/questions/51851485/multiple-nsentitydescriptions-claim-nsmanagedobject-subclass
    private static var _testingManagedObjectModel: NSManagedObjectModel?

    // State

    enum State {
        case unloaded
        case loading
        case loaded(Data)
        case failed(NSError)
    }

    private var _state: State = .unloaded

    // Internal

    fileprivate var completionOrder: [UUID] = []

    fileprivate var completionBlocks: [UUID: (Result<PersistentContainerManager.Data, NSError>) async -> Void] = [:]

    private let asyncTaskQueue = AsyncTaskQueue(maxConcurrentTasks: 1)

    // Init

    deinit {
        // unload persistent store on deallocation
        switch _state {
        case .loaded(let data):
            data.container.persistentStoreDescriptions = []
        case .unloaded,
             .loading,
             .failed:
            break
        }
    }

    init(storeType: StoreType,
         modelURL: URL,
         persistentStoreURL: URL,
         migrations: [Migration],
         forceMigration: Bool,
         userDefaults: UserDefaults) {
        self.storeType = storeType
        self.modelURL = modelURL
        self.persistentStoreURL = persistentStoreURL
        self.migrations = migrations
        self.forceMigration = forceMigration
        self.userDefaults = userDefaults
    }

    // Accessors

    func setState(_ state: State) async {
        self._state = state

        let processResult: (Result<PersistentContainerManager.Data, NSError>) async -> Void = { result in
            for uuid in self.completionOrder {
                guard let completionBlock = self.completionBlocks[uuid] else { continue }
                try? await self.asyncTaskQueue.enqueue {
                    await completionBlock(result)
                }
            }

            self.completionOrder = []
            self.completionBlocks = [:]
        }

        switch state {
        case .unloaded,
             .loading:
            return
        case .loaded(let data):
            await processResult(.success(data))
        case .failed(let error):
            await processResult(.failure(error))
        }
    }

    func data() async throws -> PersistentContainerManager.Data {
        switch _state {
        case .unloaded:
            return try await loadPersistentContainer()
        case .loading:
            return try await queueForResource()
        case .loaded(let data):
            return data
        case .failed(let error):
            throw error
        }
    }

    // Queueing

    private func queueForResource() async throws -> PersistentContainerManager.Data {
        let uuid = UUID()
        completionOrder.append(uuid)
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await checkResourceAvailability(uuid: uuid) { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func checkResourceAvailability(uuid: UUID, completion: @escaping ((Result<PersistentContainerManager.Data, NSError>) async -> Void)) async {

        switch _state {
        case .unloaded,
             .loading:
            completionBlocks[uuid] = completion
        case .loaded(let data):
            await completion(.success(data))
        case .failed(let error):
            await completion(.failure(error))
        }
    }

    // CoreData Loading

    private func loadPersistentContainer(recovering: Bool = false) async throws -> PersistentContainerManager.Data {

        do {
            await setState(.loading)

            let managedObjectModel = try await loadManagedObjectModel()

            Logger.log(.info, "\(CoreDataManager.self): Loading persistent stores.")

            let persistentContainer = NSPersistentContainer(name: modelName, managedObjectModel: managedObjectModel)

            let description = NSPersistentStoreDescription(url: persistentStoreURL)
            description.shouldAddStoreAsynchronously = true
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true
            description.type = storeType.descriptionType
            persistentContainer.persistentStoreDescriptions = [description]

            return try await withCheckedThrowingContinuation { continuation in
                persistentContainer.loadPersistentStores { description, error in
                    if let error = error {
                        Task {
                            Logger.log(.error, "\(CoreDataManager.self): Error while loading persistent stores: \(error).")

                            if recovering {
                                Logger.log(.error, "\(CoreDataManager.self): Persistent stores failed to load and won't be recovered.")
                                continuation.resume(throwing: error)
                            } else {
                                Logger.log(.warning, "\(CoreDataManager.self): Deleting persistent stores and reloading.")
                                self.removePersistentStore()
                                do {
                                    let data = try await self.loadPersistentContainer(recovering: true)
                                    continuation.resume(returning: data)
                                } catch {
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                        return
                    }

                    Logger.log(.info, "\(CoreDataManager.self): Persistent stores loaded successfully.")
                    Logger.log(.info, "\(CoreDataManager.self): \(description.url?.path.replacingOccurrences(of: " ", with: "\\ ") ?? "_")")

                    let context = persistentContainer.newBackgroundContext()
                    context.automaticallyMergesChangesFromParent = true

                    Task {
                        await self.executeMigrations(in: context)
                        let data = Data(container: persistentContainer, context: context)
                        continuation.resume(returning: data)
                        await self.setState(.loaded(data))
                    }
                }
            }
        } catch {
            await setState(.failed(error as NSError))
            throw error
        }
    }

    private func loadManagedObjectModel() async throws -> NSManagedObjectModel {

        switch storeType {
        case .memory:
            if CoreDataManager.Configuration.isTestTarget == false {
                Logger.log(.error, "\(CoreDataManager.self): Should not be using a memory store for release builds.", assert: true)
            }
            if let model = PersistentContainerManager._testingManagedObjectModel {
                return model
            }
        case .sqlite:
            break
        }

        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            Logger.log(.error, "\(CoreDataManager.self): Could not create a managed object model with url: \(modelURL).", assert: true)
            throw PersistentContainerManagerError.couldNotLoadManagedObjectModel
        }

        switch storeType {
        case .memory:
            PersistentContainerManager._testingManagedObjectModel = managedObjectModel
        case .sqlite:
            break
        }

        return managedObjectModel
    }

    private func executeMigrations(in context: NSManagedObjectContext) async {

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

        await context.perform {

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

    private var modelName: String {
        return modelURL.lastPathComponent
            .replacingOccurrences(of: ".momd", with: "")
            .replacingOccurrences(of: ".mom", with: "")
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
        Task {
            let result = await get(withQuery: query, in: context)
            completion(result)
        }
    }

    public func get(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        guard let identifier = query.identifier else {
            return .failure(.identifierNotFound)
        }

        let managedObjectContext = try? await coreDataManager.persistentData().context

        guard let managedObjectContext = managedObjectContext else {
            return .failure(.invalidCoreDataState)
        }

        return await withCheckedContinuation { continuation in
            managedObjectContext.perform {
                switch CoreDataStore._get(byID: identifier, in: managedObjectContext) {
                case .success(.some(let coreDataEntity)):
                    guard let entity = E.entity(from: coreDataEntity) else {
                        continuation.resume(returning: .failure(.invalidCoreDataEntity))
                        return
                    }
                    continuation.resume(returning: .success(QueryResult(from: entity)))
                case .success:
                    continuation.resume(returning: .success(.empty()))
                case .failure(let error):
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>, completion: @escaping (Result<QueryResult<E>, StoreError>) -> Void) {
        Task {
            let result = await search(withQuery: query, in: context)
            completion(result)
        }
    }

    public func search(withQuery query: Query<E>, in context: ReadContext<E>) async -> Result<QueryResult<E>, StoreError> {
        let managedObjectContext = try? await coreDataManager.persistentData().context

        guard let managedObjectContext = managedObjectContext else {
            return .failure(.invalidCoreDataState)
        }

        return await withCheckedContinuation { continuation in
            managedObjectContext.perform {
                switch CoreDataStore._search(withQuery: query, in: managedObjectContext) {
                case .success(let coreDataEntities):
                    var entities = coreDataEntities.compactMap { E.entity(from: $0) }
                    if query.order.contains(where: { $0.isByIdentifiers }) {
                        entities = entities.order(with: query.order)
                    }
                    let result = QueryResult(fromProcessedEntities: entities, for: query)
                    continuation.resume(returning: .success(result))
                case .failure(let error):
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E>, StoreError>?) -> Void) where S: Sequence, S.Element == E {
        Task {
            let result = await set(entities, in: context)
            completion(result)
        }
    }

    public func set<S>(_ entities: S, in context: WriteContext<E>) async -> Result<AnySequence<E>, StoreError>? where S : Sequence, E == S.Element {
        let managedObjectContext = try? await coreDataManager.persistentData().context

        guard let managedObjectContext = managedObjectContext else {
            return .failure(.invalidCoreDataState)
        }

        return await withCheckedContinuation { continuation in
            managedObjectContext.perform {
                var mergedEntities: [E] = []
                let query = Query<E>.identifiers(entities.map { $0.identifier }.any)

                let searchResults = CoreDataStore._search(withQuery: query, in: managedObjectContext, loggingContext: "SET")
                switch searchResults {
                case .success(let searchEntities):
                    var dictionary = DualHashDictionary<E.Identifier, (E.CoreDataObject, E)>()
                    for coreDataEntity in searchEntities {
                        guard let entity = E.entity(from: coreDataEntity) else { continue }
                        dictionary[entity.identifier] = (coreDataEntity, entity)
                    }

                    for entity in entities {
                        if let (coreDataEntity, existingEntity) = dictionary[entity.identifier] {
                            if let identifier = coreDataEntity.identifierValueType(E.Identifier.self) {
                                entity.identifier.update(with: identifier)
                            }
                            let mergedEntity = existingEntity.merging(entity)
                            mergedEntity.merge(into: coreDataEntity)
                            mergedEntities.append(mergedEntity)
                        } else {
                            let coreDataEntity = E.CoreDataObject(context: managedObjectContext)
                            entity.merge(into: coreDataEntity)
                            mergedEntities.append(entity)
                        }
                    }

                case .failure(let error):
                    Logger.log(.verbose, "\(CoreDataStore.self): SET error.")
                    continuation.resume(returning: .failure(error))
                    return
                }

                do {
                    try managedObjectContext.save()
                    continuation.resume(returning: .success(mergedEntities.any))
                } catch {
                    Logger.log(.verbose, "\(CoreDataStore.self): SET error: \(error).")
                    continuation.resume(returning: .failure(.coreData(error as NSError)))
                }
            }
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>, completion: @escaping (Result<AnySequence<E.Identifier>, StoreError>?) -> Void) {
        Task {
            let result = await removeAll(withQuery: query, in: context)
            completion(result)
        }
    }

    public func removeAll(withQuery query: Query<E>, in context: WriteContext<E>) async -> Result<AnySequence<E.Identifier>, StoreError>? {
        let managedObjectContext = try? await coreDataManager.persistentData().context

        guard let managedObjectContext = managedObjectContext else {
            return .failure(.invalidCoreDataState)
        }

        return await withCheckedContinuation { continuation in
            managedObjectContext.perform {
                switch CoreDataStore._search(withQuery: query, in: managedObjectContext, loggingContext: "REMOVE ALL") {
                case .success(let coreDataEntities) where coreDataEntities.isEmpty:
                    continuation.resume(returning: .success(.empty))
                case .success(let coreDataEntities) where query.filter == .all:
                    let identifiers = coreDataEntities.compactMap { E.entity(from: $0)?.identifier }
                    let (success, error) = self.coreDataManager.clearDatabase([E.CoreDataObject.entity()], in: managedObjectContext)
                    if success {
                        continuation.resume(returning: .success(identifiers.any))
                    } else if let error {
                        continuation.resume(returning: .failure(.coreData(error)))
                    } else {
                        continuation.resume(returning: .failure(.invalidCoreDataState))
                    }
                case .success(let coreDataEntities):
                    let identifiers = coreDataEntities.compactMap { E.entity(from: $0)?.identifier }
                    coreDataEntities.forEach { coreDataEntity in
                        managedObjectContext.delete(coreDataEntity)
                    }
                    do {
                        try managedObjectContext.save()
                        continuation.resume(returning: .success(identifiers.any))
                    } catch {
                        Logger.log(.verbose, "\(CoreDataStore.self): REMOVE ALL failure: \(error).")
                        continuation.resume(returning: .failure(.coreData(error as NSError)))
                    }
                case .failure(let error):
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>, completion: @escaping (Result<Void, StoreError>?) -> Void) where S: Sequence, S.Element == E.Identifier {
        Task {
            let result = await remove(identifiers, in: context)
            completion(result)
        }
    }

    public func remove<S>(_ identifiers: S, in context: WriteContext<E>) async -> Result<Void, StoreError>? where S: Sequence, S.Element == E.Identifier {
        let result = await removeAll(withQuery: .identifiers(identifiers.any), in: context)
        if case .failure(let error) = result {
            return .failure(error)
        }
        return .success(())
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
