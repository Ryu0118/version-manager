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
    version: "1.0.0"
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

@Test("bump updates .appversion.yml's own version field and preserves comments")
func bumpUpdatesConfigVersionAndPreservesComments() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("Sources"),
            withIntermediateDirectories: true
        )
        try """
        # top-level comment about this project's versioning
        version: "1.0.0" # inline comment on the version line
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
        let runner = BumpRunner(fileManager: FileManager.default, processRunner: MockProcessRunner())
        _ = try await runner.run(
            configPath: directory.appendingPathComponent(".appversion.yml").path,
            projectRoot: directory.path,
            newVersion: "1.1.0",
            dryRun: false,
            skipHooks: true,
            force: false
        )
        let configContent = try String(
            contentsOf: directory.appendingPathComponent(".appversion.yml"),
            encoding: .utf8
        )
        #expect(configContent.contains("version: \"1.1.0\""))
        #expect(!configContent.contains("\"1.0.0\""))
        #expect(configContent.contains("# top-level comment about this project's versioning"))
        #expect(configContent.contains("# inline comment on the version line"))
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

@Test("current returns config.version verbatim, without reading any file rule")
func currentExtractsVersion() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("Sources"),
            withIntermediateDirectories: true
        )
        try """
        version: "2.5.0"
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
        let runner = CurrentRunner(fileManager: FileManager.default)
        let version = try await runner.run(
            configPath: directory.appendingPathComponent(".appversion.yml").path,
            projectRoot: directory.path
        )
        #expect(version == "2.5.0")
    }
}

@Test("check reports inconsistent when a rule matches zero times")
func checkReportsInconsistentOnZeroMatch() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try """
        version: "1.0.0"
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

@Test("bump runs post hooks with correct environment after applying")
func bumpRunsPostHooks() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try writeFixture(in: directory)
        try """
        version: "1.0.0"
        files:
          - id: version-swift
            path: Sources/Version.swift
            pattern: 'static let current = "(\\d+\\.\\d+\\.\\d+)"'
            occurrences: 1
        hooks:
          post:
            - name: notify
              run: "true"
        """.write(to: directory.appendingPathComponent(".appversion.yml"), atomically: true, encoding: .utf8)
        let processRunner = MockProcessRunner()
        let runner = BumpRunner(fileManager: FileManager.default, processRunner: processRunner)
        _ = try await runner.run(
            configPath: directory.appendingPathComponent(".appversion.yml").path,
            projectRoot: directory.path,
            newVersion: "1.1.0",
            dryRun: false,
            skipHooks: false,
            force: false
        )
        #expect(processRunner.capturedCommands.contains("true"))
    }
}

@Test("check detects version mismatch across rules")
func checkDetectsVersionMismatch() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try """
        version: "1.0.0"
        files:
          - id: a
            path: a.txt
            pattern: 'v(\\d+\\.\\d+\\.\\d+)'
          - id: b
            path: b.txt
            pattern: 'v(\\d+\\.\\d+\\.\\d+)'
        """.write(to: directory.appendingPathComponent(".appversion.yml"), atomically: true, encoding: .utf8)
        try "v1.0.0".write(to: directory.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "v0.9.0".write(to: directory.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        let runner = CheckRunner(fileManager: FileManager.default)
        let result = try await runner.run(
            configPath: directory.appendingPathComponent(".appversion.yml").path,
            projectRoot: directory.path
        )
        #expect(!result.isConsistent)
    }
}

@Test("check detects a file rule whose version disagrees with config.version")
func checkDetectsMismatchAgainstConfigVersion() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try """
        version: "2.0.0"
        files:
          - id: a
            path: a.txt
            pattern: 'v(\\d+\\.\\d+\\.\\d+)'
        """.write(to: directory.appendingPathComponent(".appversion.yml"), atomically: true, encoding: .utf8)
        try "v1.0.0".write(to: directory.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        let runner = CheckRunner(fileManager: FileManager.default)
        let result = try await runner.run(
            configPath: directory.appendingPathComponent(".appversion.yml").path,
            projectRoot: directory.path
        )
        #expect(!result.isConsistent)
        #expect(result.issues.contains { $0.contains("2.0.0") })
    }
}
