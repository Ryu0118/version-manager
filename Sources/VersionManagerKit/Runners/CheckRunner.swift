import FileManagerProtocol
import Foundation

package struct CheckResult: Sendable, Equatable {
    package let isConsistent: Bool
    package let issues: [String]
}

package struct CheckRunner {
    private let fileManager: any FileManagerProtocol

    package init(fileManager: some FileManagerProtocol) {
        self.fileManager = fileManager
    }

    package func run(configPath: String, projectRoot: String) async throws -> CheckResult {
        let config = try ConfigLoader(fileManager: fileManager).load(from: configPath)
        try ConfigValidator().validate(config)

        let access = FileSystemAccess(fileManager: fileManager)

        var issues: [String] = []
        for rule in config.files {
            let matchedPaths = try await access.expandGlob(pattern: rule.path, relativeTo: projectRoot)
            if matchedPaths.isEmpty {
                issues.append("[\(rule.id)] matched zero files")
                continue
            }
            for path in matchedPaths {
                guard let data = fileManager.contents(atPath: path),
                      let content = String(bytes: data, encoding: .utf8)
                else {
                    issues.append("[\(rule.id)] unreadable: \(path)")
                    continue
                }
                guard let regex = try? Regex(rule.pattern) else {
                    issues.append("[\(rule.id)] invalid regex")
                    continue
                }
                if content.matches(of: regex).isEmpty {
                    issues.append("[\(rule.id)] matched zero occurrences in \(path)")
                }
            }
        }

        return CheckResult(isConsistent: issues.isEmpty, issues: issues)
    }
}
