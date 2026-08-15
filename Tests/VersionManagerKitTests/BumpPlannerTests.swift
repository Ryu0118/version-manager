import FileManagerProtocol
import Foundation
import Testing
@testable import VersionManagerKit

@Test("single match single file replaces the captured group only")
func singleMatchReplaces() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try "static let current = \"1.17.2\"".write(
            to: directory.appendingPathComponent("Version.swift"),
            atomically: true,
            encoding: .utf8
        )
        let config = Config(
            version: .init(format: .semver, pattern: nil, strict: nil),
            sourceOfTruth: nil,
            files: [.init(
                id: "v",
                path: "Version.swift",
                pattern: "static let current = \"(\\d+\\.\\d+\\.\\d+)\"",
                occurrences: .all
            )],
            renames: nil,
            hooks: nil
        )
        let access = FileSystemAccess(fileManager: FileManager.default)
        let planner = BumpPlanner(
            fileSystemAccess: access, fileManager: FileManager.default, processRunner: MockProcessRunner()
        )
        let plan = try await planner.plan(config: config, projectRoot: directory.path, newVersion: "1.18.0")

        #expect(plan.replacements.count == 1)
        let replacement = plan.replacements[0]
        #expect(replacement.newContent == "static let current = \"1.18.0\"")
        #expect(replacement.matches.count == 1)
        #expect(replacement.matches[0].oldValue == "1.17.2")
    }
}

@Test("multiple matches in one file all replace correctly, including surrounding context")
func multipleMatchesReplace() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try "MARKETING_VERSION = 1.17.2;\nDEBUG_MARKETING_VERSION = 1.17.2;\n".write(
            to: directory.appendingPathComponent("project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )
        let config = Config(
            version: .init(format: .semver, pattern: nil, strict: nil),
            sourceOfTruth: nil,
            files: [.init(
                id: "pbx",
                path: "project.pbxproj",
                pattern: "MARKETING_VERSION = (\\d+\\.\\d+\\.\\d+);",
                occurrences: .all
            )],
            renames: nil,
            hooks: nil
        )
        let access = FileSystemAccess(fileManager: FileManager.default)
        let planner = BumpPlanner(
            fileSystemAccess: access, fileManager: FileManager.default, processRunner: MockProcessRunner()
        )
        let plan = try await planner.plan(config: config, projectRoot: directory.path, newVersion: "1.18.0")

        #expect(plan.replacements.count == 1)
        #expect(plan.replacements[0].matches.count == 2)
        #expect(plan.replacements[0].newContent == "MARKETING_VERSION = 1.18.0;\nDEBUG_MARKETING_VERSION = 1.18.0;\n")
    }
}

@Test("length-changing replacement keeps all matches correctly positioned (reverse-order safety)")
func lengthChangingReplacementStaysCorrect() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try "v1.9.0 first, then v1.9.0 second, then v1.9.0 third".write(
            to: directory.appendingPathComponent("multi.txt"),
            atomically: true,
            encoding: .utf8
        )
        let config = Config(
            version: .init(format: .semver, pattern: nil, strict: nil),
            sourceOfTruth: nil,
            files: [.init(id: "multi", path: "multi.txt", pattern: "v(\\d+\\.\\d+\\.\\d+)", occurrences: .all)],
            renames: nil,
            hooks: nil
        )
        let access = FileSystemAccess(fileManager: FileManager.default)
        let planner = BumpPlanner(
            fileSystemAccess: access, fileManager: FileManager.default, processRunner: MockProcessRunner()
        )
        // 1.9.0 -> 1.10.0 grows each match by 1 character; a naive forward replace would corrupt indices 2 and 3.
        let plan = try await planner.plan(config: config, projectRoot: directory.path, newVersion: "1.10.0")

        #expect(plan.replacements[0].newContent == "v1.10.0 first, then v1.10.0 second, then v1.10.0 third")
    }
}

@Test("glob matching multiple files produces one FileReplacementPlan per file")
func globMultipleFilesProducesMultiplePlans() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directory.appendingPathComponent("App.xcodeproj"),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: directory.appendingPathComponent("Widget.xcodeproj"),
            withIntermediateDirectories: true
        )
        try "MARKETING_VERSION = 1.17.2;".write(
            to: directory.appendingPathComponent("App.xcodeproj/project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )
        try "MARKETING_VERSION = 1.17.2;".write(
            to: directory.appendingPathComponent("Widget.xcodeproj/project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )
        let config = Config(
            version: .init(format: .semver, pattern: nil, strict: nil),
            sourceOfTruth: nil,
            files: [.init(
                id: "pbx",
                path: "*.xcodeproj/project.pbxproj",
                pattern: "MARKETING_VERSION = (\\d+\\.\\d+\\.\\d+);",
                occurrences: .all
            )],
            renames: nil,
            hooks: nil
        )
        let access = FileSystemAccess(fileManager: fileManager)
        let planner = BumpPlanner(
            fileSystemAccess: access, fileManager: fileManager, processRunner: MockProcessRunner()
        )
        let plan = try await planner.plan(config: config, projectRoot: directory.path, newVersion: "1.18.0")

        #expect(plan.replacements.count == 2)
        #expect(Set(plan.replacements.map(\.ruleID)) == ["pbx"])
    }
}

@Test("zero matching files produces zero FileReplacementPlans for that rule")
func zeroMatchingFilesProducesEmpty() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let config = Config(
            version: .init(format: .semver, pattern: nil, strict: nil),
            sourceOfTruth: nil,
            files: [.init(id: "missing", path: "*.nonexistent", pattern: "v(\\d+)", occurrences: .all)],
            renames: nil,
            hooks: nil
        )
        let access = FileSystemAccess(fileManager: FileManager.default)
        let planner = BumpPlanner(
            fileSystemAccess: access, fileManager: FileManager.default, processRunner: MockProcessRunner()
        )
        let plan = try await planner.plan(config: config, projectRoot: directory.path, newVersion: "1.18.0")

        #expect(plan.replacements.isEmpty)
    }
}

@Test("capture group outside context is unchanged")
func contextOutsideCaptureUnchanged() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try "prefix-1.0.0-suffix stays".write(
            to: directory.appendingPathComponent("f.txt"),
            atomically: true,
            encoding: .utf8
        )
        let config = Config(
            version: .init(format: .semver, pattern: nil, strict: nil),
            sourceOfTruth: nil,
            files: [.init(id: "f", path: "f.txt", pattern: "prefix-(\\d+\\.\\d+\\.\\d+)-suffix", occurrences: .all)],
            renames: nil,
            hooks: nil
        )
        let access = FileSystemAccess(fileManager: FileManager.default)
        let planner = BumpPlanner(
            fileSystemAccess: access, fileManager: FileManager.default, processRunner: MockProcessRunner()
        )
        let plan = try await planner.plan(config: config, projectRoot: directory.path, newVersion: "2.0.0")

        #expect(plan.replacements[0].newContent == "prefix-2.0.0-suffix stays")
    }
}

@Test("rename rule with transform produces a RenamePlan")
func renameRuleProducesRenamePlan() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        try "v1.0.0".write(
            to: directory.appendingPathComponent("a.txt"),
            atomically: true,
            encoding: .utf8
        )
        let config = Config(
            version: .init(format: .semver, pattern: nil, strict: nil),
            sourceOfTruth: nil,
            files: [.init(id: "f", path: "a.txt", pattern: "v(\\d+\\.\\d+\\.\\d+)", occurrences: .all)],
            renames: [.init(
                id: "r",
                directory: "Configs",
                format: "{version}.xcconfig",
                transform: .init(run: "echo \"$APPVERSION_VALUE\" | tr '.' '-'")
            )],
            hooks: nil
        )
        let access = FileSystemAccess(fileManager: FileManager.default)
        let processRunner = MockProcessRunner()
        processRunner.stubbedOutput = "1-1-0\n"
        let planner = BumpPlanner(
            fileSystemAccess: access, fileManager: FileManager.default, processRunner: processRunner
        )
        let plan = try await planner.plan(config: config, projectRoot: directory.path, newVersion: "1.1.0")

        #expect(plan.renames.count == 1)
        #expect(plan.renames[0].newPath == directory.path + "/Configs/1-1-0.xcconfig")
    }
}
