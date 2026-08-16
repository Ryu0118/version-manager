import FileManagerProtocol
import Foundation

package struct SkillInstallResult: Sendable, Equatable {
    package let installed: [InstalledSkill]
    package let skipped: [SkippedSkill]

    package struct InstalledSkill: Sendable, Equatable {
        package let name: String
        package let paths: [String]
    }

    package struct SkippedSkill: Sendable, Equatable {
        package let name: String
        package let reason: String
    }
}

package enum SkillInstallerError: LocalizedError, Equatable {
    case writeFailed(path: String)

    package var errorDescription: String? {
        switch self {
        case let .writeFailed(path):
            "Failed to write skill file at \(path)"
        }
    }
}

package struct SkillInstaller {
    private let fileManager: any FileManagerProtocol

    package init(fileManager: some FileManagerProtocol) {
        self.fileManager = fileManager
    }

    package func install(
        _ assets: [SkillAsset],
        agent: SkillAgentTarget,
        baseDir: String,
        force: Bool
    ) throws -> SkillInstallResult {
        var installed: [SkillInstallResult.InstalledSkill] = []
        var skipped: [SkillInstallResult.SkippedSkill] = []

        let targets: [String] = switch agent {
        case .claudeCode: ["\(baseDir)/.claude/skills"]
        case .agents: ["\(baseDir)/.agents/skills"]
        case .both: ["\(baseDir)/.claude/skills", "\(baseDir)/.agents/skills"]
        }

        for asset in assets {
            var writtenPaths: [String] = []
            for target in targets {
                let skillDir = "\(target)/\(asset.name)"
                let path = "\(skillDir)/SKILL.md"
                if fileManager.fileExists(atPath: path), !force {
                    skipped.append(.init(name: asset.name, reason: "already exists at \(path)"))
                    continue
                }
                try fileManager.createDirectory(atPath: skillDir, withIntermediateDirectories: true)
                guard fileManager.createFile(atPath: path, contents: Data(asset.content.utf8)) else {
                    throw SkillInstallerError.writeFailed(path: path)
                }
                writtenPaths.append(path)
            }
            if !writtenPaths.isEmpty {
                installed.append(.init(name: asset.name, paths: writtenPaths))
            }
        }

        return SkillInstallResult(installed: installed, skipped: skipped)
    }
}
