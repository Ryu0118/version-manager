import FileManagerProtocol
import Foundation
import Testing
@testable import VersionManagerKit

private func writeFixture(in directory: URL) throws {
    try FileManager.default.createDirectory(
        at: directory.appendingPathComponent("Sources"),
        withIntermediateDirectories: true
    )
    try """
    version:
      format: semver
    files:
      - id: version-swift
        path: Sources/Version.swift
        pattern: 'static let current = "(\\d+\\.\\d+\\.\\d+)"'
        occurrences: 1
    """.write(to: directory.appendingPathComponent(".appversion.yml"), atomically: true, encoding: .utf8)
    try "enum Version {\n    static let current = \"1.0.0\"\n}\n".write(
        to: directory.appendingPathComponent("Sources/Version.swift"),
        atomically: true,
        encoding: .utf8
    )
}

@Test("bump end-to-end updates the version and writes the file")
func bumpEndToEnd() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try writeFixture(in: directory)
        let runner = BumpRunner(fileManager: FileManager.default, processRunner: MockProcessRunner())
        _ = try await runner.run(
            configPath: directory.appendingPathComponent(".appversion.yml").path,
            projectRoot: directory.path,
            newVersion: "1.1.0",
            dryRun: false,
            skipHooks: true,
            force: false
        )
        let content = try String(
            contentsOf: directory.appendingPathComponent("Sources/Version.swift"),
            encoding: .utf8
        )
        #expect(content.contains("1.1.0"))
        #expect(!content.contains("1.0.0"))
    }
}

@Test("bump --dry-run writes nothing")
func bumpDryRunWritesNothing() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try writeFixture(in: directory)
        let runner = BumpRunner(fileManager: FileManager.default, processRunner: MockProcessRunner())
        _ = try await runner.run(
            configPath: directory.appendingPathComponent(".appversion.yml").path,
            projectRoot: directory.path,
            newVersion: "1.1.0",
            dryRun: true,
            skipHooks: true,
            force: false
        )
        let content = try String(
            contentsOf: directory.appendingPathComponent("Sources/Version.swift"),
            encoding: .utf8
        )
        #expect(content.contains("1.0.0"))
    }
}

@Test("check reports consistent when files match")
func checkReportsConsistent() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try writeFixture(in: directory)
        let runner = CheckRunner(fileManager: FileManager.default)
        let result = try await runner.run(
            configPath: directory.appendingPathComponent(".appversion.yml").path,
            projectRoot: directory.path
        )
        #expect(result.isConsistent)
        #expect(result.issues.isEmpty)
    }
}

@Test("check reports inconsistent when a rule matches zero times")
func checkReportsInconsistentOnZeroMatch() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try """
        version:
          format: semver
        files:
          - id: missing
            path: Sources/DoesNotExist.swift
            pattern: 'static let current = "(\\d+\\.\\d+\\.\\d+)"'
        """.write(to: directory.appendingPathComponent(".appversion.yml"), atomically: true, encoding: .utf8)
        let runner = CheckRunner(fileManager: FileManager.default)
        let result = try await runner.run(
            configPath: directory.appendingPathComponent(".appversion.yml").path,
            projectRoot: directory.path
        )
        #expect(!result.isConsistent)
        #expect(!result.issues.isEmpty)
    }
}
