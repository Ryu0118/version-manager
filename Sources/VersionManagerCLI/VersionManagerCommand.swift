import ArgumentParser

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
package struct VersionManagerCommand: AsyncParsableCommand {
    package static let configuration = CommandConfiguration(
        commandName: "version-manager",
        abstract: "Bump version strings across a project from a single .appversion.yml",
        version: VersionManagerVersion.current,
        subcommands: [
            BumpCommand.self,
            CheckCommand.self,
            CurrentCommand.self,
            InitCommand.self,
            InstallSkillsCommand.self,
        ],
    )

    package init() {}
}
