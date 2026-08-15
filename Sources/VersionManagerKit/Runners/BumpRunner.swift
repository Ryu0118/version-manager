import FileManagerProtocol
import Foundation
import ProcessRunning

package struct BumpRunner {
    private let fileManager: any FileManagerProtocol
    private let processRunner: any ProcessRunning

    package init(fileManager: some FileManagerProtocol, processRunner: some ProcessRunning) {
        self.fileManager = fileManager
        self.processRunner = processRunner
    }

    package func run(
        configPath: String,
        projectRoot: String,
        newVersion: String,
        dryRun: Bool,
        skipHooks: Bool,
        force: Bool
    ) async throws -> BumpPlan {
        let config = try ConfigLoader(fileManager: fileManager).load(from: configPath)
        try ConfigValidator().validate(config)
        try VersionFormatValidator().validate(newVersion, strict: config.strict ?? true)

        let access = FileSystemAccess(fileManager: fileManager)
        let planner = BumpPlanner(fileSystemAccess: access, fileManager: fileManager, processRunner: processRunner)
        var plan = try await planner.plan(config: config, projectRoot: projectRoot, newVersion: newVersion)
        plan.preHooks = config.hooks?.pre ?? []
        plan.postHooks = config.hooks?.post ?? []

        let absoluteConfigPath = configPath.hasPrefix("/") ? configPath : projectRoot + "/" + configPath
        guard let configData = fileManager.contents(atPath: absoluteConfigPath),
              let configContent = String(bytes: configData, encoding: .utf8)
        else {
            throw BumpRunnerError.configFileUnreadable(path: absoluteConfigPath)
        }
        guard let configReplacement = BumpPlanner.replacementPlan(
            ruleID: Self.configReplacementRuleID,
            path: absoluteConfigPath,
            content: configContent,
            pattern: Self.configVersionPattern,
            newVersion: newVersion
        ) else {
            throw BumpRunnerError.configVersionFieldNotFound(path: absoluteConfigPath)
        }
        plan.replacements.append(configReplacement)

        try PlanValidator().validate(plan, config: config, newVersion: newVersion, force: force)

        let oldVersion = plan.replacements.first?.matches.first?.oldValue ?? ""

        if !dryRun {
            if !skipHooks, let preHooks = config.hooks?.pre, !preHooks.isEmpty {
                try await HookRunner(processRunner: processRunner)
                    .run(preHooks, old: oldVersion, new: newVersion, configDir: projectRoot)
            }
            try PlanApplier(fileManager: fileManager).apply(plan)
            if !skipHooks, let postHooks = config.hooks?.post, !postHooks.isEmpty {
                try await HookRunner(processRunner: processRunner)
                    .run(postHooks, old: oldVersion, new: newVersion, configDir: projectRoot)
            }
        }

        return plan
    }

    private static let configReplacementRuleID = "__appversion_config__"

    private static let configVersionPattern =
        #"version:\s*"?(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)"?"#
}

package enum BumpRunnerError: Error, LocalizedError, Equatable {
    case configFileUnreadable(path: String)
    case configVersionFieldNotFound(path: String)

    package var errorDescription: String? {
        switch self {
        case let .configFileUnreadable(path):
            "could not read config file to update its own version field: \(path)"
        case let .configVersionFieldNotFound(path):
            "could not find a \"version:\" field to update in \(path) — refusing to bump " +
                "silently without updating the config's own source-of-truth version"
        }
    }
}
