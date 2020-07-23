//
//  DescriptionsVersionManager.swift
//  LucidCommand
//
//  Created by Théophane Rupin on 2/22/19.
//

import LucidCodeGen
import Foundation
import ShellOut
import PathKit

final class DescriptionsVersionManager {

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

    init(outputPath: Path,
         inputPath: Path,
         gitRemote: String?,
         noRepoUpdate: Bool,
         logger: Logger) throws {

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
        return try shellOut(to: "git tag", at: self.repositoryPath.absolute().string)
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

        try cacheRepository()
        try fetchOrigin()

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
        if (repositoryPath + ".git").exists == false {
            if repositoryPath.exists {
                try repositoryPath.delete()
            }
            try repositoryPath.mkpath()
            try shellOut(to: "cp -r . \(repositoryPath.absolute()) || true")
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

// MARK: - Migration Helper

func shouldGenerateDataModel(byComparing oldDescriptions: Descriptions,
                             to newDescriptions: Descriptions,
                             appVersion: Version,
                             logger: Logger) throws -> Bool {

    logger.moveToChild("Looking for changes in description files...")

    var result = false

    for newVersionEntity in newDescriptions.persistedEntitiesByName.values.sorted(by: { $0.name < $1.name }) {
        if let newVersionEntityPreviousName = newVersionEntity.previousSearchableName,
            let oldVersionEntity = oldDescriptions.persistedEntitiesByName[newVersionEntityPreviousName],
            oldVersionEntity.addedAtVersion == newVersionEntity.addedAtVersion {
            if try _shouldGenerateDataModel(byComparing: oldVersionEntity, to: newVersionEntity, appVersion: appVersion, logger: logger) {
                result = true
            }
        } else if let oldVersionEntity = oldDescriptions.persistedEntitiesByName[newVersionEntity.name],
            oldVersionEntity.addedAtVersion == newVersionEntity.addedAtVersion {
            if try _shouldGenerateDataModel(byComparing: oldVersionEntity, to: newVersionEntity, appVersion: appVersion, logger: logger) {
                result = true
            }
        } else {
            guard newVersionEntity.previousName == nil else {
                try logger.throwError("Entity \(newVersionEntity.name) is new. Thus it can't have a 'previous_name' defined.")
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
        logger.warn("'\(newEntity.name).lastRemoteRead' value changed from '\(oldEntity.lastRemoteRead)' to '\(newEntity.lastRemoteRead)'.")
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
            if newProperty.defaultValue == nil && newProperty.optional == false && newProperty.extra == false {
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

    if let oldVersionName = oldEntity.previousName, newEntity.previousName == nil {
        try logger.throwError("\(newEntity.name).previous_name': '\(oldVersionName)' was deleted. Please restore it.")
    }
    if oldEntity.previousName != newEntity.previousName {
        logger.warn("'\(newEntity.name).previousName' value changed from '\(oldEntity.previousName ?? "nil")' to '\(newEntity.previousName ?? "nil")'.")
        result = true
    }

    if oldEntity.versionHistory != newEntity.versionHistory {
        logger.warn("'\(newEntity.name).versionHistory' value changed from '\(oldEntity.versionHistory.description)' to '\(newEntity.versionHistory.description)'.")
        result = true
    }

    return result
}

private func _shouldGenerateDataModel(byComparing oldVersion: EntityProperty,
                                      to newVersion: EntityProperty,
                                      entityName: String,
                                      appVersion: Version,
                                      logger: Logger) throws -> Bool {

    var result = false

    if oldVersion.name != newVersion.name {
        logger.warn("'\(entityName).\(newVersion.name).name' value changed from '\(oldVersion.name)' to '\(newVersion.name)'.")
        result = true
    }

    if oldVersion.propertyType != newVersion.propertyType {
        logger.warn("'\(entityName).\(newVersion.name).propertyType' value changed from '\(oldVersion.propertyType)' to '\(newVersion.propertyType)'.")
        result = true
    }

    if oldVersion.optional != newVersion.optional {
        logger.warn("'\(entityName).\(newVersion.name).optional' value changed from '\(oldVersion.optional)' to '\(newVersion.optional)'.")
        result = true
    }

    if oldVersion.extra != newVersion.extra {
        logger.warn("'\(entityName).\(newVersion.name).extra' value changed from '\(oldVersion.extra)' to '\(newVersion.extra)'.")
        result = true
    }

    if oldVersion.defaultValue != newVersion.defaultValue {
        logger.warn("'\(entityName).\(newVersion.name).defaultValue' value changed from '\(oldVersion.defaultValue?.description ?? "nil")' to '\(newVersion.defaultValue?.description ?? "nil")'.")
        result = true
    }

    if oldVersion.useForEquality != newVersion.useForEquality {
        logger.warn("'\(entityName).\(newVersion.name).useForEquality' value changed from '\(oldVersion.useForEquality)' to '\(newVersion.useForEquality)'.")
        result = true
    }

    if let oldVersionName = oldVersion.previousName, newVersion.previousName == nil {
        try logger.throwError("'\(newVersion.name).previous_name': '\(oldVersionName)' was deleted. Please restore it.")
    }
    if oldVersion.previousName != newVersion.previousName {
        logger.warn("'\(entityName).\(newVersion.name).previousName' value changed from '\(oldVersion.previousName ?? "nil")' to '\(newVersion.previousName ?? "nil")'.")
        result = true
    }
    
    if oldVersion.platforms != newVersion.platforms {
        logger.warn("'\(newVersion.name).platforms' value changed from '\(oldVersion.platforms)' to '\(newVersion.platforms)'.")
        result = true
    }

    if oldVersion.unused != newVersion.unused {
        // Toggling the unused flag
        switch (oldVersion.unused, newVersion.unused) {
        case (false, true):
            logger.warn("'\(entityName).\(newVersion.name).unused' value changed from '\(oldVersion.unused)' to '\(newVersion.unused)'. Removing property.")
            result = true

        case (true, false):
            guard oldVersion.previousName == nil else {
                try logger.throwError("Property \(newVersion.name) is being changed from unused to used. It should use `added_at_version` rather than 'previous_name'. Update description and run again.")
            }
            guard newVersion.addedAtVersion == appVersion else {
                try logger.throwError("Property \(newVersion.name) is being changed from unused to used but its 'added_at_version' isn't set to '\(appVersion)'. Update description and run again.")
            }
            logger.warn("Detected property '\(newVersion.name)' changed from unused to used.")
            result = true

        case (false, false),
             (true, true):
            break
        }
    }

    return result
}

// MARK: - Validation

func validateDescriptions(byComparing oldVersion: Descriptions,
                          to newVersion: Descriptions,
                          appVersion: Version,
                          logger: Logger) throws {
    
    for newVersion in newVersion.persistedEntitiesByName.values {
        if let previousName = newVersion.previousSearchableName,
            let oldVersion = oldVersion.persistedEntitiesByName[previousName] {

            if oldVersion.identifierTypeID != newVersion.identifierTypeID {
                logger.warn("'\(newVersion.name).uid' value changed from '\(oldVersion.identifierTypeID ?? "nil")' to '\(newVersion.identifierTypeID ?? "nil")'. This value should never change arbitrarily as it could cause severe data losses.")
            }
        }
    }
}
