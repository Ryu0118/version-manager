import FileManagerProtocol
import Foundation
import Testing
@testable import VersionManagerKit

@Test("expands a glob to matching files")
func expandsGlob() async throws {
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
        try "1".write(
            to: directory.appendingPathComponent("App.xcodeproj/project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )
        try "1".write(
            to: directory.appendingPathComponent("Widget.xcodeproj/project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )
        try "1".write(
            to: directory.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )

        let access = FileSystemAccess(fileManager: fileManager)
        let matches = try await access.expandGlob(
            pattern: "*.xcodeproj/project.pbxproj",
            relativeTo: directory.path
        )
        #expect(matches.count == 2)
    }
}

@Test("glob with zero matches returns empty array")
func expandsGlobToEmpty() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let access = FileSystemAccess(fileManager: FileManager.default)
        let matches = try await access.expandGlob(
            pattern: "*.nonexistent",
            relativeTo: directory.path
        )
        #expect(matches.isEmpty)
    }
}
