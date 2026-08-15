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
        var extractedVersions: Set<String> = []
        for rule in config.files {
            let matchedPaths = try await access.expandGlob(pattern: rule.path, relativeTo: projectRoot)
            if matchedPaths.isEmpty {
                issues.append("[\(rule.id)] matched zero files")
                continue
            }
            for path in matchedPaths {
                checkFile(rule: rule, path: path, issues: &issues, extractedVersions: &extractedVersions)
            }
        }

        issues += consistencyIssues(extractedVersions: extractedVersions, config: config)

        return CheckResult(isConsistent: issues.isEmpty, issues: issues)
    }

    private func checkFile(
        rule: Config.FileRule,
        path: String,
        issues: inout [String],
        extractedVersions: inout Set<String>
    ) {
        guard let data = fileManager.contents(atPath: path),
              let content = String(bytes: data, encoding: .utf8)
        else {
            issues.append("[\(rule.id)] unreadable: \(path)")
            return
        }
        guard let regex = try? Regex(rule.pattern) else {
            issues.append("[\(rule.id)] invalid regex")
            return
        }
        let matches = content.matches(of: regex)
        if matches.isEmpty {
            issues.append("[\(rule.id)] matched zero occurrences in \(path)")
            return
        }
        for match in matches {
            guard match.output.count > 1, let range = match.output[1].range else { continue }
            extractedVersions.insert(String(content[range]))
        }
    }

    private func consistencyIssues(extractedVersions: Set<String>, config: Config) -> [String] {
        var issues: [String] = []

        if extractedVersions.count > 1 {
            issues.append("version mismatch across rules: \(extractedVersions.sorted().joined(separator: ", "))")
        }

        if let version = extractedVersions.first, extractedVersions.count == 1 {
            do {
                try VersionFormatValidator().validate(version, against: config.version)
            } catch {
                issues.append("extracted version \"\(version)\" does not match configured format: \(error)")
            }
        }

        return issues
    }
}
