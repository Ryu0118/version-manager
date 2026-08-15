import Foundation

package struct VersionFormatValidator {
    package init() {}

    package func validate(_ versionString: String, against format: Config.VersionFormat) throws {
        switch format.format {
        case .semver:
            try validateSemVer(versionString, strict: format.strict ?? true)
        case .pattern:
            try validatePattern(versionString, pattern: format.pattern ?? "")
        }
    }

    private func validateSemVer(_ versionString: String, strict: Bool) throws {
        let parsed: SemanticVersion
        do {
            parsed = try SemanticVersion(parsing: versionString)
        } catch {
            throw VersionFormatError.invalidSemVer(input: versionString, underlying: String(describing: error))
        }
        if strict, !parsed.preRelease.isEmpty {
            throw VersionFormatError.preReleaseNotAllowed(input: versionString)
        }
    }

    private func validatePattern(_ versionString: String, pattern: String) throws {
        let anchoredPattern = "^(?:\(pattern))$"
        guard let regex = try? Regex(anchoredPattern), versionString.wholeMatch(of: regex) != nil else {
            throw VersionFormatError.patternMismatch(input: versionString, pattern: pattern)
        }
    }
}

package enum VersionFormatError: Error, LocalizedError, Equatable {
    case invalidSemVer(input: String, underlying: String)
    case preReleaseNotAllowed(input: String)
    case patternMismatch(input: String, pattern: String)

    package var errorDescription: String? {
        switch self {
        case let .invalidSemVer(input, underlying):
            "\"\(input)\" is not a valid SemVer version: \(underlying)"
        case let .preReleaseNotAllowed(input):
            "\"\(input)\" contains a pre-release/build suffix, which is not allowed under strict semver (set version.strict: false to allow)"
        case let .patternMismatch(input, pattern):
            "\"\(input)\" does not match the configured pattern \"\(pattern)\""
        }
    }
}
