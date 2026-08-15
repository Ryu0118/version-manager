import ArgumentParser

package struct CheckCommand: AsyncParsableCommand {
    package static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Verify that project files are consistent with .appversion.yml"
    )

    @Flag(help: "Output machine-readable JSON")
    package var json = false

    @OptionGroup package var globalOptions: GlobalOptions

    package init() {}

    package func run() async throws {
        // implemented in Task 9
    }
}
