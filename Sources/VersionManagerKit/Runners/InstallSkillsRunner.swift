import FileManagerProtocol
import Foundation

package struct InstallSkillsRunner {
    private let fileManager: any FileManagerProtocol

    package init(fileManager: some FileManagerProtocol) {
        self.fileManager = fileManager
    }

    package func run(agent: SkillAgentTarget, dir: String, global: Bool, force: Bool) throws -> SkillInstallResult {
        let homeDir = ProcessInfo.processInfo.environment["HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let baseDir = global ? homeDir : dir
        return try SkillInstaller(fileManager: fileManager).install(
            GeneratedSkills.all,
            agent: agent,
            baseDir: baseDir,
            force: force
        )
    }
}
