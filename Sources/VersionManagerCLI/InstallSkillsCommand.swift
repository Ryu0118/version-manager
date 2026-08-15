import ArgumentParser

package enum SkillAgentTarget: String, ExpressibleByArgument, CaseIterable {
    case claudeCode = "claude-code"
    case codex
    case both
}

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
        // implemented in Task 17
    }
}
