import Foundation

package struct ConfigValidator {
    package init() {}

    package func validate(_ config: Config) throws {
        var errors: [ConfigValidatorError] = []
        errors += validateFiles(config.files)
        errors += validateRenames(config.renames)
        errors += validateVersion(config.version, strict: config.strict)
        if !errors.isEmpty {
            throw ConfigValidationFailure(errors: errors)
        }
    }

    private func validateVersion(_ version: String, strict: Bool?) -> [ConfigValidatorError] {
        do {
            try VersionFormatValidator().validate(version, strict: strict ?? true)
        } catch {
            return [.invalidVersionField(underlying: error.localizedDescription)]
        }
        return []
    }
}

package enum ConfigValidatorError: Error, LocalizedError, Equatable {
    case invalidRegexPattern(ruleID: String, pattern: String, underlying: String)
    case captureGroupCountMismatch(ruleID: String, found: Int)
    case pathEscapesProjectRoot(ruleID: String, path: String)
    case duplicateRuleID(id: String)
    case missingVersionPlaceholder(ruleID: String, format: String)
    case invalidVersionField(underlying: String)

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
        case let .invalidVersionField(underlying):
            "config version field is invalid: \(underlying)"
        }
    }
}

package struct ConfigValidationFailure: Error, LocalizedError, Equatable {
    package let errors: [ConfigValidatorError]

    package var errorDescription: String? {
        errors.compactMap(\.errorDescription).joined(separator: "\n")
    }
}
