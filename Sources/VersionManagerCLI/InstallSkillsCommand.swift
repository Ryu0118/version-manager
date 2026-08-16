import ArgumentParser
import Foundation
import VersionManagerKit

extension SkillAgentTarget: ExpressibleByArgument {}

package struct InstallSkillsCommand: AsyncParsableCommand {
    package static let configuration = CommandConfiguration(
        commandName: "install-skills",
        abstract: "Install version-manager Agent Skills into a project"
    )

    @Option(help: "Which agent layout to install")
    package var agent: SkillAgentTarget = .both

    @Option(help: "Target project root (mutually exclusive with --global)")
    package var dir: String = "."

    @Flag(help: "Install into the user's home directory instead of a project (~/.claude/skills, ~/.agents/skills)")
    package var global = false

    @Flag(help: "Overwrite existing skill directories")
    package var force = false

    @Flag(help: "Output machine-readable JSON")
    package var json = false

    package init() {}

    package func run() async throws {
        try InstallSkillsArgumentsValidator().validate(dir: dir, global: global)

        let runner = InstallSkillsRunner(fileManager: FileManager.default)
        let result = try runner.run(agent: agent, dir: dir, global: global, force: force)

        if json {
            let data = try JSONEncoder().encode(SkillInstallResultJSON(result))
            guard let output = String(bytes: data, encoding: .utf8) else {
                throw JSONOutputError.encodingFailed
            }
            print(output)
        } else {
            print(SkillInstallResultRenderer().render(result))
        }
    }
}
