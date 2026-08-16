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
        if global, dir != "." {
            throw ValidationError("--dir cannot be combined with --global")
        }

        let runner = InstallSkillsRunner(fileManager: FileManager.default)
        let result = try runner.run(agent: agent, dir: dir, global: global, force: force)
        if json {
            struct InstalledJSON: Encodable {
                let name: String
                let paths: [String]
            }
            struct ResultJSON: Encodable {
                let installed: [InstalledJSON]
                let skipped: [[String: String]]
            }
            let payload = ResultJSON(
                installed: result.installed.map { InstalledJSON(name: $0.name, paths: $0.paths) },
                skipped: result.skipped.map { ["name": $0.name, "reason": $0.reason] }
            )
            let data = try JSONEncoder().encode(payload)
            guard let output = String(bytes: data, encoding: .utf8) else {
                throw JSONOutputError.encodingFailed
            }
            print(output)
        } else {
            for skill in result.installed {
                for path in skill.paths {
                    print("installed: \(skill.name) -> \(path)")
                }
            }
            for skip in result.skipped {
                print("skipped: \(skip.name) (\(skip.reason))")
            }
        }
    }
}
