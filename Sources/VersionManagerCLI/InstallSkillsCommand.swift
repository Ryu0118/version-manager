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

    @Option(help: "Target project root")
    package var dir: String = "."

    @Flag(help: "Overwrite existing skill directories")
    package var force = false

    @Flag(help: "Output machine-readable JSON")
    package var json = false

    package init() {}

    package func run() async throws {
        let runner = InstallSkillsRunner(fileManager: FileManager.default)
        let result = try runner.run(agent: agent, dir: dir, force: force)
        if json {
            struct ResultJSON: Encodable {
                let installed: [String]
                let skipped: [[String: String]]
            }
            let payload = ResultJSON(
                installed: result.installed,
                skipped: result.skipped.map { ["name": $0.name, "reason": $0.reason] }
            )
            let data = try JSONEncoder().encode(payload)
            guard let output = String(bytes: data, encoding: .utf8) else {
                throw JSONOutputError.encodingFailed
            }
            print(output)
        } else {
            for name in result.installed {
                print("installed: \(name)")
            }
            for skip in result.skipped {
                print("skipped: \(skip.name) (\(skip.reason))")
            }
        }
    }
}
