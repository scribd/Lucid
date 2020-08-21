//
//  DescriptionsVersionManager.swift
//  LucidCommand
//
//  Created by Théophane Rupin on 2/22/19.
//

import LucidCodeGen
import LucidCodeGenCore
import Foundation
import ShellOut
import PathKit

final class DescriptionsVersionManager {

    private let workingPath: Path

    private let inputPath: Path

    private let outputPath: Path

    private let gitRemote: String?

    private let noRepoUpdate: Bool

    private let logger: Logger

    private var didFetch = false

    private var repositoryPath: Path {
        return outputPath + "repository"
    }

    private var repositoryDescriptionsPath: Path {
        return repositoryPath + inputPath
    }

    init(workingPath: Path,
         outputPath: Path,
         inputPath: Path,
         gitRemote: String?,
         noRepoUpdate: Bool,
         logger: Logger) throws {

        self.workingPath = workingPath
        self.outputPath = outputPath
        self.inputPath = inputPath
        self.gitRemote = gitRemote
        self.noRepoUpdate = noRepoUpdate
        self.logger = logger

        guard inputPath.isRelative else {
            try logger.throwError("Input path needs to be a relative path.")
        }
    }
        
    func fetchDescriptionsVersion(releaseTag: String) throws -> Path {

        logger.moveToChild("Fetching descriptions for tag: \(releaseTag)...")

        let destinationDescriptionsPath = outputPath + "descriptions_\(releaseTag)"

        try cacheRepository()

        if let gitRemote = gitRemote {
            try shellOut(to: "git remote remove origin || true", at: repositoryPath.absolute().string)
            try shellOut(to: "git remote add origin \(gitRemote)", at: repositoryPath.absolute().string)
        }

        try shellOut(to: "git reset --hard --quiet \(releaseTag) --", at: repositoryPath.absolute().string)
        logger.done("Checked out \(releaseTag).")

        if destinationDescriptionsPath.exists {
            try destinationDescriptionsPath.delete()
        }
        try destinationDescriptionsPath.parent().mkpath()
        try shellOut(to: "cp -r \(repositoryDescriptionsPath.absolute()) \(destinationDescriptionsPath.absolute())")
        logger.done("Copied descriptions to \(destinationDescriptionsPath).")
        logger.moveToParent()
        return destinationDescriptionsPath
    }

    func allVersionsFromGitTags() throws -> [Version] {

        try cacheRepository()
        try fetchOrigin()

        return try shellOut(to: "git tag", at: repositoryPath.absolute().string)
            .split(separator: "\n")
            .compactMap { tag -> Version? in
                do {
                    return try Version(String(tag), source: .gitTag)
                } catch {
                    return nil
                }
            }
            .filter { $0.isRelease }
            .sorted()
            .reversed()
    }

    func resolveLatestReleaseTag(excluding: Bool, appVersion: Version) throws -> String {

        logger.moveToChild("Resolving \(excluding ? "latest release tag " : "release tag for app version \(appVersion)")...")

        let versions = try allVersionsFromGitTags()

        let latestReleaseVersion = versions.first {
            $0.isAppStoreRelease && (excluding ? $0 < appVersion : Version.isMatchingRelease(appVersion, $0))
        }
        let latestBetaReleaseVersion = versions.first {
            $0.isBetaRelease && (excluding ? $0 < appVersion : Version.isMatchingRelease(appVersion, $0))
        }

        let resolve = { () -> String? in

            guard let latestReleaseVersion = latestReleaseVersion else { return latestBetaReleaseVersion?.versionString }
            guard let latestBetaReleaseVersion = latestBetaReleaseVersion else { return latestReleaseVersion.versionString }

            if latestReleaseVersion > latestBetaReleaseVersion {
                return latestReleaseVersion.versionString
            } else {
                return latestBetaReleaseVersion.versionString
            }
        }

        guard let releaseTag = resolve() else {
            try logger.throwError("Could not resolve tag for app version: \(appVersion.dotDescription).")
        }

        logger.done("Resolved tag: \(releaseTag).")
        logger.moveToParent()

        return releaseTag
    }

    private func cacheRepository() throws {
        guard (workingPath + ".git").exists else {
            try logger.throwError("Working directory needs to be a git repository.")
        }

        if (repositoryPath + ".git").exists == false {
            if repositoryPath.exists {
                try repositoryPath.delete()
            }
            try repositoryPath.mkpath()
            try shellOut(to: "cp -r \(workingPath.absolute())/ \(repositoryPath.absolute()) || true")
            logger.done("Cached repository to \(repositoryPath.absolute()).")
        }
    }

    private func fetchOrigin() throws {
        if noRepoUpdate == false && didFetch == false {
            try shellOut(to: "git fetch origin --tags --quiet", at: repositoryPath.absolute().string)
            didFetch = true
        }
    }

    func descriptionsHash(absoluteInputPath: Path) throws -> String {
        return try absoluteInputPath
            .recursiveChildren()
            .filter { $0.extension == "json" }
            .reduce("") { try $0 + $1.read() }
            .MD5()
    }
}

// MARK: - MD5

private extension String {
    func MD5() throws -> String {
        let tmpFile = "\(NSTemporaryDirectory())md5.tmp"
        try write(toFile: tmpFile, atomically: true, encoding: .utf8)
        #if os(macOS)
        let result = try shellOut(to: "md5 -q \(tmpFile)")
        #else
        let result = try shellOut(to: "md5sum \(tmpFile)")
        #endif
        try FileManager.default.removeItem(atPath: tmpFile)
        return result.components(separatedBy: " ")[0]
    }
}

// MARK: - Entity Version History Validation

func validateEntityVersionHistory(using descriptions: Descriptions, logger: Logger) throws {

    for entity in descriptions.entities {
        guard entity.persist else { continue }

        guard let firstVersion = entity.versionHistory.first else {
            try logger.throwError("Entity \(entity.name) must list a version history to persist.")
        }

        if firstVersion.previousName != nil ||
        firstVersion.ignoreMigrationChecks == true ||
            firstVersion.ignorePropertyMigrationChecksOn.isEmpty == false {
            try logger.throwError("First version of Entity \(entity.name) cannot have a previous name or migration rules.")
        }
    }
}

// MARK: - Migration Helper

func shouldGenerateDataModel(byComparing oldDescriptions: Descriptions,
                             to newDescriptions: Descriptions,
                             appVersion: Version,
                             logger: Logger) throws -> Bool {

    logger.moveToChild("Looking for changes in description files...")

    var result = false

    for newVersionEntity in newDescriptions.persistedEntitiesByName.values.sorted(by: { $0.name < $1.name }) {
        let newVersionEntityPreviousName = newVersionEntity.nameForVersion(oldDescriptions.version)
        if let oldVersionEntity = oldDescriptions.persistedEntitiesByName[newVersionEntityPreviousName],
            oldVersionEntity.addedAtVersion == newVersionEntity.addedAtVersion {
            if try _shouldGenerateDataModel(byComparing: oldVersionEntity, to: newVersionEntity, oldVersion: oldDescriptions.version, appVersion: appVersion, logger: logger) {
                result = true
            }
        } else if let oldVersionEntity = oldDescriptions.persistedEntitiesByName[newVersionEntity.name],
            oldVersionEntity.addedAtVersion == newVersionEntity.addedAtVersion {
            if try _shouldGenerateDataModel(byComparing: oldVersionEntity, to: newVersionEntity, oldVersion: oldDescriptions.version, appVersion: appVersion, logger: logger) {
                result = true
            }
        } else {
            guard newVersionEntity.legacyPreviousName == nil else {
                try logger.throwError("Entity \(newVersionEntity.name) is new. Thus it can't have a 'legacy_previous_name' defined.")
            }
            guard newVersionEntity.addedAtVersion == appVersion else {
                try logger.throwError("Entity \(newVersionEntity.name) is new but its 'added_at_version' isn't set to '\(appVersion)'.")
            }
            logger.warn("Detected new entity '\(newVersionEntity.name)'.")
            result = true
        }
    }

    for oldVersionEntity in oldDescriptions.persistedEntitiesByName.values {
        if newDescriptions.persistedEntitiesByName[oldVersionEntity.name] == nil {
            logger.warn("Detected deleted entity '\(oldVersionEntity.name)'.")
            result = true
            continue
        }
    }

    if result {
        logger.done("Done. Important changes detected. A new version of the data model will be generated.")
    } else {
        logger.done("Done. No important change detected. All is good.")
    }

    logger.moveToParent()
    return result
}

private func _shouldGenerateDataModel(byComparing oldEntity: Entity,
                                      to newEntity: Entity,
                                      oldVersion: Version,
                                      appVersion: Version,
                                      logger: Logger) throws -> Bool {

    var result = false

    guard newEntity.addedAtVersion != appVersion else {
        logger.info("Updating description of newly added entity \(newEntity.name). Generate new model.")
        return true
    }

    if oldEntity.name != newEntity.name {
        logger.warn("'\(newEntity.name).name' value changed from '\(oldEntity.name)' to '\(newEntity.name)'.")
        result = true
    }

    if oldEntity.persist != newEntity.persist {
        logger.warn("'\(newEntity.name).persist' value changed from '\(oldEntity.persist)' to '\(newEntity.persist)'.")
        result = true
    }

    if oldEntity.identifier.identifierType != newEntity.identifier.identifierType {
        logger.warn("'\(newEntity.name).identifier' value changed from '\(oldEntity.identifier.identifierType)' to '\(newEntity.identifier.identifierType)'.")
        result = true
    }
    
    if oldEntity.lastRemoteRead != newEntity.lastRemoteRead {
        logger.warn("'\(newEntity.name).last_remote_read' value changed from '\(oldEntity.lastRemoteRead)' to '\(newEntity.lastRemoteRead)'.")
        result = true
    }
    
    if oldEntity.platforms != newEntity.platforms {
        logger.warn("'\(newEntity.name).platforms' value changed from '\(oldEntity.platforms)' to '\(newEntity.platforms)'.")
        result = true
    }
    
    let oldProperties = oldEntity.properties.reduce(into: [:]) { $0[$1.name] = $1 }
    for newProperty in newEntity.properties {
        if let oldProperty = oldProperties[newProperty.previousSearchableName ?? newProperty.name] {
            if try _shouldGenerateDataModel(byComparing: oldProperty, to: newProperty, entityName: newEntity.name, appVersion: appVersion, logger: logger) {
                result = true
            }
        } else {
            guard newProperty.previousName == nil else {
                try logger.throwError("Property '\(newEntity.name).\(newProperty.name)' is new. Thus it can't have a 'previous_name' defined.")
            }
            if newProperty.unused {
                logger.warn("Adding new unused property '\(newEntity.name).\(newProperty.name)'. No CoreData change required.")
                continue
            }
            guard newProperty.addedAtVersion == appVersion else {
                try logger.throwError("Property '\(newEntity.name).\(newProperty.name)' is new but its 'added_at_version' isn't set to '\(appVersion)'.")
            }
            if newProperty.defaultValue == nil && newProperty.optional == false && newProperty.lazy == false {
                try logger.throwError("Property '\(newEntity.name).\(newProperty.name)' is new in \(appVersion) and non-optional, but it does not have a default value for migrations.")
            }
            logger.warn("Detected new property '\(newEntity.name).\(newProperty.name)'.")
            result = true
        }
    }

    let newProperties = newEntity.properties.reduce(into: [:]) { $0[$1.name] = $1 }
    for oldProperty in oldEntity.properties {
        if newProperties[oldProperty.name] == nil {
            logger.warn("Detected deleted property '\(oldEntity.name).\(oldProperty.name)'.")
            result = true
            continue
        }
    }

    if let oldVersionName = oldEntity.legacyPreviousName, newEntity.legacyPreviousName != oldVersionName {
        try logger.throwError("\(newEntity.name).legacy_previous_name': '\(oldVersionName)' was changed or deleted. Please restore it.")
    }
    if oldEntity.legacyPreviousName != newEntity.legacyPreviousName {
        logger.warn("'\(newEntity.name).legacy_previous_name' value changed from '\(oldEntity.legacyPreviousName ?? "nil")' to '\(newEntity.legacyPreviousName ?? "nil")'.")
        result = true
    }
    if newEntity.nameForVersion(oldVersion) != oldEntity.name {
        try logger.throwError("Names for entity \(newEntity.name) do no match between versions \(oldVersion) and \(appVersion). Update version_history to include previous_name.")
    }

    if oldEntity.versionHistory != newEntity.versionHistory {
        logger.warn("'\(newEntity.name).version_history' value changed from '\(oldEntity.versionHistory.description)' to '\(newEntity.versionHistory.description)'.")
        result = true
    }

    return result
}

private func _shouldGenerateDataModel(byComparing oldProperty: EntityProperty,
                                      to newProperty: EntityProperty,
                                      entityName: String,
                                      appVersion: Version,
                                      logger: Logger) throws -> Bool {

    var result = false

    if oldProperty.name != newProperty.name {
        logger.warn("'\(entityName).\(newProperty.name).name' value changed from '\(oldProperty.name)' to '\(newProperty.name)'.")
        result = true
    }

    if oldProperty.propertyType != newProperty.propertyType {
        logger.warn("'\(entityName).\(newProperty.name).property_type' value changed from '\(oldProperty.propertyType)' to '\(newProperty.propertyType)'.")
        result = true
    }

    if oldProperty.optional != newProperty.optional {
        logger.warn("'\(entityName).\(newProperty.name).optional' value changed from '\(oldProperty.optional)' to '\(newProperty.optional)'.")
        result = true
    }

    if oldProperty.lazy != newProperty.lazy {
        logger.warn("'\(entityName).\(newProperty.name).lazy' value changed from '\(oldProperty.lazy)' to '\(newProperty.lazy)'.")
        result = true
    }

    if oldProperty.defaultValue != newProperty.defaultValue {
        logger.warn("'\(entityName).\(newProperty.name).default_value' value changed from '\(oldProperty.defaultValue?.description ?? "nil")' to '\(newProperty.defaultValue?.description ?? "nil")'.")
        result = true
    }

    if oldProperty.useForEquality != newProperty.useForEquality {
        logger.warn("'\(entityName).\(newProperty.name).use_for_equality' value changed from '\(oldProperty.useForEquality)' to '\(newProperty.useForEquality)'.")
        result = true
    }

    if let oldPropertyName = oldProperty.previousName, newProperty.previousName == nil {
        try logger.throwError("'\(newProperty.name).previous_name': '\(oldPropertyName)' was deleted. Please restore it.")
    }
    if oldProperty.previousName != newProperty.previousName {
        logger.warn("'\(entityName).\(newProperty.name).previous_name' value changed from '\(oldProperty.previousName ?? "nil")' to '\(newProperty.previousName ?? "nil")'.")
        result = true
    }

    if oldProperty.platforms != newProperty.platforms {
        logger.warn("'\(newProperty.name).platforms' value changed from '\(oldProperty.platforms)' to '\(newProperty.platforms)'.")
        result = true
    }

    if oldProperty.unused != newProperty.unused {
        // Toggling the unused flag
        switch (oldProperty.unused, newProperty.unused) {
        case (false, true):
            logger.warn("'\(entityName).\(newProperty.name).unused' value changed from '\(oldProperty.unused)' to '\(newProperty.unused)'. Removing property.")
            result = true

        case (true, false):
            guard oldProperty.previousName == nil else {
                try logger.throwError("Property \(newProperty.name) is being changed from unused to used. It should use `version_history` rather than 'previous_name'. Update description and run again.")
            }
            guard newProperty.addedAtVersion == appVersion else {
                try logger.throwError("Property \(newProperty.name) is being changed from unused to used but its 'version_history' isn't set to '\(appVersion)'. Update description and run again.")
            }
            logger.warn("Detected property '\(newProperty.name)' changed from unused to used.")
            result = true

        case (false, false),
             (true, true):
            break
        }
    }

    return result
}

// MARK: - Validation

func validateDescriptions(byComparing oldDescriptions: Descriptions,
                          to newDescriptions: Descriptions,
                          logger: Logger) throws {
    
    for newEntity in newDescriptions.persistedEntitiesByName.values {
        guard let addedAtVersion = newEntity.addedAtVersion else {
            try logger.throwError("Entity \(newEntity.name) does not have a valid version history.")
        }
        if addedAtVersion > oldDescriptions.version {
            continue
        }
        let previousName = newEntity.nameForVersion(oldDescriptions.version)
        guard let oldEntity = oldDescriptions.persistedEntitiesByName[previousName] else {
            try logger.throwError("Entity \(newEntity.name) could not find valid description for version \(oldDescriptions.version).")
        }
        if oldEntity.identifierTypeID != newEntity.identifierTypeID {
            logger.warn("'\(newEntity.name).uid' value changed from '\(oldEntity.identifierTypeID ?? "nil")' to '\(newEntity.identifierTypeID ?? "nil")'. This value should never change arbitrarily as it could cause severe data losses.")
        }
    }
}
