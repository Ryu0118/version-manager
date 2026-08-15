import ArgumentParser
import Foundation
import VersionManagerKit

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
        let runner = InitRunner(fileManager: FileManager.default)
        try runner.run(configPath: globalOptions.config, force: force)
        print("Wrote \(globalOptions.config)")
    }
}
