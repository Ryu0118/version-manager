import FileManagerProtocol

package struct BumpRunner {
    private let fileManager: any FileManagerProtocol

    package init(fileManager: some FileManagerProtocol) {
        self.fileManager = fileManager
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
        let planner = BumpPlanner(fileSystemAccess: access, fileManager: fileManager)
        let plan = try await planner.plan(config: config, projectRoot: projectRoot, newVersion: newVersion)

        try PlanValidator().validate(plan, config: config, newVersion: newVersion, force: force)

        if !dryRun {
            try PlanApplier(fileManager: fileManager).apply(plan)
        }

        return plan
    }
}
