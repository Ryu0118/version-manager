import ArgumentParser
import Foundation
import VersionManagerKit

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
        let runner = CheckRunner(fileManager: FileManager.default)
        let result = try await runner.run(
            configPath: globalOptions.config,
            projectRoot: FileManager.default.currentDirectoryPath
        )
        if json {
            let data = try JSONEncoder().encode(CheckResultJSON(result))
            guard let output = String(bytes: data, encoding: .utf8) else {
                throw JSONOutputError.encodingFailed
            }
            print(output)
        } else if result.isConsistent {
            print("✅ consistent")
        } else {
            for issue in result.issues {
                print("❌ \(issue)")
            }
        }
        if !result.isConsistent {
            throw ExitCode.failure
        }
    }
}
