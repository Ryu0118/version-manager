import ArgumentParser
import Foundation
import ProcessRunning
import VersionManagerKit

package struct BumpCommand: AsyncParsableCommand {
    package static let configuration = CommandConfiguration(
        commandName: "bump",
        abstract: "Bump the version across all configured files"
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
        try BumpArgumentsValidator().validate(version: version)
        let runner = BumpRunner(fileManager: FileManager.default, processRunner: ProcessRunner())
        let plan = try await runner.run(
            configPath: globalOptions.config,
            projectRoot: FileManager.default.currentDirectoryPath,
            newVersion: version,
            dryRun: dryRun,
            skipHooks: skipHooks,
            force: force
        )
        if json {
            let data = try JSONEncoder().encode(BumpPlanJSON(plan))
            if let output = String(bytes: data, encoding: .utf8) {
                print(output)
            }
        } else {
            let renderer = DiffRenderer(useColor: true)
            print(renderer.render(plan))
        }
    }
}
