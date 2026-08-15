import FileManagerProtocol
import Foundation
import ProcessRunning

package struct CurrentRunner {
    private let fileManager: any FileManagerProtocol
    private let processRunner: any ProcessRunning

    package init(fileManager: some FileManagerProtocol, processRunner: some ProcessRunning) {
        self.fileManager = fileManager
        self.processRunner = processRunner
    }

    package func run(configPath: String, projectRoot: String) async throws -> String {
        let config = try ConfigLoader(fileManager: fileManager).load(from: configPath)
        try ConfigValidator().validate(config)

        let ruleID = config.sourceOfTruth ?? config.files.first?.id
        guard let ruleID, let rule = config.files.first(where: { $0.id == ruleID }) else {
            throw CurrentRunnerError.noRulesConfigured
        }

        let access = FileSystemAccess(fileManager: fileManager)
        let matchedPaths = try await access.expandGlob(pattern: rule.path, relativeTo: projectRoot)
        guard let path = matchedPaths.first else {
            throw CurrentRunnerError.sourceFileNotFound(ruleID: rule.id, pattern: rule.path)
        }

        guard let data = fileManager.contents(atPath: path), let content = String(bytes: data, encoding: .utf8) else {
            throw CurrentRunnerError.sourceFileNotFound(ruleID: rule.id, pattern: rule.path)
        }
        guard let regex = try? Regex(rule.pattern), let match = content.firstMatch(of: regex),
              match.output.count > 1, let range = match.output[1].range
        else {
            throw CurrentRunnerError.noMatchFound(ruleID: rule.id)
        }

        return String(content[range])
    }
}

package enum CurrentRunnerError: Error, LocalizedError, Equatable {
    case noRulesConfigured
    case sourceFileNotFound(ruleID: String, pattern: String)
    case noMatchFound(ruleID: String)

    package var errorDescription: String? {
        switch self {
        case .noRulesConfigured:
            "no file rules configured"
        case let .sourceFileNotFound(ruleID, pattern):
            "[\(ruleID)] source file not found for pattern \"\(pattern)\""
        case let .noMatchFound(ruleID):
            "[\(ruleID)] pattern matched no version string"
        }
    }
}
