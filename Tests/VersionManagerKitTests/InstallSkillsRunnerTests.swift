import FileManagerProtocol
import Foundation
import Testing
@testable import VersionManagerKit

@Test("global install resolves baseDir from HOME instead of the given dir")
func globalInstallUsesHomeDirectory() async throws {
    try await FileManager.default.runInTemporaryDirectory { fakeHome in
        setenv("HOME", fakeHome.path, 1)
        defer { unsetenv("HOME") }

        let runner = InstallSkillsRunner(fileManager: FileManager.default)
        let result = try runner.run(agent: .claudeCode, dir: ".", global: true, force: false)

        let expectedPaths = Set(GeneratedSkills.all.map {
            fakeHome.appendingPathComponent(".claude/skills/\($0.name)/SKILL.md").path
        })
        let actualPaths = Set(result.installed.flatMap(\.paths))
        #expect(actualPaths == expectedPaths)
        for path in expectedPaths {
            #expect(FileManager.default.fileExists(atPath: path))
        }
    }
}

@Test("non-global install resolves baseDir from dir, ignoring HOME")
func nonGlobalInstallUsesGivenDir() async throws {
    try await FileManager.default.runInTemporaryDirectory { projectDir in
        try await FileManager.default.runInTemporaryDirectory { fakeHome in
            setenv("HOME", fakeHome.path, 1)
            defer { unsetenv("HOME") }

            let runner = InstallSkillsRunner(fileManager: FileManager.default)
            _ = try runner.run(agent: .claudeCode, dir: projectDir.path, global: false, force: false)

            let projectPath = projectDir.appendingPathComponent(".claude/skills").path
            let homePath = fakeHome.appendingPathComponent(".claude/skills").path
            #expect(FileManager.default.fileExists(atPath: projectPath))
            #expect(!FileManager.default.fileExists(atPath: homePath))
        }
    }
}
