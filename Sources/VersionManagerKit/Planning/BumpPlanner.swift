import FileManagerProtocol
import Foundation
import ProcessRunning

package struct BumpPlanner {
    private let fileSystemAccess: FileSystemAccess
    private let fileManager: any FileManagerProtocol
    private let processRunner: any ProcessRunning

    package init(
        fileSystemAccess: FileSystemAccess,
        fileManager: some FileManagerProtocol,
        processRunner: some ProcessRunning
    ) {
        self.fileSystemAccess = fileSystemAccess
        self.fileManager = fileManager
        self.processRunner = processRunner
    }

    package func plan(config: Config, projectRoot: String, newVersion: String) async throws -> BumpPlan {
        var replacements: [FileReplacementPlan] = []

        for rule in config.files {
            let matchedPaths = try await fileSystemAccess.expandGlob(pattern: rule.path, relativeTo: projectRoot)
            for path in matchedPaths {
                guard let data = fileManager.contents(atPath: path),
                      let content = String(bytes: data, encoding: .utf8) else { continue }
                if let replacement = Self.replacementPlan(
                    ruleID: rule.id, path: path, content: content, pattern: rule.pattern, newVersion: newVersion
                ) {
                    replacements.append(replacement)
                }
            }
        }

        var renames: [RenamePlan] = []
        let oldVersion = replacements.first?.matches.first?.oldValue ?? ""
        let transformer = VersionTransformer(processRunner: processRunner)
        for rule in config.renames ?? [] {
            let newValue = try await transformer.transform(
                rule, value: newVersion, old: oldVersion, new: newVersion, configDir: projectRoot
            )
            let oldValue = try await transformer.transform(
                rule, value: oldVersion, old: oldVersion, new: newVersion, configDir: projectRoot
            )
            let newFileName = rule.format.replacingOccurrences(of: "{version}", with: newValue)
            let oldFileName = rule.format.replacingOccurrences(of: "{version}", with: oldValue)
            let directory = projectRoot + "/" + rule.directory
            renames.append(RenamePlan(
                ruleID: rule.id,
                oldPath: directory + "/" + oldFileName,
                newPath: directory + "/" + newFileName
            ))
        }

        return BumpPlan(replacements: replacements, renames: renames)
    }

    package static func replacementPlan(
        ruleID: String,
        path: String,
        content: String,
        pattern: String,
        newVersion: String
    ) -> FileReplacementPlan? {
        guard let regex = try? Regex(pattern) else { return nil }

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

        guard !matchSlices.isEmpty else { return nil }
        return FileReplacementPlan(
            ruleID: ruleID,
            path: path,
            matches: matchSlices.reversed(),
            originalContent: content,
            newContent: result
        )
    }
}
