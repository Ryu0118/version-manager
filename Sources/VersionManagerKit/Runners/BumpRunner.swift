import FileManagerProtocol
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
        try VersionFormatValidator().validate(newVersion, against: config.version)

        let access = FileSystemAccess(fileManager: fileManager)
        let planner = BumpPlanner(fileSystemAccess: access, fileManager: fileManager, processRunner: processRunner)
        let plan = try await planner.plan(config: config, projectRoot: projectRoot, newVersion: newVersion)

        try PlanValidator().validate(plan, config: config, newVersion: newVersion, force: force)

        if !dryRun {
            try PlanApplier(fileManager: fileManager).apply(plan)
        }

        return plan
    }
}
