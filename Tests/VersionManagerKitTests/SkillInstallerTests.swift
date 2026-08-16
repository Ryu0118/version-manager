import FileManagerProtocol
import Foundation
import Testing
@testable import VersionManagerKit

@Test("installs to .claude/skills for claude-code agent")
func installsToClaudeSkillsDir() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let assets = [SkillAsset(name: "test-skill", content: "# Test Skill")]
        let installer = SkillInstaller(fileManager: FileManager.default)
        let result = try installer.install(assets, agent: .claudeCode, baseDir: directory.path, force: false)
        let path = directory.appendingPathComponent(".claude/skills/test-skill/SKILL.md").path
        #expect(result.installed == [.init(name: "test-skill", paths: [path])])
        let content = try String(contentsOfFile: path, encoding: .utf8)
        #expect(content == "# Test Skill")
    }
}

@Test("installs to .agents/skills for agents target")
func installsToAgentsSkillsDir() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let assets = [SkillAsset(name: "test-skill", content: "# Test Skill")]
        let installer = SkillInstaller(fileManager: FileManager.default)
        _ = try installer.install(assets, agent: .agents, baseDir: directory.path, force: false)
        let path = directory.appendingPathComponent(".agents/skills/test-skill/SKILL.md").path
        #expect(FileManager.default.fileExists(atPath: path))
    }
}

@Test("installs to both locations for both agent")
func installsToBothDirs() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let assets = [SkillAsset(name: "test-skill", content: "# Test Skill")]
        let installer = SkillInstaller(fileManager: FileManager.default)
        _ = try installer.install(assets, agent: .both, baseDir: directory.path, force: false)
        let claudePath = directory.appendingPathComponent(".claude/skills/test-skill/SKILL.md").path
        let agentsPath = directory.appendingPathComponent(".agents/skills/test-skill/SKILL.md").path
        #expect(FileManager.default.fileExists(atPath: claudePath))
        #expect(FileManager.default.fileExists(atPath: agentsPath))
    }
}

@Test("skips an existing skill without force")
func skipsExistingWithoutForce() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let skillDir = directory.appendingPathComponent(".claude/skills/test-skill")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let path = skillDir.appendingPathComponent("SKILL.md").path
        try "old content".write(toFile: path, atomically: true, encoding: .utf8)

        let assets = [SkillAsset(name: "test-skill", content: "# New Content")]
        let installer = SkillInstaller(fileManager: FileManager.default)
        let result = try installer.install(assets, agent: .claudeCode, baseDir: directory.path, force: false)
        #expect(result.installed.isEmpty)
        #expect(result.skipped.count == 1)
        let content = try String(contentsOfFile: path, encoding: .utf8)
        #expect(content == "old content")
    }
}

@Test("overwrites an existing skill with force")
func overwritesSkillWithForce() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let skillDir = directory.appendingPathComponent(".claude/skills/test-skill")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let path = skillDir.appendingPathComponent("SKILL.md").path
        try "old content".write(toFile: path, atomically: true, encoding: .utf8)

        let assets = [SkillAsset(name: "test-skill", content: "# New Content")]
        let installer = SkillInstaller(fileManager: FileManager.default)
        let result = try installer.install(assets, agent: .claudeCode, baseDir: directory.path, force: true)
        #expect(result.installed == [.init(name: "test-skill", paths: [path])])
        let content = try String(contentsOfFile: path, encoding: .utf8)
        #expect(content == "# New Content")
    }
}
