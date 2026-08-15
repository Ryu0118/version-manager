import Foundation

package enum PlanValidatorError: Error, LocalizedError, Equatable {
    case zeroMatches(ruleID: String)
    case occurrencesMismatch(ruleID: String, expected: Int, found: Int)
    case inconsistentOldVersions(ruleID: String, versions: [String])
    case noOpBump(version: String)
    case renameTargetAlreadyExists(ruleID: String, path: String)

    package var errorDescription: String? {
        switch self {
        case let .zeroMatches(ruleID):
            "[\(ruleID)] matched zero files/occurrences — the rule may be stale"
        case let .occurrencesMismatch(ruleID, expected, found):
            "[\(ruleID)] expected \(expected) occurrence(s), found \(found)"
        case let .inconsistentOldVersions(ruleID, versions):
            "[\(ruleID)] rules disagree on the current version: \(versions.joined(separator: ", ")) (use --force to override)"
        case let .noOpBump(version):
            "new version \"\(version)\" is the same as the current version"
        case let .renameTargetAlreadyExists(ruleID, path):
            "[\(ruleID)] rename target already exists: \(path)"
        }
    }
}

package struct PlanValidationFailure: Error, LocalizedError, Equatable {
    package let errors: [PlanValidatorError]

    package var errorDescription: String? {
        errors.compactMap(\.errorDescription).joined(separator: "\n")
    }
}

package struct PlanValidator {
    package init() {}

    package func validate(
        _ plan: BumpPlan,
        config: Config,
        newVersion: String,
        force: Bool,
        existingPaths: Set<String> = []
    ) throws {
        var errors: [PlanValidatorError] = []

        for rule in config.files {
            let matchingReplacements = plan.replacements.filter { $0.ruleID == rule.id }
            let totalMatches = matchingReplacements.reduce(0) { $0 + $1.matches.count }

            if totalMatches == 0 {
                errors.append(.zeroMatches(ruleID: rule.id))
                continue
            }

            if case let .exactly(expected) = rule.occurrences, expected != totalMatches {
                errors.append(.occurrencesMismatch(ruleID: rule.id, expected: expected, found: totalMatches))
            }
        }

        var oldVersionsByRule: [String: Set<String>] = [:]
        for replacement in plan.replacements {
            oldVersionsByRule[replacement.ruleID, default: []].formUnion(replacement.matches.map(\.oldValue))
        }
        let allOldVersions = Set(oldVersionsByRule.values.flatMap(\.self))
        if allOldVersions.count > 1, !force {
            for (ruleID, versions) in oldVersionsByRule where versions.count == 1 {
                errors.append(.inconsistentOldVersions(ruleID: ruleID, versions: Array(versions)))
            }
        }

        if allOldVersions.count == 1, allOldVersions.first == newVersion {
            errors.append(.noOpBump(version: newVersion))
        }

        for rename in plan.renames where existingPaths.contains(rename.newPath) {
            errors.append(.renameTargetAlreadyExists(ruleID: rename.ruleID, path: rename.newPath))
        }

        if !errors.isEmpty {
            throw PlanValidationFailure(errors: errors)
        }
    }
}
