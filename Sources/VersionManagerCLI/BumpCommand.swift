import ArgumentParser

package struct BumpCommand: AsyncParsableCommand {
    package static let configuration = CommandConfiguration(
        commandName: "bump",
        abstract: "Bump the version across all configured files",
    )

    @Argument(help: "New version string")
    package var version: String

    @Flag(help: "Show the planned changes without writing them")
    package var dryRun = false

    @Flag(help: "Output machine-readable JSON")
    package var json = false

    @Flag(help: "Skip pre/post hooks")
    package var skipHooks = false

    @Flag(help: "Continue even if pre-bump consistency checks fail")
    package var force = false

    @OptionGroup package var globalOptions: GlobalOptions

    package init() {}

    package func run() async throws {
        // implemented in Task 9
    }
}
