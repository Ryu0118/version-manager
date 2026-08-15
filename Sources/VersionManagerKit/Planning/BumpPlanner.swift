import FileManagerProtocol

package struct BumpPlanner {
    private let fileSystemAccess: FileSystemAccess
    private let fileManager: any FileManagerProtocol

    package init(fileSystemAccess: FileSystemAccess, fileManager: some FileManagerProtocol) {
        self.fileSystemAccess = fileSystemAccess
        self.fileManager = fileManager
    }

    package func plan(config: Config, projectRoot: String, newVersion: String) async throws -> BumpPlan {
        var replacements: [FileReplacementPlan] = []

        for rule in config.files {
            let matchedPaths = try await fileSystemAccess.expandGlob(pattern: rule.path, relativeTo: projectRoot)
            for path in matchedPaths {
                guard let data = fileManager.contents(atPath: path),
                      let content = String(bytes: data, encoding: .utf8) else { continue }
                guard let regex = try? Regex(rule.pattern) else { continue }

                var matchSlices: [MatchSlice] = []
                var result = content
                // Replace in reverse order so an earlier length-changing replacement
                // never invalidates the still-unprocessed ranges of later matches.
                let matches = Array(content.matches(of: regex).reversed())

                for match in matches {
                    guard match.output.count > 1, let captureRange = match.output[1].range else { continue }
                    let oldValue = String(content[captureRange])
                    matchSlices.append(MatchSlice(range: captureRange, oldValue: oldValue))
                    result.replaceSubrange(captureRange, with: newVersion)
                }

                if !matchSlices.isEmpty {
                    replacements.append(FileReplacementPlan(
                        ruleID: rule.id,
                        path: path,
                        matches: matchSlices.reversed(),
                        originalContent: content,
                        newContent: result
                    ))
                }
            }
        }

        return BumpPlan(replacements: replacements)
    }
}
