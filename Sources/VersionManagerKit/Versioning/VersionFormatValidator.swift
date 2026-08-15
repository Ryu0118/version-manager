import Foundation

package struct VersionFormatValidator {
    package init() {}

    package func validate(_ versionString: String, strict: Bool) throws {
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
}

package enum VersionFormatError: Error, LocalizedError, Equatable {
    case invalidSemVer(input: String, underlying: String)
    case preReleaseNotAllowed(input: String)

    package var errorDescription: String? {
        switch self {
        case let .invalidSemVer(input, underlying):
            "\"\(input)\" is not a valid SemVer version: \(underlying)"
        case let .preReleaseNotAllowed(input):
            "\"\(input)\" contains a pre-release/build suffix, which is not allowed under strict semver (set version.strict: false to allow)"
        }
    }
}
