import FileManagerProtocol
import Foundation
import Testing
@testable import VersionManagerKit

@Test("writes a template .appversion.yml when none exists")
func writesTemplate() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let configPath = directory.appendingPathComponent(".appversion.yml").path
        let runner = InitRunner(fileManager: FileManager.default)
        try runner.run(configPath: configPath, force: false)
        let content = try String(contentsOfFile: configPath, encoding: .utf8)
        #expect(content.contains("version:"))
        #expect(content.contains("files:"))
    }
}

@Test("fails when a config already exists and force is false")
func failsWhenExistsWithoutForce() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let configPath = directory.appendingPathComponent(".appversion.yml").path
        try "existing".write(toFile: configPath, atomically: true, encoding: .utf8)
        let runner = InitRunner(fileManager: FileManager.default)
        #expect(throws: InitRunnerError.alreadyExists(path: configPath)) {
            try runner.run(configPath: configPath, force: false)
        }
    }
}

@Test("overwrites an existing config when force is true")
func overwritesWithForce() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let configPath = directory.appendingPathComponent(".appversion.yml").path
        try "existing".write(toFile: configPath, atomically: true, encoding: .utf8)
        let runner = InitRunner(fileManager: FileManager.default)
        try runner.run(configPath: configPath, force: true)
        let content = try String(contentsOfFile: configPath, encoding: .utf8)
        #expect(content.contains("version:"))
    }
}
