import Foundation

package struct ConfigValidator {
    package init() {}

    package func validate(_ config: Config) throws {
        var errors: [ConfigValidatorError] = []
        errors += validateFiles(config.files)
        errors += validateRenames(config.renames)
        if !errors.isEmpty {
            throw ConfigValidationFailure(errors: errors)
        }
    }
}

package enum ConfigValidatorError: Error, LocalizedError, Equatable {
    case invalidRegexPattern(ruleID: String, pattern: String, underlying: String)
    case captureGroupCountMismatch(ruleID: String, found: Int)
    case pathEscapesProjectRoot(ruleID: String, path: String)
    case duplicateRuleID(id: String)
    case missingVersionPlaceholder(ruleID: String, format: String)
    case unknownSourceOfTruth(id: String)
    case patternRequiredForCustomFormat

    package var errorDescription: String? {
        switch self {
        case let .invalidRegexPattern(ruleID, pattern, underlying):
            "[\(ruleID)] invalid regex pattern \"\(pattern)\": \(underlying)"
        case let .captureGroupCountMismatch(ruleID, found):
            "[\(ruleID)] pattern must have exactly 1 capture group, found \(found)"
        case let .pathEscapesProjectRoot(ruleID, path):
            "[\(ruleID)] path \"\(path)\" escapes the project root (absolute paths and \"..\" are not allowed)"
        case let .duplicateRuleID(id):
            "duplicate rule id \"\(id)\""
        case let .missingVersionPlaceholder(ruleID, format):
            "[\(ruleID)] rename format \"\(format)\" must contain {version}"
        case let .unknownSourceOfTruth(id):
            "source_of_truth \"\(id)\" does not match any rule id"
        case .patternRequiredForCustomFormat:
            "version.pattern is required when version.format is \"pattern\""
        }
    }
}

package struct ConfigValidationFailure: Error, LocalizedError, Equatable {
    package let errors: [ConfigValidatorError]

    package var errorDescription: String? {
        errors.compactMap(\.errorDescription).joined(separator: "\n")
    }
}
