import Foundation

extension ConfigValidator {
    func validateFiles(_ files: [Config.FileRule]) -> [ConfigValidatorError] {
        var errors: [ConfigValidatorError] = []
        var seenIDs: Set<String> = []

        for rule in files {
            if seenIDs.contains(rule.id) {
                errors.append(.duplicateRuleID(id: rule.id))
            }
            seenIDs.insert(rule.id)

            if rule.path.hasPrefix("/") || rule.path.contains("..") {
                errors.append(.pathEscapesProjectRoot(ruleID: rule.id, path: rule.path))
            }

            do {
                _ = try Regex(rule.pattern)
                let groupCount = captureGroupCount(of: rule.pattern)
                if groupCount != 1 {
                    errors.append(.captureGroupCountMismatch(ruleID: rule.id, found: groupCount))
                }
            } catch {
                errors.append(.invalidRegexPattern(
                    ruleID: rule.id,
                    pattern: rule.pattern,
                    underlying: String(describing: error)
                ))
            }
        }

        return errors
    }

    /// Swift's `Regex` type does not expose capture-group count via public API, so this hand-rolled
    /// scanner counts top-level unescaped `(` that are not followed by `?` (non-capturing groups,
    /// lookarounds, etc.). Precise enough for the validator's needs, not a full regex parser.
    private func captureGroupCount(of pattern: String) -> Int {
        var count = 0
        var index = pattern.startIndex
        while index < pattern.endIndex {
            let char = pattern[index]
            if char == "\\" {
                index = pattern.index(after: index)
                if index < pattern.endIndex {
                    index = pattern.index(after: index)
                }
                continue
            }
            if char == "(" {
                let nextIndex = pattern.index(after: index)
                if nextIndex < pattern.endIndex, pattern[nextIndex] == "?" {
                    // (?:...) non-capturing, (?=...) lookahead, etc. — not a capture group
                } else {
                    count += 1
                }
            }
            index = pattern.index(after: index)
        }
        return count
    }
}
