import FileManagerProtocol
import Foundation

package enum InitRunnerError: Error, LocalizedError, Equatable {
    case alreadyExists(path: String)
    case writeFailed(path: String)

    package var errorDescription: String? {
        switch self {
        case let .alreadyExists(path):
            "\(path) already exists (use --force to overwrite)"
        case let .writeFailed(path):
            "failed to write \(path)"
        }
    }
}

package struct InitRunner {
    private let fileManager: any FileManagerProtocol

    package init(fileManager: some FileManagerProtocol) {
        self.fileManager = fileManager
    }

    package func run(configPath: String, force: Bool) throws {
        if fileManager.fileExists(atPath: configPath), !force {
            throw InitRunnerError.alreadyExists(path: configPath)
        }
        guard fileManager.createFile(atPath: configPath, contents: Data(Self.template.utf8), attributes: nil) else {
            throw InitRunnerError.writeFailed(path: configPath)
        }
    }

    private static let template = """
    # .appversion.yml
    # version: the single source of truth. `current`/`check` read this value directly;
    # `bump` rewrites it (and every matching files[] rule) to the new version.
    version: "0.1.0"

    # strict: true (default) rejects pre-release/build metadata like 1.18.0-beta.1
    # strict: false

    files:
      - id: version-swift
        path: Sources/MyToolCLI/Version.swift
        pattern: 'static let current = "(\\d+\\.\\d+\\.\\d+)"'
        occurrences: 1

    # renames:
    #   - id: version-xcconfig
    #     directory: Configs
    #     format: "{version}.xcconfig"
    #     transform:
    #       run: "echo \\"$APPVERSION_VALUE\\" | tr '.' '-'"

    # hooks:
    #   pre:
    #     - name: ensure-clean-worktree
    #       run: "git diff --quiet"
    #   post:
    #     - name: update-changelog
    #       run: "./scripts/insert-changelog-entry.sh"
    """
}
