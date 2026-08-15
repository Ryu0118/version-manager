import FileManagerProtocol
import Foundation
import Testing
@testable import VersionManagerKit

private final class FailingWriteFileManager: FileManager, @unchecked Sendable {
    /// Maps a destination path to the 1-based call number of `moveItem(atPath:toPath:)`
    /// (per that destination) on which it should fail. A `nil` value never fails.
    let failOnDestinationCallNumber: [String: Int]
    private nonisolated(unsafe) var callCounts: [String: Int] = [:]

    init(failOnDestinationCallNumber: [String: Int]) {
        self.failOnDestinationCallNumber = failOnDestinationCallNumber
        super.init()
    }

    convenience init(failOnPath: String) {
        self.init(failOnDestinationCallNumber: [failOnPath: 1])
    }

    override func moveItem(atPath srcPath: String, toPath dstPath: String) throws {
        callCounts[dstPath, default: 0] += 1
        if callCounts[dstPath] == failOnDestinationCallNumber[dstPath] {
            throw CocoaError(.fileWriteUnknown)
        }
        try super.moveItem(atPath: srcPath, toPath: dstPath)
    }
}

@Test("applies replacements by writing new content")
func appliesReplacements() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let path = directory.appendingPathComponent("a.txt").path
        FileManager.default.createFile(atPath: path, contents: Data("v1.0.0".utf8))
        let plan = BumpPlan(replacements: [
            FileReplacementPlan(ruleID: "f", path: path, matches: [], originalContent: "v1.0.0", newContent: "v1.1.0"),
        ])
        let applier = PlanApplier(fileManager: FileManager.default)
        try applier.apply(plan)
        let contents = FileManager.default.contents(atPath: path) ?? Data()
        #expect(String(bytes: contents, encoding: .utf8) == "v1.1.0")
    }
}

@Test("applies renames after replacements")
func appliesRenamesAfterReplacements() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let aPath = directory.appendingPathComponent("a.txt").path
        let configsDir = directory.appendingPathComponent("Configs")
        try FileManager.default.createDirectory(at: configsDir, withIntermediateDirectories: true)
        let oldPath = configsDir.appendingPathComponent("1-0-0.xcconfig").path
        let newPath = configsDir.appendingPathComponent("1-1-0.xcconfig").path
        FileManager.default.createFile(atPath: aPath, contents: Data("v1.0.0".utf8))
        FileManager.default.createFile(atPath: oldPath, contents: Data("old".utf8))

        var plan = BumpPlan(replacements: [
            FileReplacementPlan(ruleID: "f", path: aPath, matches: [], originalContent: "v1.0.0", newContent: "v1.1.0"),
        ])
        plan.renames = [RenamePlan(ruleID: "r", oldPath: oldPath, newPath: newPath)]
        let applier = PlanApplier(fileManager: FileManager.default)
        try applier.apply(plan)
        #expect(FileManager.default.fileExists(atPath: newPath))
        #expect(!FileManager.default.fileExists(atPath: oldPath))
    }
}

@Test("rolls back already-applied replacements on mid-apply I/O failure")
func rollsBackOnFailure() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let aPath = directory.appendingPathComponent("a.txt").path
        let bPath = directory.appendingPathComponent("b.txt").path
        FileManager.default.createFile(atPath: aPath, contents: Data("v1.0.0".utf8))
        FileManager.default.createFile(atPath: bPath, contents: Data("v1.0.0".utf8))

        let plan = BumpPlan(replacements: [
            FileReplacementPlan(ruleID: "a", path: aPath, matches: [], originalContent: "v1.0.0", newContent: "v1.1.0"),
            FileReplacementPlan(ruleID: "b", path: bPath, matches: [], originalContent: "v1.0.0", newContent: "v1.1.0"),
        ])
        let mock = FailingWriteFileManager(failOnPath: bPath)
        let applier = PlanApplier(fileManager: mock)
        #expect(throws: (any Error).self) {
            try applier.apply(plan)
        }
        let contents = FileManager.default.contents(atPath: aPath) ?? Data()
        #expect(String(bytes: contents, encoding: .utf8) == "v1.0.0")
    }
}

@Test("surfaces unrecovered paths when rollback itself fails")
func rollbackFailureIsSurfaced() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let aPath = directory.appendingPathComponent("a.txt").path
        let bPath = directory.appendingPathComponent("b.txt").path
        FileManager.default.createFile(atPath: aPath, contents: Data("v1.0.0".utf8))
        FileManager.default.createFile(atPath: bPath, contents: Data("v1.0.0".utf8))

        let plan = BumpPlan(replacements: [
            FileReplacementPlan(ruleID: "a", path: aPath, matches: [], originalContent: "v1.0.0", newContent: "v1.1.0"),
            FileReplacementPlan(ruleID: "b", path: bPath, matches: [], originalContent: "v1.0.0", newContent: "v1.1.0"),
        ])
        // a's forward write (call #1) succeeds; b's forward write (call #1) fails,
        // triggering rollback; a's rollback write (call #2) also fails.
        let mock = FailingWriteFileManager(failOnDestinationCallNumber: [aPath: 2, bPath: 1])
        let applier = PlanApplier(fileManager: mock)
        #expect(throws: PlanApplierError.rollbackFailed(unrecoveredPaths: [aPath])) {
            try applier.apply(plan)
        }
    }
}
