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
        if let configData = fileManager.contents(atPath: absoluteConfigPath),
           let configContent = String(bytes: configData, encoding: .utf8),
           let configReplacement = BumpPlanner.replacementPlan(
               ruleID: "__appversion_config__",
               path: absoluteConfigPath,
               content: configContent,
               pattern: #"version:\s*"(\d+\.\d+\.\d+)""#,
               newVersion: newVersion
           )
        {
            plan.replacements.append(configReplacement)
        }

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
}
