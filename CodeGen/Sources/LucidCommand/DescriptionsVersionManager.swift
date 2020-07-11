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

    func resolveLatestReleaseTag(excluding: Bool, appVersion: String) throws -> String {

        logger.moveToChild("Resolving \(excluding ? "latest release tag " : "release tag for app version \(appVersion)")...")

        try cacheRepository()
        try fetchOrigin()

        let resolvingVersion = try Version(appVersion, source: .description)

        let versions = try shellOut(to: "git tag", at: self.repositoryPath.absolute().string)
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

        let latestReleaseVersion = versions.first {
            $0.isAppStoreRelease && (excluding ? $0 < resolvingVersion : Version.isMatchingRelease(resolvingVersion, $0))
        }
        let latestBetaReleaseVersion = versions.first {
            $0.isBetaRelease && (excluding ? $0 < resolvingVersion : Version.isMatchingRelease(resolvingVersion, $0))
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
            try logger.throwError("Could not resolve tag for app version: \(appVersion).")
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
            .reduce(Data()) { try $0 + $1.read() }
            .sha256()
    }
}

// MARK: - SHA

private extension Data {

    func sha256() throws -> String {
        let transform = SecDigestTransformCreate(kSecDigestSHA2, 256, nil)
        SecTransformSetAttribute(transform, kSecTransformInputAttributeName, self as CFTypeRef, nil)
        guard let shaSum = SecTransformExecute(transform, nil) as? Data else {
            throw CodeGenError.invalidSHASum
        }
        return shaSum.base64EncodedString()
    }
}

// MARK: - Migration Helper

func shouldGenerateDataModel(byComparing oldVersion: Descriptions,
                             to newVersion: Descriptions,
                             appVersion: String,
                             logger: Logger) throws -> Bool {

    logger.moveToChild("Looking for changes in description files...")

    var result = false

    for newVersionEntity in newVersion.persistedEntitiesByName.values.sorted(by: { $0.name < $1.name }) {
        if let newVersionEntityPreviousName = newVersionEntity.previousSearchableName,
            let oldVersionEntity = oldVersion.persistedEntitiesByName[newVersionEntityPreviousName],
            oldVersionEntity.addedAtVersion == newVersionEntity.addedAtVersion {
            if try _shouldGenerateDataModel(byComparing: oldVersionEntity, to: newVersionEntity, appVersion: appVersion, logger: logger) {
                result = true
            }
        } else if let oldVersionEntity = oldVersion.persistedEntitiesByName[newVersionEntity.name],
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

    for oldVersionEntity in oldVersion.persistedEntitiesByName.values {
        if newVersion.persistedEntitiesByName[oldVersionEntity.name] == nil {
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

private func _shouldGenerateDataModel(byComparing oldVersion: Entity,
                                      to newVersion: Entity,
                                      appVersion: String,
                                      logger: Logger) throws -> Bool {

    var result = false

    guard newVersion.addedAtVersion != appVersion else {
        logger.info("Updating description of newly added entity \(newVersion.name). Generate new model.")
        return true
    }

    if oldVersion.name != newVersion.name {
        logger.warn("'\(newVersion.name).name' value changed from '\(oldVersion.name)' to '\(newVersion.name)'.")
        result = true
    }

    if oldVersion.persist != newVersion.persist {
        logger.warn("'\(newVersion.name).persist' value changed from '\(oldVersion.persist)' to '\(newVersion.persist)'.")
        result = true
    }

    if oldVersion.identifier.identifierType != newVersion.identifier.identifierType {
        logger.warn("'\(newVersion.name).identifier' value changed from '\(oldVersion.identifier.identifierType)' to '\(newVersion.identifier.identifierType)'.")
        result = true
    }
    
    if oldVersion.lastRemoteRead != newVersion.lastRemoteRead {
        logger.warn("'\(newVersion.name).lastRemoteRead' value changed from '\(oldVersion.lastRemoteRead)' to '\(newVersion.lastRemoteRead)'.")
        result = true
    }
    
    if oldVersion.platforms != newVersion.platforms {
        logger.warn("'\(newVersion.name).platforms' value changed from '\(oldVersion.platforms)' to '\(newVersion.platforms)'.")
        result = true
    }
    
    let oldProperties = oldVersion.properties.reduce(into: [:]) { $0[$1.name] = $1 }
    for newProperty in newVersion.properties {
        if let oldProperty = oldProperties[newProperty.previousSearchableName ?? newProperty.name] {
            if try _shouldGenerateDataModel(byComparing: oldProperty, to: newProperty, entityName: newVersion.name, appVersion: appVersion, logger: logger) {
                result = true
            }
        } else {
            guard newProperty.previousName == nil else {
                try logger.throwError("Property '\(newVersion.name).\(newProperty.name)' is new. Thus it can't have a 'previous_name' defined.")
            }
            if newProperty.unused {
                logger.warn("Adding new unused property '\(newVersion.name).\(newProperty.name)'. No CoreData change required.")
                continue
            }
            guard newProperty.addedAtVersion == appVersion else {
                try logger.throwError("Property '\(newVersion.name).\(newProperty.name)' is new but its 'added_at_version' isn't set to '\(appVersion)'.")
            }
            if newProperty.defaultValue == nil && newProperty.optional == false && newProperty.extra == false {
                try logger.throwError("Property '\(newVersion.name).\(newProperty.name)' is new in \(appVersion) and non-optional, but it does not have a default value for migrations.")
            }
            logger.warn("Detected new property '\(newVersion.name).\(newProperty.name)'.")
            result = true
        }
    }

    let newProperties = newVersion.properties.reduce(into: [:]) { $0[$1.name] = $1 }
    for oldProperty in oldVersion.properties {
        if newProperties[oldProperty.name] == nil {
            logger.warn("Detected deleted property '\(oldVersion.name).\(oldProperty.name)'.")
            result = true
            continue
        }
    }

    if let oldVersionName = oldVersion.previousName, newVersion.previousName == nil {
        try logger.throwError("\(newVersion.name).previous_name': '\(oldVersionName)' was deleted. Please restore it.")
    }
    if oldVersion.previousName != newVersion.previousName {
        logger.warn("'\(newVersion.name).previousName' value changed from '\(oldVersion.previousName ?? "nil")' to '\(newVersion.previousName ?? "nil")'.")
        result = true
    }

    if oldVersion.modelMappingHistory != newVersion.modelMappingHistory {
        logger.warn("'\(newVersion.name).modelMappingHistory' value changed from '\(oldVersion.modelMappingHistory?.description ?? "nil")' to '\(newVersion.modelMappingHistory?.description ?? "nil")'.")
        result = true
    }

    return result
}

private func _shouldGenerateDataModel(byComparing oldVersion: EntityProperty,
                                      to newVersion: EntityProperty,
                                      entityName: String,
                                      appVersion: String,
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
                          appVersion: String,
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