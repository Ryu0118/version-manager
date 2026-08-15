import ArgumentParser

package struct CurrentCommand: AsyncParsableCommand {
    package static let configuration = CommandConfiguration(
        commandName: "current",
        abstract: "Print the current version",
    )

    @Flag(help: "Output machine-readable JSON")
    package var json = false

    @OptionGroup package var globalOptions: GlobalOptions

    package init() {}

    package func run() async throws {
        // implemented in Task 12
    }
}
