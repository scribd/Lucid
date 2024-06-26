//
//  Swift.swift
//  LucidCommand
//
//  Created by Théophane Rupin on 9/25/20.
//

import Foundation
import LucidCodeGen
import LucidCodeGenCore
import PathKit

final class SwiftCommand {

    private let logger: Logger

    private let configuration: CommandConfiguration

    init(logger: Logger, configuration: CommandConfiguration) {
        self.logger = logger
        self.configuration = configuration
    }

    func run() throws {

        let currentAppVersion = try Version(configuration.currentVersion, source: .description)
        let currentDescriptionsParser = DescriptionsParser(inputPath: configuration.inputPath,
                                                           targets: configuration.targets,
                                                           logger: logger)
        let currentDescriptions = try currentDescriptionsParser.parse(version: currentAppVersion)

        logger.moveToChild("Validating entity version histories")
        try validateEntityVersionHistory(using: currentDescriptions, logger: logger)
        logger.moveToParent()

        logger.moveToParent()

        logger.moveToChild("Resolving release tags.")

        // If the script hasn't continued after a delay, then show these instructions
        let timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { timer in
            timer.invalidate()
            self.logger.moveToChild("Delay detected while trying to connect to GitHub.")
            self.logger.info("")
            self.logger.info("-------------- Does this appear to be stuck? -------------------------------------------------------------------------------")
            self.logger.info("")
            self.logger.info("  If this is your first time running this script, you might be missing a key in your keychain to access GitHub.")
            self.logger.info("")
            self.logger.info("  First, try a sanity check:")
            self.logger.info("      Run: ssh -T git@github.com")
            self.logger.info("      Sucess: Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.")
            self.logger.info("      Failure: <anything else>")
            self.logger.info("")
            self.logger.info("  If the above check failed then you need to create an ssh key (if none exists) and add it to the keychain.")
            self.logger.info("")
            self.logger.info("  1. First verify that you have a ~/.ssh directory. If you do, skip to step 3, otherwise continue to step 2.")
            self.logger.info("  2. To generate .ssh keys, run the command:")
            self.logger.info("      > ssh-keygen -b 4096 -t ed25519")
            self.logger.info("  3. Now we need to copy the public key to the pasteboard and create an authentication key on GitHub. Run the commands:")
            self.logger.info("      > cd ~/.ssh")
            self.logger.info("      > cat id_ed25519.pub | pbcopy")
            self.logger.info("  4. Go to GitHub.com and:")
            self.logger.info("      a. navigate to Profile (image circle in top right) → Settings → SSH and GPG Keys.")
            self.logger.info("      b. press New SSH Key to create a new authentication key.")
            self.logger.info("      c. create a key with a memorable name, and paste the previously copied key into the key area.")
            self.logger.info("  5. To add the .ssh keys to the keychain, run the command:")
            self.logger.info("      > ssh-add -K ~/.ssh/id_ed25519")
            self.logger.info("  6. Run the sanity check:")
            self.logger.info("      > ssh -T git@github.com")
            self.logger.info("")
            self.logger.info("      If you see an error like:")
            self.logger.info("          The authenticity of host 'github.com (192.30.255.112)' can't be established.")
            self.logger.info("          ED25519 key fingerprint is SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU.")
            self.logger.info("          This key is not known by any other names")
            self.logger.info("          Are you sure you want to continue connecting (yes/no/[fingerprint])?")
            self.logger.info("")
            self.logger.info("      Then you can enter 'yes' to add it to your known_hosts list")
            self.logger.info("      You should eventually be able to run the sanity check and see the success response.")
            self.logger.info("  7. You can now try re-running the 'lucid swift' command!")
            self.logger.info("")
            self.logger.info("")
            self.logger.info("      NOTE: The first time you run this command it will be slow. Very, very slow.")
            self.logger.info("            This is because it has to fetch the history of version tags to validate from.")
            self.logger.info("            Subsequent runs will only need to fetch the most recent tags and will be faster.")
            self.logger.info("            These versions are stored in ~Library/Caches/Lucid and you will see a series of folders")
            self.logger.info("            that are in the format similar to 'descriptions_release_12.7-45'.")
            self.logger.info("")
            self.logger.info("      NOTE: These instructions were written on 11/30/2023, so some of the GitHub UI might have changed since then.")
            self.logger.info("            Also, replace ed25519 with rsa if you already have that key type or prefer it.")
            self.logger.info("")
            self.logger.info("----------------------------------------------------------------------------------------------------------------------------")
            self.logger.info("")
            self.logger.moveToParent()
        }
        logger.moveToChild("Logging values")
        let descriptionsVersionManager = try DescriptionsVersionManager(workingPath: configuration._workingPath,
                                                                        outputPath: configuration.cachePath,
                                                                        inputPath: configuration._inputPath,
                                                                        gitRemote: configuration.gitRemote,
                                                                        currentVersion: currentAppVersion,
                                                                        logger: logger)

        if let descriptionsVersionManager = descriptionsVersionManager {
            logger.info("descriptionsVersionManager: \(descriptionsVersionManager)")
        } else {
            logger.info("descriptionsVersionManager is nil")
        }

        var modelMappingHistoryVersions = try currentDescriptions.modelMappingHistory(derivedFrom: descriptionsVersionManager?.versions() ?? [])
        modelMappingHistoryVersions.removeAll { $0 == currentAppVersion }

        logger.info("modelMappingHistoryVersions: \(modelMappingHistoryVersions)")

        var descriptions = try modelMappingHistoryVersions.reduce(into: [Version: Descriptions]()) { descriptions, appVersion in
            guard appVersion < currentAppVersion else { return }
            guard let descriptionsVersionManager = descriptionsVersionManager else {
                logger.error("descriptionsVersionManager is nil")
                return
            }
    
            do {
                logger.info("Resolving release tag for app version \(appVersion)...")
                let releaseTag = try descriptionsVersionManager.resolveLatestReleaseTag(excluding: false, appVersion: appVersion)
                logger.info("Resolved release tag: \(releaseTag)")
                let descriptionsPath = try descriptionsVersionManager.fetchDescriptionsVersion(releaseTag: releaseTag)
                let descriptionsParser = DescriptionsParser(inputPath: descriptionsPath, logger: Logger(level: .none))
                descriptions[appVersion] = try descriptionsParser.parse(version: appVersion, includeEndpoints: false)
            } catch {
                logger.error("Failed to resolve release tag for app version \(appVersion): \(error.localizedDescription)")
            }
            timer.invalidate()
        }

        logger.info("descriptions: \(descriptions)")

        descriptions[currentAppVersion] = currentDescriptions

        logger.moveToParent()

        let _shouldGenerateDataModel: Bool
        if configuration.forceBuildNewDBModel || configuration.forceBuildNewDBModelForVersions.contains(currentAppVersion.dotDescription) {
            _shouldGenerateDataModel = true
        } else if
            let descriptionsVersionManager = descriptionsVersionManager,
            let latestReleaseTag = try? descriptionsVersionManager.resolveLatestReleaseTag(excluding: true, appVersion: currentAppVersion) {

                let latestDescriptionsPath = try descriptionsVersionManager.fetchDescriptionsVersion(releaseTag: latestReleaseTag)
                let latestDescriptionsParser = DescriptionsParser(inputPath: latestDescriptionsPath,
                                                                  targets: configuration.targets,
                                                                  logger: Logger(level: .none))
                let appVersion = try Version(latestReleaseTag, source: .description)
                let latestDescriptions = try latestDescriptionsParser.parse(version: appVersion, includeEndpoints: false)

                _shouldGenerateDataModel = try shouldGenerateDataModel(byComparing: latestDescriptions,
                                                                       to: currentDescriptions,
                                                                       appVersion: currentAppVersion,
                                                                       logger: logger)

                try validateDescriptions(byComparing: latestDescriptions,
                                         to: currentDescriptions,
                                         logger: logger)
        } else {
            _shouldGenerateDataModel = true
        }
        logger.moveToParent()

        logger.moveToChild("Starting code generation...")
        for target in configuration.targets.value.all where target.isSelected {
            let descriptionsHash = try DescriptionsVersionManager.descriptionsHash(absoluteInputPath: configuration.inputPath)
            let generator = try SwiftCodeGenerator(to: target,
                                                   descriptions: descriptions,
                                                   appVersion: currentAppVersion,
                                                   historyVersions: modelMappingHistoryVersions,
                                                   shouldGenerateDataModel: _shouldGenerateDataModel,
                                                   descriptionsHash: descriptionsHash,
                                                   coreDataMigrationsFunction: configuration.coreDataMigrationsFunction,
                                                   useCoreDataLegacyNaming: configuration.useCoreDataLegacyNaming,
                                                   organizationName: configuration.organizationName,
                                                   extensionsPath: configuration.extensionsPath,
                                                   logger: logger)
            try generator.generate()
        }
        logger.moveToParent()

        logger.br()
        logger.done("Finished successfully.")
    }
}
