import FileManagerProtocol

package struct InstallSkillsRunner {
    private let fileManager: any FileManagerProtocol

    package init(fileManager: some FileManagerProtocol) {
        self.fileManager = fileManager
    }

    package func run(agent: SkillAgentTarget, dir: String, force: Bool) throws -> SkillInstallResult {
        try SkillInstaller(fileManager: fileManager).install(GeneratedSkills.all, agent: agent, dir: dir, force: force)
    }
}
