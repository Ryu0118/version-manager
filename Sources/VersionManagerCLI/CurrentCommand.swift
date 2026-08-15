import ArgumentParser
import Foundation
import VersionManagerKit

package struct CurrentCommand: AsyncParsableCommand {
    package static let configuration = CommandConfiguration(
        commandName: "current",
        abstract: "Print the current version"
    )

    @Flag(help: "Output machine-readable JSON")
    package var json = false

    @OptionGroup package var globalOptions: GlobalOptions

    package init() {}

    package func run() async throws {
        let runner = CurrentRunner(fileManager: FileManager.default)
        let version = try await runner.run(
            configPath: globalOptions.config,
            projectRoot: FileManager.default.currentDirectoryPath
        )
        print(version)
    }
}
