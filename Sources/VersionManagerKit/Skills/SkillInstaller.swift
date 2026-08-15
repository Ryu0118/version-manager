import FileManagerProtocol
import Foundation

package struct SkillInstallResult: Sendable, Equatable {
    package let installed: [String]
    package let skipped: [SkippedSkill]

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
        dir: String,
        force: Bool
    ) throws -> SkillInstallResult {
        var installed: [String] = []
        var skipped: [SkillInstallResult.SkippedSkill] = []

        let targets: [String] = switch agent {
        case .claudeCode: [".claude/skills"]
        case .codex: [".agents/skills"]
        case .both: [".claude/skills", ".agents/skills"]
        }

        for asset in assets {
            var wroteAny = false
            for target in targets {
                let skillDir = "\(dir)/\(target)/\(asset.name)"
                let path = "\(skillDir)/SKILL.md"
                if fileManager.fileExists(atPath: path), !force {
                    skipped.append(.init(name: asset.name, reason: "already exists at \(path)"))
                    continue
                }
                try fileManager.createDirectory(atPath: skillDir, withIntermediateDirectories: true)
                guard fileManager.createFile(atPath: path, contents: Data(asset.content.utf8)) else {
                    throw SkillInstallerError.writeFailed(path: path)
                }
                wroteAny = true
            }
            if wroteAny {
                installed.append(asset.name)
            }
        }

        return SkillInstallResult(installed: installed, skipped: skipped)
    }
}
