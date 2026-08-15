import ArgumentParser

package struct InitCommand: AsyncParsableCommand {
    package static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Generate a .appversion.yml template"
    )

    @Flag(help: "Overwrite an existing .appversion.yml")
    package var force = false

    @OptionGroup package var globalOptions: GlobalOptions

    package init() {}

    package func run() async throws {
        // implemented in Task 14
    }
}
